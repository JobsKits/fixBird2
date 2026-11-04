//
//  UIViewController+生命周期探针.swift
//  JobsByUIKit
//
//  Created by Jobs on 2026年5月13日，星期三.
//

#if os(OSX)
import AppKit
#elseif os(iOS) || os(tvOS)
import UIKit
#endif

import ObjectiveC
import JobsSwiftBaseDefines

// MARK: - 📌给 UIViewController 的生命周期中加入探针@转发到挂载的子视图 UIView
/// 示例代码 ➤ UIView 侧挂钩 @ UIViewController 的生命周期
private final class UITestView: UIView, VCLifeCycleListener {
    func hostLoadView() {
        /// TODO
    }
    func hostViewDidLoad() {
        /// TODO
    }
    func hostViewWillAppear() {
        /// TODO
    }
    func hostViewDidAppear() {
        /// TODO
    }
    func hostViewWillDisappear() {
        /// TODO
    }
    func hostViewDidDisappear() {
        /// TODO
    }
    func hostViewWillLayoutSubviews() {
        /// TODO
    }
    func hostViewDidLayoutSubviews() {
        /// TODO
    }
    func hostViewSafeAreaInsetsDidChange() {
        /// TODO
    }
}
/// 示例代码 ➤ UIViewController 侧@注入使用（手动映射示例）
/// 注意：实际使用本文件提供的 bindVCLifecycleListener 后，不需要手动写这些转发。
private final class UITestVC: UIViewController {
    lazy var testView = {
        UITestView()
    }()

    override func loadView() {
        super.loadView()
        testView.hostLoadView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        testView.hostViewDidLoad()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        testView.hostViewWillAppear()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        testView.hostViewDidAppear()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        testView.hostViewWillDisappear()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        testView.hostViewDidDisappear()
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        testView.hostViewWillLayoutSubviews()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        testView.hostViewDidLayoutSubviews()
    }

    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        testView.hostViewSafeAreaInsetsDidChange()
    }
}
// MARK: - 用协议让 view 接收“宿主生命周期”事件（不耦合具体 view）
public protocol VCLifeCycleListener: AnyObject {
    func hostLoadView()
    func hostViewDidLoad()
    func hostViewWillAppear()
    func hostViewDidAppear()
    func hostViewWillDisappear()
    func hostViewDidDisappear()
    // 布局相关
    func hostViewWillLayoutSubviews()
    func hostViewDidLayoutSubviews()
    // 安全区变化
    func hostViewSafeAreaInsetsDidChange()
}

