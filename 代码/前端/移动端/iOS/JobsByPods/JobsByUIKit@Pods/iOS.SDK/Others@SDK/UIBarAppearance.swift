//
//  UIBarAppearance.swift
//  JobsByUIKit
//
//  Created by Jobs on 2026年5月13日，星期三.
//

#if os(OSX)
import AppKit
#elseif os(iOS) || os(tvOS)
import UIKit
#endif

import JobsSwiftBaseDefines

@available(iOS 13.0, *)
extension UIBarAppearance {
    // MARK: - 1. 背景预设 configureXXX
    /// 系统默认背景（跟随主题）
    @discardableResult
    public func byDefaultBackground() -> Self {
        configureWithDefaultBackground()
        return self
    }
    /// 不透明背景（常用场景）
    @discardableResult
    public func byOpaqueBackground(_ color: UIColor? = nil) -> Self {
        configureWithOpaqueBackground()
        if let color {
            backgroundColor = color
        };return self
    }
    /// 透明背景（导航栏悬浮、全屏滚动那种）
    @discardableResult
    public func byTransparentBackground() -> Self {
        configureWithTransparentBackground()
        return self
    }
    // MARK: - 2. 背景内容（effect / color / image）
    /// 背景毛玻璃效果
    @discardableResult
    public func byBackgroundEffect(_ effect: UIBlurEffect?) -> Self {
        backgroundEffect = effect
        return self
    }
    /// 背景纯色
    @discardableResult
    public func byBackgroundColor(_ color: UIColor?) -> Self {
        backgroundColor = color
        return self
    }
    /// 背景图
    @discardableResult
    public func byBackgroundImage(_ image: UIImage?) -> Self {
        self.backgroundImage = image
        return self
    }
    /// 背景图（可选顺便设 contentMode）
    @discardableResult
    public func byBackgroundImage(_ image: UIImage?,
                           contentMode: UIView.ContentMode? = nil) -> Self {
        backgroundImage = image
        if let mode = contentMode {
            backgroundImageContentMode = mode
        };return self
    }
    /// 单独改背景图 contentMode
    @discardableResult
    public func byBackgroundImageContentMode(_ mode: UIView.ContentMode) -> Self {
        backgroundImageContentMode = mode
        return self
    }
    // MARK: - 3. 阴影（shadow）
    /// 阴影颜色（传 nil / JobsCor.clear 代表不要阴影）
    @discardableResult
    public func byShadowColor(_ color: UIColor?) -> Self {
        shadowColor = color
        return self
    }
    /// 阴影图（优先级高于 shadowColor）
    @discardableResult
    public func byShadowImage(_ image: UIImage?) -> Self {
        shadowImage = image
        return self
    }
    // MARK: - 4. 组合辅助
    /// 一次性指定：毛玻璃 + 背景色 + 阴影
    @discardableResult
    public func byBackground(
        effect: UIBlurEffect? = nil,
        color: UIColor? = nil,
        shadowColor: UIColor? = nil,
        shadowImage: UIImage? = nil
    ) -> Self {
        backgroundEffect = effect
        backgroundColor = color
        self.shadowColor = shadowColor
        self.shadowImage = shadowImage
        return self
    }
}
