//
//  UIViewController+DSL.swift
//  JobsByUIKit
//
//  Created by Jobs on 2026年5月13日，星期三.
//

#if os(OSX)
import AppKit
#elseif os(iOS) || os(tvOS)
import UIKit
#endif

import JobsSwiftBlock
import JobsSwiftBaseDefines

@MainActor
// MARK: - 直接赋值@单参数
extension UIViewController {
    // ================================== 标题 / 背景 ==================================
    @discardableResult
    public func byTitle(_ title: String?) -> Self {
        self.title = title
        return self
    }

    @discardableResult
    public func byBackgroundColor(_ color: UIColor) -> Self {
        if viewIfLoaded == nil { loadViewIfNeeded() }
        view.byBackgroundColor(color)
        return self
    }

    @discardableResult
    public func byFrame(_ frame: CGRect) -> Self {
        self.view.frame = frame
        return self
    }
    // ================================== Modal 属性 ==================================
    @discardableResult
    public func byModalPresentationStyle(_ style: UIModalPresentationStyle) -> Self {
        self.modalPresentationStyle = style
        return self
    }

    @discardableResult
    public func byModalTransitionStyle(_ style: UIModalTransitionStyle) -> Self {
        self.modalTransitionStyle = style
        return self
    }

    @available(iOS 18.0, *)
    @discardableResult
    public func byPreferredTransition(_ transition: UIViewController.Transition?) -> Self {
        self.preferredTransition = transition
        return self
    }

    @available(iOS 7.0, *)
    @discardableResult
    public func byTransitioningDelegate(_ delegate: UIViewControllerTransitioningDelegate?) -> Self {
        self.transitioningDelegate = delegate
        return self
    }
    // ================================== Content Size / Layout ==================================
    @discardableResult
    public func byPreferredContentSize(_ size: CGSize) -> Self {
        self.preferredContentSize = size
        return self
    }

    @discardableResult
    public func byEdgesForExtendedLayout(_ edges: UIRectEdge) -> Self {
        self.edgesForExtendedLayout = edges
        return self
    }

    @discardableResult
    public func byExtendedLayoutIncludesOpaqueBars(_ flag: Bool) -> Self {
        self.extendedLayoutIncludesOpaqueBars = flag
        return self
    }

    @discardableResult
    public func byAutomaticallyAdjustsScrollInsets(_ flag: Bool) -> Self {
        if #available(iOS 11.0, *) {
            assertionFailure("iOS 11+ 请使用 UIScrollView.contentInsetAdjustmentBehavior")
        } else {
            self.automaticallyAdjustsScrollViewInsets = flag
        };return self
    }
    // ================================== 状态栏 / 外观 ==================================
    @available(iOS 13.0, *)
    @discardableResult
    public func byOverrideUserInterfaceStyle(_ style: UIUserInterfaceStyle) -> Self {
        self.overrideUserInterfaceStyle = style
        return self
    }
    // ================================== 焦点 / 交互追踪（TV / iOS 15+） ==================================
    @available(iOS 15.0, *)
    @discardableResult
    public func byFocusGroupIdentifier(_ id: String?) -> Self {
        self.focusGroupIdentifier = id
        return self
    }

    @available(iOS 16.0, *)
    @discardableResult
    public func byInteractionActivityBaseName(_ name: String?) -> Self {
        self.interactionActivityTrackingBaseName = name
        return self
    }
}
@MainActor
// MARK: - 闭包重载@单参数
extension UIViewController {
    @discardableResult
    public func byView(_ builder: (UIView) -> Void) -> Self {
        builder(view)
        return self
    }

    @discardableResult
    public func byTitle(_ builder: () -> String?) -> Self {
        self.title = builder()
        return self
    }

    @discardableResult
    public func byBackgroundColor(_ builder: () -> UIColor) -> Self {
        if viewIfLoaded == nil { loadViewIfNeeded() }
        self.view.backgroundColor = builder()
        return self
    }

    @discardableResult
    public func byFrame(_ builder: () -> CGRect) -> Self {
        self.view.frame = builder()
        return self
    }

    @discardableResult
    public func byModalPresentationStyle(_ builder: () -> UIModalPresentationStyle) -> Self {
        self.modalPresentationStyle = builder()
        return self
    }

    @discardableResult
    public func byModalTransitionStyle(_ builder: () -> UIModalTransitionStyle) -> Self {
        self.modalTransitionStyle = builder()
        return self
    }

    @available(iOS 18.0, *)
    @discardableResult
    public func byPreferredTransition(_ builder: () -> UIViewController.Transition?) -> Self {
        self.preferredTransition = builder()
        return self
    }

    @available(iOS 7.0, *)
    @discardableResult
    public func byTransitioningDelegate(_ builder: () -> UIViewControllerTransitioningDelegate?) -> Self {
        self.transitioningDelegate = builder()
        return self
    }

    @discardableResult
    public func byPreferredContentSize(_ builder: () -> CGSize) -> Self {
        self.preferredContentSize = builder()
        return self
    }

    @discardableResult
    public func byEdgesForExtendedLayout(_ builder: () -> UIRectEdge) -> Self {
        self.edgesForExtendedLayout = builder()
        return self
    }

    @discardableResult
    public func byExtendedLayoutIncludesOpaqueBars(_ builder: () -> Bool) -> Self {
        self.extendedLayoutIncludesOpaqueBars = builder()
        return self
    }