public extension VCLifeCycleListener {
    func hostLoadView() {}
    func hostViewDidLoad() {}
    func hostViewWillAppear() {}
    func hostViewDidAppear() {}
    func hostViewWillDisappear() {}
    func hostViewDidDisappear() {}
    func hostViewWillLayoutSubviews() {}
    func hostViewDidLayoutSubviews() {}
    func hostViewSafeAreaInsetsDidChange() {}
}
public typealias AnyWeakBox = WeakBox<AnyObject>
private var _vcListenersKey: UInt8 = 0
private var _vcSwizzledKey: UInt8 = 0
// MARK: - Public API
extension UIViewController {
    /// 绑定一个 listener（通常是某个子 view）
    public func bindVCLifecycleListener(_ listener: VCLifeCycleListener) {
        VCLifecycleSwizzler.installIfNeeded()
        var arr = (objc_getAssociatedObject(self, &_vcListenersKey) as? [AnyWeakBox]) ?? []
        // 去重（避免重复绑定）
        let obj = listener as AnyObject
        if arr.contains(where: { $0.value === obj }) == false {
            arr.append(WeakBox(obj))
            objc_setAssociatedObject(
                self,
                &_vcListenersKey,
                arr,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
    /// 解绑（可选）
    public func unbindVCLifecycleListener(_ listener: VCLifeCycleListener) {
        guard var arr = objc_getAssociatedObject(self, &_vcListenersKey) as? [AnyWeakBox] else { return }
        let obj = listener as AnyObject
        arr.removeAll { $0.value == nil || $0.value === obj }
        objc_setAssociatedObject(self, &_vcListenersKey, arr, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }
    /// 当前活着的 listeners（自动清理 nil）
    fileprivate var _vcLifecycleListeners: [VCLifeCycleListener] {
        let arr = (objc_getAssociatedObject(self, &_vcListenersKey) as? [AnyWeakBox]) ?? []
        // 清理 nil，并把 AnyObject 转回协议类型
        let aliveObjects: [AnyObject] = arr.compactMap { $0.value }
        let aliveListeners: [VCLifeCycleListener] = aliveObjects.compactMap { $0 as? VCLifeCycleListener }
        if aliveObjects.count != arr.count {
            objc_setAssociatedObject(
                self,
                &_vcListenersKey,
                aliveObjects.map { WeakBox($0) },
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        };return aliveListeners
    }
}
// MARK: - Swizzler
private enum VCLifecycleSwizzler {
    static func installIfNeeded() {
        // 保证只 swizzle 一次
        if (objc_getAssociatedObject(UIViewController.self, &_vcSwizzledKey) as? Bool) == true { return }
        objc_setAssociatedObject(UIViewController.self, &_vcSwizzledKey, true, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        swizzle(UIViewController.self,
                original: #selector(UIViewController.loadView),
                swizzled: #selector(UIViewController.__probe_loadView))
        swizzle(UIViewController.self,
                original: #selector(UIViewController.viewDidLoad),
                swizzled: #selector(UIViewController.__probe_viewDidLoad))
        swizzle(UIViewController.self,
                original: #selector(UIViewController.viewWillAppear(_:)),
                swizzled: #selector(UIViewController.__probe_viewWillAppear(_:)))
        swizzle(UIViewController.self,
                original: #selector(UIViewController.viewDidAppear(_:)),
                swizzled: #selector(UIViewController.__probe_viewDidAppear(_:)))
        swizzle(UIViewController.self,
                original: #selector(UIViewController.viewWillDisappear(_:)),
                swizzled: #selector(UIViewController.__probe_viewWillDisappear(_:)))
        swizzle(UIViewController.self,
                original: #selector(UIViewController.viewDidDisappear(_:)),
                swizzled: #selector(UIViewController.__probe_viewDidDisappear(_:)))
        swizzle(UIViewController.self,
                original: #selector(UIViewController.viewWillLayoutSubviews),
                swizzled: #selector(UIViewController.__probe_viewWillLayoutSubviews))
        swizzle(UIViewController.self,
                original: #selector(UIViewController.viewDidLayoutSubviews),
                swizzled: #selector(UIViewController.__probe_viewDidLayoutSubviews))
        swizzle(UIViewController.self,
                original: #selector(UIViewController.viewSafeAreaInsetsDidChange),
                swizzled: #selector(UIViewController.__probe_viewSafeAreaInsetsDidChange))
    }

    private static func swizzle(_ cls: AnyClass, original: Selector, swizzled: Selector) {
        guard
            let m1 = class_getInstanceMethod(cls, original),
            let m2 = class_getInstanceMethod(cls, swizzled)
        else { return }
        method_exchangeImplementations(m1, m2)
    }
}
// MARK: - Probe Forwarders
extension UIViewController {
    @objc fileprivate func __probe_loadView() {
        __probe_loadView()
        _vcLifecycleListeners.forEach { $0.hostLoadView() }
    }
    @objc fileprivate func __probe_viewDidLoad() {
        __probe_viewDidLoad()
        _vcLifecycleListeners.forEach { $0.hostViewDidLoad() }
    }
    @objc fileprivate func __probe_viewWillAppear(_ animated: Bool) {
        __probe_viewWillAppear(animated)
        _vcLifecycleListeners.forEach { $0.hostViewWillAppear() }
    }
    @objc fileprivate func __probe_viewDidAppear(_ animated: Bool) {
        __probe_viewDidAppear(animated)
        _vcLifecycleListeners.forEach { $0.hostViewDidAppear() }
    }
    @objc fileprivate func __probe_viewWillDisappear(_ animated: Bool) {
        __probe_viewWillDisappear(animated)
        _vcLifecycleListeners.forEach { $0.hostViewWillDisappear() }
    }
    @objc fileprivate func __probe_viewDidDisappear(_ animated: Bool) {
        __probe_viewDidDisappear(animated)
        _vcLifecycleListeners.forEach { $0.hostViewDidDisappear() }
    }
    @objc fileprivate func __probe_viewWillLayoutSubviews() {
        __probe_viewWillLayoutSubviews()
        _vcLifecycleListeners.forEach { $0.hostViewWillLayoutSubviews() }
    }
    @objc fileprivate func __probe_viewDidLayoutSubviews() {
        __probe_viewDidLayoutSubviews()
        _vcLifecycleListeners.forEach { $0.hostViewDidLayoutSubviews() }
    }
    @objc fileprivate func __probe_viewSafeAreaInsetsDidChange() {
        __probe_viewSafeAreaInsetsDidChange()
        _vcLifecycleListeners.forEach { $0.hostViewSafeAreaInsetsDidChange() }
    }
}
