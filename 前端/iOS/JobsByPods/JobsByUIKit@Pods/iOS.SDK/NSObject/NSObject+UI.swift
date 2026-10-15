//
//  NSObject+UI.swift
//  JobsByUIKit
//
//  Created by Jobs on 2026年5月13日，星期三.
//

#if os(OSX)
import AppKit
#elseif os(iOS) || os(tvOS)
import UIKit
#endif

extension NSObject {
    // 更稳的 rootVC 获取：优先前台激活场景 + 兼容 iOS13/14
    // 仅使用 UIWindowScene.windows，不再触发 UIApplication.shared.windows 的弃用告警
    @inline(__always)
    public func activeRootViewController() -> UIViewController? {
        if #available(iOS 13.0, *) {
            let scenes = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .sorted { lhs, rhs in
                    func rank(_ s: UIScene.ActivationState) -> Int {
                        switch s {
                        /// 处理 .foregroundActive 分支
                        case .foregroundActive:   return 0
                        /// 处理 .foregroundInactive 分支
                        case .foregroundInactive: return 1
                        /// 未匹配已知分支时执行兜底处理
                        default:                  return 2
                        }
                    };return rank(lhs.activationState) < rank(rhs.activationState)
                }
            for scene in scenes {
                if let key = scene.keyWindowCompat { return key.rootViewController }
                if let anyOnScreen = scene.windows.first(where: { !$0.isHidden && $0.alpha > 0 }) {
                    return anyOnScreen.rootViewController
                }
            };return nil
        } else {
            // iOS 12 及以下兜底：这里不会在新系统路径上编译执行，因此不会产生警告
            return UIApplication.shared.keyWindow?.rootViewController
                ?? UIApplication.shared.delegate?.window??.rootViewController
        }
    }
    /// 获取“屏幕上可见”的顶部控制器（递归 + 全容器支持）
    /// - 参数 base: 初始控制器（默认从前台激活场景 rootVC 开始）
    public func topViewController(
        base: UIViewController? = nil
    ) -> UIViewController? {
        // 如果没传 base，就自动拿当前激活场景的 rootVC
        let base = base ?? activeRootViewController()
        guard let base else { return nil }
        // 防止自引用死循环
        func next(_ candidate: UIViewController?) -> UIViewController? {
            guard let vc = candidate, vc !== base else { return nil };return vc
        }
        // 1) 优先穿透 present
        if let presented = next(base.presentedViewController) {
            return topViewController(base: presented)
        }
        // 2) 导航控制器
        if let nav = base as? UINavigationController {
            return topViewController(base: next(nav.visibleViewController ?? nav.topViewController))
        }
        // 3) TabBar 控制器
        if let tab = base as? UITabBarController,
           let sel = next(tab.selectedViewController) {
            return topViewController(base: sel)
        }
        // 4) Split（取最后一个）
        if let split = base as? UISplitViewController,
           let last = next(split.viewControllers.last) {
            return topViewController(base: last)
        }
        // 5) PageVC
        if let page = base as? UIPageViewController,
           let cur = next(page.viewControllers?.first) {
            return topViewController(base: cur)
        }
        // 6) 自定义容器
        if !base.children.isEmpty {
            if let onScreen = base.children.first(where: { $0.viewIfLoaded?.window != nil }),
               let vc = next(onScreen) {
                return topViewController(base: vc)
            }
            if let last = next(base.children.last) {
                return topViewController(base: last)
            }
        };return base // 7) 没有更深层就返回当前
    }

    public func activeKeyWindow() -> UIWindow? {
        if #available(iOS 13.0, *) {
            for scene in UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }) {
                if #available(iOS 15.0, *), let key = scene.keyWindow { return key }
                if let key = scene.windows.first(where: { $0.isKeyWindow }) { return key }
                if let visible = scene.windows.first(where: { !$0.isHidden && $0.alpha > 0 }) { return visible }
            };return nil
        } else {
            // < iOS13 用老API
            return legacyKeyWindowPreiOS13()
        }
    }
    // MARK: - 顶部导航控制器（更健壮）
    public func topNavController() -> UINavigationController? {
        guard Thread.isMainThread else {
            return DispatchQueue.main.sync { topNavController() }
        }
        guard let rootVC = activeKeyWindow()?.rootViewController else { return nil }
        guard let topVC = visibleViewController(from: rootVC) else { return nil }
        // 1) 顶部就是导航
        if let nav = topVC as? UINavigationController { return nav }
        // 2) 顶部所在的导航
        if let nav = topVC.navigationController { return nav }
        // 3) 顶部是 TabBar 且选中项为导航
        if let tab = topVC as? UITabBarController,
           let sel = tab.selectedViewController as? UINavigationController { return sel };return nil
    }
    // MARK: - 获取顶部控制器
    public func topViewController() -> UIViewController? {
        guard Thread.isMainThread else { return DispatchQueue.main.sync { topViewController() } }
        guard let rootVC = activeKeyWindow()?.rootViewController else { return nil };return visibleViewController(from: rootVC)
    }
    // MARK: - 核心：寻找“可见 VC”（容器全面覆盖）
    public func visibleViewController(from root: UIViewController?, depth: Int = 0) -> UIViewController? {
        guard let root = root, depth < 32 else { return root } // 防御：最大 32 层
        // 1) 先穿透被 present 的 VC
        if let presented = root.presentedViewController {
            return visibleViewController(from: presented, depth: depth + 1)
        }
        // 2) 导航：用 visible/top（更贴近“屏幕上看到的”）
        if let nav = root as? UINavigationController {
            return visibleViewController(from: nav.visibleViewController ?? nav.topViewController, depth: depth + 1)
        }
        // 3) Tab：选中的那个
        if let tab = root as? UITabBarController, let sel = tab.selectedViewController {
            return visibleViewController(from: sel, depth: depth + 1)
        }
        // 4) Split：一般取最后（detail）
        if let split = root as? UISplitViewController, let last = split.viewControllers.last {
            return visibleViewController(from: last, depth: depth + 1)
        }
        // 5) PageVC：当前展示的第一个
        if let page = root as? UIPageViewController, let cur = page.viewControllers?.first {
            return visibleViewController(from: cur, depth: depth + 1)
        }
        // 6) 自定义容器：挑在窗口上的那个
        if !root.children.isEmpty {
            let onScreen = root.children.first(where: { $0.viewIfLoaded?.window != nil })
            if let onScreen { return visibleViewController(from: onScreen, depth: depth + 1) }
            // 没有明确在窗口的，就保守取最后一个
            return visibleViewController(from: root.children.last, depth: depth + 1)
        };return root // 7) 叶子节点
    }
}
