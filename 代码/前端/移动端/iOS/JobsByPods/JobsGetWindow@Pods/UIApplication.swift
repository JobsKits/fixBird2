//
//  UIApplication.swift
//  JobsGetWindow
//
//  Created by Jobs on 2026年5月13日，星期三.
//

#if os(OSX)
import AppKit
#elseif os(iOS) || os(tvOS)
import UIKit
#endif

/**
     // 取 keyWindow
     let win = UIApplication.jobsKeyWindow()

     // 取最顶层可见 VC（做 push/present 的宿主）
     if let topVC = UIApplication.jobsTopMostVC() {
         // ... 用 topVC 做 present 或的 pushSafely 入口
     }
 */
// MARK: - Key Window（跨版本最大兼容）
// =======================================================
// UIApplication + UI 层级工具（零弃用警告 / 多 Scene 兼容）
// =======================================================
public extension UIApplication {
    // MARK: - 对外 API
    /// ① 获取“最合理”的 Key Window（多 Scene / 外接屏 / 可见性 / windowLevel 兼容）
    /// - Parameter scene: 指定 UIScene；nil 则自动从所有 connectedScenes 中择优
    /// - Parameter preferMainScreen: 是否优先主屏幕（避免拿到外接屏/CarPlay 的 window）
    /// 通用版本：iOS 12 及以下也能编译
    static func jobsKeyWindow(preferMainScreen: Bool = true) -> UIWindow? {
        if #available(iOS 13.0, *) {
            guard let ws = bestWindowScene() else { return nil };return bestWindow(in: ws, preferMainScreen: preferMainScreen)
        } else {
            return UIApplication.shared.keyWindow
        }
    }
    /// iOS 13+ 才暴露 UIScene 参数
    @available(iOS 13.0, *)
    static func jobsKeyWindow(in scene: UIScene?,
                              preferMainScreen: Bool = true) -> UIWindow? {
        let ws = (scene as? UIWindowScene) ?? bestWindowScene()
        guard let ws else { return nil };return bestWindow(in: ws, preferMainScreen: preferMainScreen)
    }
    /// ② 顶层“可见 VC”（支持 Nav/Tab/Split/Page/Presented；可选忽略 Alert）
    /// - Parameters:
    ///   - root: 指定起点 VC；默认自动取 rootVC
    ///   - scene: 指定场景；默认自动选择前台/最合理的
    ///   - ignoreAlert: 是否忽略 UIAlertController（比如做 present 宿主时可忽略）
    /// iOS 12 也能编译：不暴露 UIScene
    static func jobsTopMostVC(
        from root: UIViewController? = nil,
        ignoreAlert: Bool = false
    ) -> UIViewController? {
        let rootVC: UIViewController? = {
            if let root { return root }
            if #available(iOS 13.0, *) {
                guard let ws = bestWindowScene(),
                      let r = bestRootViewController(in: ws) else { return nil };return r
            } else {
                return UIApplication.shared.keyWindow?.rootViewController
            }
        }();return _jobsVisibleVC(from: rootVC, ignoreAlert: ignoreAlert)
    }
    /// iOS 13+ 才提供 scene 版本
    @available(iOS 13.0, *)
    static func jobsTopMostVC(
        from root: UIViewController? = nil,
        in scene: UIScene?,
        ignoreAlert: Bool = false
    ) -> UIViewController? {
        let rootVC: UIViewController? = {
            if let root { return root }
            let ws = (scene as? UIWindowScene) ?? bestWindowScene()
            guard let ws,
                  let r = bestRootViewController(in: ws) else { return nil };return r
        }();return _jobsVisibleVC(from: rootVC, ignoreAlert: ignoreAlert)
    }
    /// 递归下钻逻辑提取成私有方法，两个重载共用
    private static func _jobsVisibleVC(
        from vc: UIViewController?,
        ignoreAlert: Bool
    ) -> UIViewController? {
        guard let vc else { return nil }
        if let presented = vc.presentedViewController,
           !presented.isBeingDismissed,
           !(ignoreAlert && presented is UIAlertController) {
            return _jobsVisibleVC(from: presented, ignoreAlert: ignoreAlert)
        }
        let child: UIViewController?
        if let nav = vc as? UINavigationController {
            child = nav.visibleViewController ?? nav.topViewController
        } else if let tab = vc as? UITabBarController {
            child = tab.selectedViewController
        } else if let split = vc as? UISplitViewController {
            child = split.viewControllers.last
        } else if let page = vc as? UIPageViewController {
            child = page.viewControllers?.first
        } else {
            child = nil
        }
        guard let child, child !== vc else { return vc }
        return _jobsVisibleVC(from: child, ignoreAlert: ignoreAlert)
    }
    /// ③ 全局安全区 Insets（不依赖当前 VC）
    static var jobsSafeAreaInsets: UIEdgeInsets {
        return jobsKeyWindow()?.safeAreaInsets ?? .zero
    }
    /// ④ 四个边的便捷访问
    static var jobsSafeTopInset: CGFloat { jobsSafeAreaInsets.top }
    static var jobsSafeBottomInset: CGFloat { jobsSafeAreaInsets.bottom }
    static var jobsSafeLeftInset: CGFloat { jobsSafeAreaInsets.left }
    static var jobsSafeRightInset: CGFloat { jobsSafeAreaInsets.right }
    /// ⑤ 是否“刘海/全面屏 iPhone”（本质：是否存在 Home Indicator 的底部安全区）
    /// ✅ 模拟器同样有效（取决于你选的机型）
    static var jobsIsNotchPhone: Bool {
        UIDevice.current.userInterfaceIdiom == .phone && jobsSafeBottomInset > 0
    }
}
// MARK: - 内部实现（iOS 13+）
@available(iOS 13.0, *)
private extension UIApplication {
    /// 选择最“活跃/合理”的 windowScene（前台激活 > 前台非激活 > 其余）
    static func bestWindowScene() -> UIWindowScene? {
        func rank(_ s: UIScene.ActivationState) -> Int {
            switch s {
            /// 处理 .foregroundActive 分支
            case .foregroundActive:   return 0
            /// 处理 .foregroundInactive 分支
            case .foregroundInactive: return 1
            /// 处理 .background 分支
            case .background:         return 2
            /// 未匹配已知分支时执行兜底处理
            default:                  return 3
            }
        };return UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .sorted { rank($0.activationState) < rank($1.activationState) }
            .first
    }
    /// 在一个 windowScene 内选择“最佳窗口”
    static func bestWindow(in ws: UIWindowScene, preferMainScreen: Bool) -> UIWindow? {
        let windows = ws.windows
        guard !windows.isEmpty else { return nil }
        // 1) keyWindow 优先（iOS15 有 scene.keyWindow，但这里统一从 windows 里找）
        if let key = windows.first(where: \.isKeyWindow) {
            if !preferMainScreen || key.screen == UIScreen.main { return key }
        }
        // 2) 可见窗口优先：normal level > 非 normal
        func windowRank(_ w: UIWindow) -> (Int, Int, Int) {
            // 可见性：0(可见且normal) < 1(可见且非normal) < 2(不可见)
            let visibilityGroup: Int = {
                guard !w.isHidden, w.alpha > 0.01 else { return 2 };return (w.windowLevel == .normal) ? 0 : 1
            }()
            // 主屏优先
            let screenGroup = (preferMainScreen && w.screen != UIScreen.main) ? 1 : 0
            // 与 normal 的距离越小越好
            let levelDistance = Int(abs(w.windowLevel.rawValue - UIWindow.Level.normal.rawValue))
            return (visibilityGroup, screenGroup, levelDistance)
        };return windows.sorted { a, b in windowRank(a) < windowRank(b) }.first
    }
    /// 从 windowScene 取 rootVC（统一入口，供 jobsTopMostVC 使用）
    static func bestRootViewController(in ws: UIWindowScene) -> UIViewController? {
        bestWindow(in: ws, preferMainScreen: true)?.rootViewController
    }
}
