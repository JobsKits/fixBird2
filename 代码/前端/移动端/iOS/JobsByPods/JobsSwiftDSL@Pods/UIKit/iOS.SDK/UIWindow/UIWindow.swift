//
//  UIWindow.swift
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

extension UIWindow {
    /// 返回一个“保证非空”的 UIWindow
    /// - 优先 jobsKeyWindow（真实窗口）
    /// - 取不到时兜底创建一个离屏窗口，避免 unwrap 报错
    public static var wd: UIWindow {
        if let real = UIApplication.jobsKeyWindow() {
            return real
        } else {
            // ✅ 构造一个兜底 window（不会显示，只用于防止 nil）
            return UIWindow(frame: UIScreen.main.bounds).byWindowLevel(.alert + 1)
        }
    }
    /// 实例访问也保持一致
    public var wd: UIWindow { Self.wd }
    // ================================== 跨版本入口：iOS 12+ 可编译 ==================================
    @discardableResult
    public static func jobsMake(root: UIViewController? = nil,
                                level: UIWindow.Level = .normal,
                                makeKeyVisible: Bool = true) -> UIWindow {
        // iOS 13+ 走 scene 路径；iOS 12- 走 frame 路径
        if #available(iOS 13.0, *) {
            return jobsMake(scene: nil,
                            root: root,
                            level: level,
                            makeKeyVisible: makeKeyVisible)
        } else {
            return UIWindow(frame: UIScreen.main.bounds)
                .byRootViewController(root)
                .byWindowLevel(level)
                ._makeIfNeeded(makeKeyVisible)
        }
    }
    /// 新建并附着到“最合适”的前台 scene（iOS 26+ 不要再用 init(frame:)）
    @available(iOS 13.0, tvOS 13.0, *)
    @discardableResult
    public static func jobsMake(scene: UIWindowScene? = nil,
                                root: UIViewController? = nil,
                                level: UIWindow.Level = .normal,
                                makeKeyVisible: Bool = true) -> UIWindow {
        let targetScene: UIWindowScene? = {
            if let scene { return scene };return UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .first { $0.activationState == .foregroundActive }
                ?? UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        }()
        let win: UIWindow
        if let s = targetScene {
            win = UIWindow(windowScene: s)
        } else {
            // 极端兜底：没拿到 scene 时也能创建（理论上很少见）
            win = UIWindow(frame: UIScreen.main.bounds)
        };return win
            .byRootViewController(root)
            .byWindowLevel(level)
            ._makeIfNeeded(makeKeyVisible)
    }
    // 顶层 VC（跨 UINavigationController / UITabBarController / presented 链）
    public static func jobsTopMost(from base: UIViewController?) -> UIViewController? {
        guard let base else { return nil }
        if let nav = base as? UINavigationController {
            return jobsTopMost(from: nav.visibleViewController ?? nav.topViewController)
        }
        if let tab = base as? UITabBarController {
            return jobsTopMost(from: tab.selectedViewController)
        }
        if let presented = base.presentedViewController {
            return jobsTopMost(from: presented)
        };return base
    }
    // 私有小工具：是否 makeKeyAndVisible
    @discardableResult
    private func _makeIfNeeded(_ flag: Bool) -> Self {
        if flag { self.makeKeyAndVisible() };return self
    }
}
