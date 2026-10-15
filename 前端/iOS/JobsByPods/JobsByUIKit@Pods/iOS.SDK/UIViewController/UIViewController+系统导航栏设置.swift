//
//  UIViewController+系统导航栏设置.swift
//  JobsByUIKit
//
//  Created by Jobs on 2026年5月13日，星期三.
//

#if os(OSX)
import AppKit
#elseif os(iOS) || os(tvOS)
import UIKit
#endif

import JobsSwiftDSL
import JobsSwiftBaseDefines

// MARK: - 不看代码，强制性的在本页面隐藏系统的导航栏
/**
 
     override func viewDidAppear(_ animated: Bool) {
         super.viewDidAppear(animated)
         jobsForceHideSystemNavBar(YES)
     }
 
     override func viewWillDisappear(_ animated: Bool) {
         super.viewWillDisappear(animated)
         jobsForceHideSystemNavBar(NO)
     }
 */
extension UIViewController {
    public func jobsForceHideSystemNavBar(_ hidden: Bool) {
        onMainAsync(self) { vc in
            var r: UIResponder? = vc.view
            while let cur = r {
                if let hostVC = cur as? UIViewController,
                   let nav = hostVC.navigationController {
                    nav.setNavigationBarHidden(hidden, animated: false)
                    nav.navigationBar.isHidden = hidden
                    return
                }
                r = cur.next
            }
            vc.navigationController?.setNavigationBarHidden(hidden, animated: false)
            vc.navigationController?.navigationBar.isHidden = hidden
        }
    }
}
private var _nbHiddenKey: UInt8 = 0
private var _nbAnimatedKey: UInt8 = 0
private var _nbSwizzledKey: UInt8 = 0
extension UIViewController {
    /// 写在 viewDidLoad：进入本页隐藏，离开自动还原
    @discardableResult
    public func byNavBarHiddenLifecycle(_ hiddenOnAppear: Bool, animated: Bool = true) -> Self {
        objc_setAssociatedObject(self, &_nbHiddenKey, hiddenOnAppear as NSNumber, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        objc_setAssociatedObject(self, &_nbAnimatedKey, animated as NSNumber, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        Self._nb_swizzleOnce(for: type(of: self))
        return self
    }
    /// 立即切换（链式）
    @discardableResult
    public func byNavBarHidden(_ hidden: Bool, animated: Bool = false) -> Self {
        navigationController?.setNavigationBarHidden(hidden, animated: animated)
        return self
    }
    // MARK: - swizzle
    private static func _nb_swizzleOnce(for cls: UIViewController.Type) {
        let key = ObjectIdentifier(cls)
        var done = (objc_getAssociatedObject(cls, &_nbSwizzledKey) as? Set<ObjectIdentifier>) ?? []
        guard !done.contains(key) else { return }
        done.insert(key); objc_setAssociatedObject(cls, &_nbSwizzledKey, done, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        func exch(_ c: AnyClass, _ o: Selector, _ n: Selector) {
            guard let m1 = class_getInstanceMethod(c, o),
                  let m2 = class_getInstanceMethod(c, n) else { return }
            method_exchangeImplementations(m1, m2)
        }
        exch(cls, #selector(UIViewController.viewWillAppear(_:)),
                  #selector(UIViewController._nb_viewWillAppear(_:)))
        exch(cls, #selector(UIViewController.viewWillDisappear(_:)),
                  #selector(UIViewController._nb_viewWillDisappear(_:)))
    }

    @objc
    private func _nb_viewWillAppear(_ animated: Bool) {
        _nb_viewWillAppear(animated) // 调原实现
        if let on = (objc_getAssociatedObject(self, &_nbHiddenKey) as? NSNumber)?.boolValue,
           let anim = (objc_getAssociatedObject(self, &_nbAnimatedKey) as? NSNumber)?.boolValue {
            navigationController?.setNavigationBarHidden(on, animated: anim)
        }
    }

    @objc
    private func _nb_viewWillDisappear(_ animated: Bool) {
        _nb_viewWillDisappear(animated) // 调原实现
        if let _ = objc_getAssociatedObject(self, &_nbHiddenKey) {
            // 只在启用了 lifecycle 时还原
            navigationController?.setNavigationBarHidden(false, animated: true)
        }
    }
}

private enum _JobsNavPopSwizzleOnceToken { static var done = false }
extension UINavigationController {
    public static func _jobs_installPopSwizzlesIfNeeded() {
        guard !_JobsNavPopSwizzleOnceToken.done else { return }
        _JobsNavPopSwizzleOnceToken.done = true
        let cls: AnyClass = UINavigationController.self
        func exch(_ o: Selector, _ n: Selector) {
            guard let m1 = class_getInstanceMethod(cls, o),
                  let m2 = class_getInstanceMethod(cls, n) else { return }
            method_exchangeImplementations(m1, m2)
        }
        exch(#selector(UINavigationController.popViewController(animated:)),
             #selector(UINavigationController._jobs_popViewController_swizzled(animated:)))
        exch(#selector(UINavigationController.popToViewController(_:animated:)),
             #selector(UINavigationController._jobs_popToViewController_swizzled(_:animated:)))
        exch(#selector(UINavigationController.popToRootViewController(animated:)),
             #selector(UINavigationController._jobs_popToRootViewController_swizzled(animated:)))
    }

    @objc
    public func _jobs_popViewController_swizzled(animated: Bool) -> UIViewController? {
        // 手势交互进行中 → 走系统（避免破坏交互式返回）
        if let g = self.interactivePopGestureRecognizer,
           g.state == .began || g.state == .changed {
            return _jobs_popViewController_swizzled(animated: animated)
        }
        if animated, let top = self.topViewController,
           let dir = top._jobs_entryDirection, dir != .system {
            let tr = CATransition()
                .byType(.push)
                .bySubtype(dir._reverseCASubtype)
                .byDuration(top._jobs_entryDuration ?? 0.32)
                .byTimingFunction(
                    CAMediaTimingFunction(name: top._jobs_entryTiming ?? .easeInEaseOut)
                )
            self.view.layer.add(tr, forKey: "jobs.pop.\(dir._debugKey)")
            return _jobs_popViewController_swizzled(animated: false)
        };return _jobs_popViewController_swizzled(animated: animated)
    }

    @objc
    public func _jobs_popToViewController_swizzled(_ viewController: UIViewController, animated: Bool) -> [UIViewController]? {
        if let g = self.interactivePopGestureRecognizer,
           g.state == .began || g.state == .changed {
            return _jobs_popToViewController_swizzled(viewController, animated: animated)
        }
        if animated, let top = self.topViewController,
           let dir = top._jobs_entryDirection, dir != .system {
            let tr = CATransition()
                .byType(.push)
                .bySubtype(dir._reverseCASubtype)
                .byDuration(top._jobs_entryDuration ?? 0.32)                 // 来自 CAMediaTiming DSL
                .byTimingFunction(                                           // 来自 CAAnimation DSL
                    CAMediaTimingFunction(name: top._jobs_entryTiming ?? .easeInEaseOut)
                )
            self.view.layer.add(tr, forKey: "jobs.popTo.\(dir._debugKey)")
            return _jobs_popToViewController_swizzled(viewController, animated: false)
        };return _jobs_popToViewController_swizzled(viewController, animated: animated)
    }

    @objc
    public func _jobs_popToRootViewController_swizzled(animated: Bool) -> [UIViewController]? {
        if let g = self.interactivePopGestureRecognizer,
           g.state == .began || g.state == .changed {
            return _jobs_popToRootViewController_swizzled(animated: animated)
        }
        if animated, let top = self.topViewController,
           let dir = top._jobs_entryDirection, dir != .system {
            let tr = CATransition()
                .byType(.push)
                .bySubtype(dir._reverseCASubtype)
                .byDuration(top._jobs_entryDuration ?? 0.32)
                .byTimingFunction(
                    CAMediaTimingFunction(name: top._jobs_entryTiming ?? .easeInEaseOut)
                )
            self.view.layer.add(tr, forKey: "jobs.popRoot.\(dir._debugKey)")
            return _jobs_popToRootViewController_swizzled(animated: false)
        };return _jobs_popToRootViewController_swizzled(animated: animated)
    }
}

@MainActor
extension UIViewController {
    private struct _JobsNavKey {
        // 用地址作为唯一 key
        static var wrapper: UInt8 = 0
    }

    public var jobsNavContainer: UINavigationController {
        if let nav = self as? UINavigationController { return nav }
        if let nav = self.navigationController { return nav }
        if let cached = objc_getAssociatedObject(self, &_JobsNavKey.wrapper) as? UINavigationController {
            return cached
        }
        let nav = UINavigationController(rootViewController: self)
        objc_setAssociatedObject(self, &_JobsNavKey.wrapper, nav, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        return nav
    }

    public var jobsNav: Self {
        _ = jobsNavContainer
        return self
    }

    @discardableResult
    public func jobsNav(_ onWrap: (UINavigationController) -> Void) -> Self {
        let alreadyHad = (self is UINavigationController)
            || (self.navigationController != nil)
            || (objc_getAssociatedObject(self, &_JobsNavKey.wrapper) != nil)
        let nav = jobsNavContainer
        if !alreadyHad { onWrap(nav) };return self
    }
}
// ================================== 链式导航（去重） ==================================
public enum JobsPresentPolicy {
    case ignoreIfBusy
    case presentOnTopMost
}

private var _jobsPushLockKey: UInt8 = 0
public final class _JobsPushLockBox {
    var lockedUntil: TimeInterval = 0
}

extension UINavigationController {
    public var _jobs_lockBox: _JobsPushLockBox {
        if let b = objc_getAssociatedObject(self, &_jobsPushLockKey) as? _JobsPushLockBox { return b }
        let b = _JobsPushLockBox()
        objc_setAssociatedObject(self, &_jobsPushLockKey, b, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        return b
    }
    public var _jobs_isPushingLocked: Bool {
        CFAbsoluteTimeGetCurrent() < _jobs_lockBox.lockedUntil
    }
    public func _jobs_lockPushing(for seconds: TimeInterval) {
        _jobs_lockBox.lockedUntil = CFAbsoluteTimeGetCurrent() + max(0.05, seconds)
    }
}
