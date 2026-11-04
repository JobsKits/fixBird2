//
//  UIViewController+传值回调.swift
//  JobsByUIKit
//
//  Created by Jobs on 2026年5月13日，星期三.
//

#if os(OSX)
import AppKit
#elseif os(iOS) || os(tvOS)
import UIKit
#endif

import ObjectiveC.runtime
import JobsSwiftBlock
import JobsSwiftDSL
import JobsSwiftBaseDefines

private enum JobsAssocKey {
    static var callback: UInt8 = 0
    static var onAppearCompletions: UInt8 = 1
    static var appearCompletionFired: UInt8 = 2
}
/// ✅ 覆盖所有 ViewController（UIViewController 及其子类）
extension UIViewController: @retroactive ViewDataProtocol {}
@MainActor
public extension ViewDataProtocol where Self: UIViewController {
    // ================================== 正向：传值即渲染（默认 no-op） ==================================
    /// 默认实现：什么都不做，留给子类 VC 自己实现 `byData(_:)` 去解析/渲染
    @discardableResult
    func byData(_ any: Any?) -> Self { self }
    // ================================== 逆向：回传 ==================================
    @discardableResult
    func onResult(_ callback: @escaping jobsByAnyBlock) -> Self {
        objc_setAssociatedObject(
            self,
            &JobsAssocKey.callback,
            callback,
            .OBJC_ASSOCIATION_COPY_NONATOMIC
        );return self
    }
    func sendResult(_ any: Any?) {
        (objc_getAssociatedObject(self, &JobsAssocKey.callback) as? jobsByAnyBlock)?(any)
    }
}

extension UIViewController{
    @discardableResult
    public func goBack(_ result: Any?, animated: Bool = true) -> Self {
        if let r = result { sendResult(r) }
        if let nav = navigationController,
           nav.viewControllers.first != self {
            nav.popViewController(animated: animated)
        } else {
            dismiss(animated: animated)
        };return self
    }
    // ✅ 出现完成（push/present 结束）的一次性回调
    @discardableResult
    public func byCompletion(_ block: @escaping jobsByVoidBlock) -> Self {
        UIViewController._JobsAppearSwizzler.installIfNeeded()
        var arr = (objc_getAssociatedObject(self, &JobsAssocKey.onAppearCompletions) as? [jobsByVoidBlock]) ?? []
        arr.append(block)
        objc_setAssociatedObject(
            self,
            &JobsAssocKey.onAppearCompletions,
            arr,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
        // 若已在窗口（先跳转后注册），下一轮主线程立即触发
        if self.viewIfLoaded?.window != nil {
            onMainAsync { [weak self] in
                guard let self else { return }
                jobs_fireAppearCompletionIfNeeded(reason: "alreadyVisible")
            }
        };return self
    }

    public func jobs_fireAppearCompletionIfNeeded(reason: String) {
        let fired = (objc_getAssociatedObject(self, &JobsAssocKey.appearCompletionFired) as? Bool) ?? false
        guard !fired else { return }
        guard let blocks = objc_getAssociatedObject(self, &JobsAssocKey.onAppearCompletions) as? [jobsByVoidBlock],
              !blocks.isEmpty else { return }
        objc_setAssociatedObject(
            self,
            &JobsAssocKey.appearCompletionFired,
            true,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
        objc_setAssociatedObject(
            self,
            &JobsAssocKey.onAppearCompletions,
            nil,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
        blocks.forEach { $0() }
        // print("✅ [JobsAppearCompletion] fired by \(reason) for \(self)")
    }
}
// `viewDidAppear` swizzle：出现完成时机
private enum _JobsAppearSwizzleOnceToken { static var done = false }
extension UIViewController {
    private final class _JobsAppearSwizzler {
        static func installIfNeeded() {
            guard !_JobsAppearSwizzleOnceToken.done else { return }
            _JobsAppearSwizzleOnceToken.done = true
            let cls: AnyClass = UIViewController.self
            guard
                let m1 = class_getInstanceMethod(cls, #selector(UIViewController.viewDidAppear(_:))),
                let m2 = class_getInstanceMethod(cls, #selector(UIViewController.jobs_viewDidAppear_swizzled(_:)))
            else { return }
            method_exchangeImplementations(m1, m2)
        }
    }

    @objc
    private func jobs_viewDidAppear_swizzled(_ animated: Bool) {
        self.jobs_viewDidAppear_swizzled(animated) // 原实现
        self.jobs_fireAppearCompletionIfNeeded(reason: "viewDidAppear")
    }
}