    @discardableResult
    public func byAutomaticallyAdjustsScrollInsets(_ builder: () -> Bool) -> Self {
        let flag = builder()
        if #available(iOS 11.0, *) {
            assertionFailure("iOS 11+ 请使用 UIScrollView.contentInsetAdjustmentBehavior")
        } else {
            self.automaticallyAdjustsScrollViewInsets = flag
        };return self
    }

    @available(iOS 13.0, *)
    @discardableResult
    public func byOverrideUserInterfaceStyle(_ builder: () -> UIUserInterfaceStyle) -> Self {
        self.overrideUserInterfaceStyle = builder()
        return self
    }

    @available(iOS 15.0, *)
    @discardableResult
    public func byFocusGroupIdentifier(_ builder: () -> String?) -> Self {
        self.focusGroupIdentifier = builder()
        return self
    }

    @available(iOS 16.0, *)
    @discardableResult
    public func byInteractionActivityBaseName(_ builder: () -> String?) -> Self {
        self.interactionActivityTrackingBaseName = builder()
        return self
    }
}

@MainActor
extension UIViewController {
    // ================================== Segue ==================================
    @discardableResult
    public func byPerformSegue(_ identifier: String, sender: Any? = nil) -> Self {
        self.performSegue(withIdentifier: identifier, sender: sender)
        return self
    }
    // ================================== Modal 展示 / 解散 ==================================
    // ⚠️ 已删除：byPresent(_ viewController: UIViewController, ...) 这个容易误用的重载
    // 如果确实想保留，请放开下面注释，并保留所有护栏（强烈建议不要改）：
    /*
    @discardableResult
    func byPresent(_ viewController: UIViewController,
                   animated: Bool = false,
                   jobsByVoidBlock: (jobsByVoidBlock)? = nil) -> Self {
        // 强力护栏：禁止 present 已挂载 / 正在展示 / 自己
        guard viewController !== self else {
            assertionFailure("❌ Don't present self on self")
            return self
        }
        guard viewController.parent == nil, viewController.presentingViewController == nil else {
            assertionFailure("❌ Trying to present a VC that already has a parent/presentingVC: \(viewController)")
            return self
        }
        // 宿主自己必须在 window 上，且不在 dismiss
        guard self.viewIfLoaded?.window != nil, self.isBeingDismissed == false else {
            assertionFailure("❌ Host not in window or being dismissed: \(self)")
            return self
        }
        self.present(viewController, animated: animated, jobsByVoidBlock: jobsByVoidBlock)
        return self
    }
    */
    /// 统一语义化 dismiss
    @discardableResult
    public func byDismiss(animated: Bool = true,
                          completion: (jobsByVoidBlock)? = nil) -> Self {
        self.dismiss(animated: animated, completion: completion)
        return self
    }
    // ================================== Content Size / Layout ==================================
    public var jobs_preferredContentSize: CGSize {
        self.preferredContentSize
    }
    // ================================== show / showDetail（安全命名） ==================================
    @discardableResult
    public func byShow(_ vc: UIViewController, sender: Any? = nil) -> Self {
        self.show(vc, sender: sender)
        return self
    }

    @discardableResult
    public func byShowDetail(_ vc: UIViewController, sender: Any? = nil) -> Self {
        self.showDetailViewController(vc, sender: sender)
        return self
    }

    @discardableResult
    public func byNeedsStatusBarUpdate() -> Self {
        self.setNeedsStatusBarAppearanceUpdate()
        return self
    }

    @discardableResult
    public func byPreferredStatusBarStyle(_ style: UIStatusBarStyle) -> Self {
        assertionFailure("请在子类中 override preferredStatusBarStyle 实现此功能")
        return self
    }
    // ================================== 子控制器管理 ==================================
    @discardableResult
    public func addChildVC(_ child: UIViewController,
                           into container: UIView? = nil,
                           layout: (jobsByViewBlock)? = nil) -> Self {
        self.addChild(child)
        if viewIfLoaded == nil { loadViewIfNeeded() }
        let host = container ?? self.view!
        host.addSubview(child.view)
        layout?(child.view)
        child.didMove(toParent: self)
        return self
    }

    @discardableResult
    public func addChildVC(_ child: UIViewController) -> Self {
        self.addChild(child)
        self.view.addSubview(child.view)
        child.didMove(toParent: self)
        return self
    }

    @discardableResult
    public func removeFromParentVC() -> Self {
        guard parent != nil else { return self }
        self.willMove(toParent: nil)
        self.view.removeFromSuperview()
        self.removeFromParent()
        return self
    }

    public var jobs_hasParent: Bool { self.parent != nil }
    // ================================== 滚动联动（iOS15+） ==================================
    @available(iOS 15.0, *)
    @discardableResult
    public func byContentScrollView(_ scrollView: UIScrollView?, for edge: NSDirectionalRectEdge) -> Self {
        self.setContentScrollView(scrollView, for: edge)
        return self
    }

    @available(iOS 15.0, *)
    public var jobs_contentScrollViewTop: UIScrollView? {
        self.contentScrollView(for: .top)
    }
    // ================================== iOS 26+ 属性更新批 ==================================
    @available(iOS 26.0, *)
    @discardableResult
    public func bySetNeedsUpdateProperties() -> Self {
        self.setNeedsUpdateProperties()
        return self
    }

    @available(iOS 26.0, *)
    @discardableResult
    public func byUpdatePropertiesIfNeeded() -> Self {
        self.updatePropertiesIfNeeded()
        return self
    }
}
