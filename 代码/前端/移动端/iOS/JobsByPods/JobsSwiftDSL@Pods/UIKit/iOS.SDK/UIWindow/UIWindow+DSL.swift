//
//  UIWindow+DSL.swift
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

// MARK: - 直接赋值@单参数
extension UIWindow {
    /// 绑定到指定 WindowScene（不会 makeKeyAndVisible）
    /// - 兼容：iOS 12 也能编译。iOS 13+ 可进一步用 byAttach(toScene:)
    @discardableResult
    public func byAttach(to scene: Any?) -> Self {
        if #available(iOS 13.0, *) {
            return byAttach(toScene: scene as? UIWindowScene)
        };return self
    }
    /// 绑定到指定 WindowScene（不会 makeKeyAndVisible）
    /// - iOS 13+ 专用（真正做事）
    @available(iOS 13.0, tvOS 13.0, *)
    @discardableResult
    public func byAttach(toScene scene: UIWindowScene?) -> Self {
        if let scene {
            if self.windowScene !== scene {
                self.windowScene = scene
            }
        };return self
    }
    // MARK: - 根控制器 / 可见性
    @discardableResult
    public func byRootViewController(_ vc: UIViewController?) -> Self {
        self.rootViewController = vc
        return self
    }
    // MARK: - 外观 / 显示层级
    @discardableResult
    public func byWindowLevel(_ level: UIWindow.Level) -> Self {
        self.windowLevel = level
        return self
    }

    @discardableResult
    public func byScreen(_ screen: UIScreen) -> Self {
        if #available(iOS 13.0, *) {
            if let scene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.screen == screen }) {
                self.windowScene = scene
            }
        } else {
            self.screen = screen
        };return self
    }
}
// MARK: - 闭包重载@单参数
extension UIWindow {
    @discardableResult
    public func byAttach(to builder: () -> Any?) -> Self {
        if #available(iOS 13.0, *) {
            return byAttach(toScene: builder() as? UIWindowScene)
        };return self
    }

    @available(iOS 13.0, tvOS 13.0, *)
    @discardableResult
    public func byAttach(toScene builder: () -> UIWindowScene?) -> Self {
        let scene = builder()
        if let scene {
            if self.windowScene !== scene {
                self.windowScene = scene
            }
        };return self
    }

    @discardableResult
    public func byRootViewController(_ builder: () -> UIViewController?) -> Self {
        self.rootViewController = builder()
        return self
    }

    @discardableResult
    public func byWindowLevel(_ builder: () -> UIWindow.Level) -> Self {
        self.windowLevel = builder()
        return self
    }

    @discardableResult
    public func byScreen(_ builder: () -> UIScreen) -> Self {
        let screen = builder()
        if #available(iOS 13.0, *) {
            if let scene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.screen == screen }) {
                self.windowScene = scene
            }
        } else {
            self.screen = screen
        };return self
    }
}

extension UIWindow {
    /// 仅 makeKey
    @discardableResult
    public func byMakeKey() -> Self {
        self.makeKey()
        return self
    }
    /// makeKeyAndVisible（最常用）
    @discardableResult
    public func byMakeKeyAndVisible() -> Self {
        self.makeKeyAndVisible()
        return self
    }
    /// 退位（让位于别的 window）
    @discardableResult
    public func byResignKey() -> Self {
        self.resignKey()
        return self
    }
    // MARK: - 工具方法（少量“好用但容易踩坑”的动作）
    /// 快照整窗（不跨进程，不含系统状态栏）
    public func snapshotImage(afterScreenUpdates: Bool = true) -> UIImage? {
        UIGraphicsImageRenderer(bounds: bounds).image { _ in
            self.drawHierarchy(in: self.bounds, afterScreenUpdates: afterScreenUpdates)
        }
    }
    /// 在最顶层控制器 present 一个 VC（避免直接对 window 做 VC 管理）
    @discardableResult
    public func presentOnTop(_ vc: UIViewController,
                             animated: Bool = true,
                             completion: (jobsByVoidBlock)? = nil) -> Self {
        guard let host = UIWindow.jobsTopMost(from: self.rootViewController) else { return self }
        // 宿主正在转场就别叠
        if host.transitionCoordinator != nil { return self }
        // 目标不能已经挂载
        if vc.parent != nil || vc.presentingViewController != nil { return self }
        host.present(vc, animated: animated, completion: completion)
        return self
    }
    // MARK: - 坐标转换（链式味道）
    @discardableResult
    public func byConvert(_ point: CGPoint,
                          to other: UIWindow?,
                          sink: jobsByPointBlock) -> Self {
        sink(convert(point, to: other))
        return self
    }

    @discardableResult
    public func byConvert(_ rect: CGRect,
                          to other: UIWindow?,
                          sink: jobsByFrameBlock) -> Self {
        sink(convert(rect, to: other))
        return self
    }
}
