//
//  UIViewController+DebugDeallocSwizzle.swift
//  JobsSwiftDebugTools
//
//  Created by Jobs on 2026年5月13日，星期三.
//

#if os(OSX)
import AppKit
#elseif os(iOS) || os(tvOS)
import UIKit
#endif

import ObjectiveC
import JobsToast

// MARK: - 可选协议
/// 如果你想自定义 toast 里展示的 tag，让你的 VC 遵循这个协议即可。
@objc public protocol UIViewControllerDebugDeinitProtocol {
    @objc var debugDeinitTag: String { get }
}

// MARK: - 对外安装入口
public enum VCDebugDeallocDebug {
    private static let showsDeinitTipsKey = "com.jobs.debug.showsControllerDeinitTips"

    /// 是否显示控制器销毁 Toast；未配置时保持历史默认值 `true`。
    public static var showsDeinitTips: Bool {
        get {
            guard UserDefaults.standard.object(forKey: showsDeinitTipsKey) != nil else { return true };return UserDefaults.standard.bool(forKey: showsDeinitTipsKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: showsDeinitTipsKey)
        }
    }

    /// 建议在 App 启动时调用一次（AppDelegate / SceneDelegate）。
    public static func install() {
        #if DEBUG
        if Thread.isMainThread {
            UIViewController._vcDebug_swizzleViewDidLoadOnce()
        } else {
            DispatchQueue.main.async {
                UIViewController._vcDebug_swizzleViewDidLoadOnce()
            }
        }
        #endif
    }
}

#if DEBUG
// MARK: - Deinit 监听器
/// 通过关联对象给 VC 绑定一个监听器对象：
/// - VC 释放时，监听器也会释放
/// - 在监听器的 deinit 里回调，从而实现“VC deinit 时提示”
private final class _VCDebugDeinitObserver {
    private let onDeinit: () -> Void
    init(_ onDeinit: @escaping () -> Void) { self.onDeinit = onDeinit }
    deinit { onDeinit() }
}
// MARK: - UIViewController Hook
private var _vcDebugDeinitObserverKey: UInt8 = 0
extension UIViewController {
    /// 仅绑定一次监听器，避免重复创建
    fileprivate func _vcDebug_attachDeinitObserverIfNeeded() {
        if objc_getAssociatedObject(self, &_vcDebugDeinitObserverKey) != nil {
            return
        }
        let clsName = String(describing: type(of: self))
        let tag: String
        if let p = self as? UIViewControllerDebugDeinitProtocol {
            tag = p.debugDeinitTag
        } else {
            tag = ""
        }
        // 这里可以自定义 toast 展示文案
        let text: String
        if tag.isEmpty {
            text = "🧹 \(clsName) deinit"
        } else {
            text = "🧹 \(clsName) [\(tag)] deinit"
        }
        let observer = _VCDebugDeinitObserver {
            DispatchQueue.main.async {
                guard VCDebugDeallocDebug.showsDeinitTips else {
                    return
                }
                text.toast
            }
        }
        objc_setAssociatedObject(
            self,
            &_vcDebugDeinitObserverKey,
            observer,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
    }
    // MARK: Swizzle
    /// swizzle viewDidLoad：在 VC 生命周期早期绑定 deinit 监听器（不碰 dealloc，更安全）
    fileprivate static func _vcDebug_swizzleViewDidLoadOnce() {
        struct Once {
            static let install: Void = {
                let cls: AnyClass = UIViewController.self
                let originalSel = #selector(UIViewController.viewDidLoad)
                let swizzledSel = #selector(UIViewController._vcDebug_viewDidLoad)
                guard
                    let originalMethod = class_getInstanceMethod(cls, originalSel),
                    let swizzledMethod = class_getInstanceMethod(cls, swizzledSel)
                else {
                    return
                }
                method_exchangeImplementations(originalMethod, swizzledMethod)
            }()
        }
        _ = Once.install
    }

    @objc fileprivate func _vcDebug_viewDidLoad() {
        // 每个 VC 实例只绑定一次监听器
        _vcDebug_attachDeinitObserverIfNeeded()
        // 调用原始的 viewDidLoad（交换实现后，这里调用到的是原实现）
        _vcDebug_viewDidLoad()
    }
}

#endif
