//
//  UINavigationController.swift
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

// MARK: - DSL
extension UINavigationController {
    /// 注意：UIImagePickerController 是 UINavigationController 子类
    /// 为避免与 UIImagePickerController(byTarget) 冲突，这里入口命名为 byNavTarget
    @discardableResult
    public func byNavTarget(_ target: AnyObject) -> Self {
        let p = jobs_navBlocksProxy()!
        p.target = target
        delegate = p
        return self
    }
    // MARK: - 转场
    @discardableResult
    public func animationControllerForOperation(_ block: @escaping (AnyObject,
                                                                    UINavigationController,
                                                                    UINavigationController.Operation,
                                                                    UIViewController,
                                                                    UIViewController)
                                                -> UIViewControllerAnimatedTransitioning?) -> Self {
        jobs_navBlocksProxy()?.animationControllerForOperation = block
        return self
    }

    @discardableResult
    public func interactionControllerForAnimationController(_ block: @escaping (AnyObject,
                                                                                UINavigationController,
                                                                                UIViewControllerAnimatedTransitioning)
                                                            -> UIViewControllerInteractiveTransitioning?) -> Self {
        jobs_navBlocksProxy()?.interactionControllerForAnimationController = block
        return self
    }
    // MARK: - 显示回调
    @discardableResult
    public func willShow(_ block: @escaping (AnyObject,
                                             UINavigationController,
                                             UIViewController,
                                             Bool) -> Void) -> Self {
        jobs_navBlocksProxy()?.willShow = block
        return self
    }

    @discardableResult
    public func didShow(_ block: @escaping (AnyObject,
                                            UINavigationController,
                                            UIViewController,
                                            Bool) -> Void) -> Self {
        jobs_navBlocksProxy()?.didShow = block
        return self
    }
    // MARK: - 方向（这些 delegate 方法在老系统也存在；闭包属性别标 @available）
    @discardableResult
    public func preferredInterfaceOrientationForPresentation(_ block: @escaping (AnyObject,
                                                                                 UINavigationController)
                                                             -> UIInterfaceOrientation) -> Self {
        jobs_navBlocksProxy()?.preferredInterfaceOrientationForPresentation = block
        return self
    }

    @discardableResult
    public func supportedInterfaceOrientations(_ block: @escaping (AnyObject,
                                                                   UINavigationController)
                                               -> UIInterfaceOrientationMask) -> Self {
        jobs_navBlocksProxy()?.supportedInterfaceOrientations = block
        return self
    }
}
// MARK: - Proxy
private final class JobsNavigationControllerBlocksProxy: NSObject, UINavigationControllerDelegate {
    weak var target: AnyObject?
    // MARK: 转场
    var animationControllerForOperation: ((AnyObject,
                                          UINavigationController,
                                          UINavigationController.Operation,
                                          UIViewController,
                                          UIViewController) -> UIViewControllerAnimatedTransitioning?)?

    func navigationController(_ navigationController: UINavigationController,
                              animationControllerFor operation: UINavigationController.Operation,
                              from fromVC: UIViewController,
                              to toVC: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        guard let t = target else { return nil };return animationControllerForOperation?(t,
                                                navigationController,
                                                operation,
                                                fromVC,
                                                toVC)
    }

    var interactionControllerForAnimationController: ((AnyObject,
                                                      UINavigationController,
                                                      UIViewControllerAnimatedTransitioning)
                                                      -> UIViewControllerInteractiveTransitioning?)?

    func navigationController(_ navigationController: UINavigationController,
                              interactionControllerFor animationController: UIViewControllerAnimatedTransitioning) -> UIViewControllerInteractiveTransitioning? {
        guard let t = target else { return nil };return interactionControllerForAnimationController?(t, navigationController, animationController)
    }
    // MARK: 显示回调
    var willShow: ((AnyObject, UINavigationController, UIViewController, Bool) -> Void)?
    func navigationController(_ navigationController: UINavigationController,
                              willShow viewController: UIViewController,
                              animated: Bool) {
        guard let t = target else { return }
        willShow?(t, navigationController, viewController, animated)
    }

    var didShow: ((AnyObject, UINavigationController, UIViewController, Bool) -> Void)?
    func navigationController(_ navigationController: UINavigationController,
                              didShow viewController: UIViewController,
                              animated: Bool) {
        guard let t = target else { return }
        didShow?(t, navigationController, viewController, animated)
    }

    // MARK: 方向
    var preferredInterfaceOrientationForPresentation: ((AnyObject, UINavigationController) -> UIInterfaceOrientation)?
    func navigationControllerPreferredInterfaceOrientationForPresentation(_ navigationController: UINavigationController) -> UIInterfaceOrientation {
        guard let t = target else { return .portrait };return preferredInterfaceOrientationForPresentation?(t, navigationController) ?? .portrait
    }

    var supportedInterfaceOrientations: ((AnyObject, UINavigationController) -> UIInterfaceOrientationMask)?
    func navigationControllerSupportedInterfaceOrientations(_ navigationController: UINavigationController) -> UIInterfaceOrientationMask {
        guard let t = target else { return .all };return supportedInterfaceOrientations?(t, navigationController) ?? .all
    }
}

private var proxyNavKey: UInt8 = 0
extension UINavigationController {
    private func jobs_navBlocksProxy(createIfNeeded: Bool = true) -> JobsNavigationControllerBlocksProxy? {
        if let p = objc_getAssociatedObject(self, &proxyNavKey) as? JobsNavigationControllerBlocksProxy {
            return p
        }
        guard createIfNeeded else { return nil }
        let p = JobsNavigationControllerBlocksProxy()
        objc_setAssociatedObject(
            self,
            &proxyNavKey,
            p,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC);return p
    }
}
