//
//  UINavigationBar.swift
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
extension UINavigationBar {
    /// barStyle（.default / .black 等）
    @discardableResult
    public func byBarStyle(_ style: UIBarStyle) -> Self {
        self.barStyle = style
        return self
    }
    /// 是否半透明
    @discardableResult
    public func byTranslucent(_ translucent: Bool) -> Self {
        self.isTranslucent = translucent
        return self
    }
    /// barTintColor（老 API，iOS13- 主要作用）
    @discardableResult
    public func byBarTintColor(_ color: UIColor?) -> Self {
        self.barTintColor = color
        return self
    }
    /// 是否使用大标题
    @discardableResult
    public func byPrefersLargeTitles(_ enable: Bool) -> Self {
        if #available(iOS 11.0, *) {
            self.prefersLargeTitles = enable
        };return self
    }
    /// 请求的行为风格（iOS16+）
    @available(iOS 15.0, *)
    @discardableResult
    public func byPreferredBehavioralStyle(_ style: UIBehavioralStyle) -> Self {
        if #available(iOS 16.0, *) {
            self.preferredBehavioralStyle = style
        };return self
    }

    @discardableResult
    public func byTitleTextAttributes(_ att: [NSAttributedString.Key: Any]?) -> Self {
        self.titleTextAttributes = att
        return self
    }

    @discardableResult
    public func byLargeTitleTextAttributes(_ att: [NSAttributedString.Key: Any]?) -> Self {
        self.largeTitleTextAttributes = att
        return self
    }
    /// 阴影图（下划线）
    @discardableResult
    public func byShadowImage(_ image: UIImage?) -> Self {
        self.shadowImage = image
        return self
    }
    /// 直接设置 standardAppearance
    @available(iOS 13.0, *)
    @discardableResult
    public func byStandardAppearance(_ appearance: UINavigationBarAppearance) -> Self {
        self.standardAppearance = appearance
        return self
    }
    /// 直接设置 compactAppearance（可为 nil）
    @available(iOS 13.0, *)
    @discardableResult
    public func byCompactAppearance(_ appearance: UINavigationBarAppearance?) -> Self {
        self.compactAppearance = appearance
        return self
    }
    /// 直接设置 scrollEdgeAppearance（可为 nil）
    @available(iOS 13.0, *)
    @discardableResult
    public func byScrollEdgeAppearance(_ appearance: UINavigationBarAppearance?) -> Self {
        self.scrollEdgeAppearance = appearance
        return self
    }
    /// 直接设置 compactScrollEdgeAppearance（可为 nil）
    @available(iOS 13.0, *)
    @discardableResult
    public func byCompactScrollEdgeAppearance(_ appearance: UINavigationBarAppearance?) -> Self {
        if #available(iOS 15.0, *) {
            self.compactScrollEdgeAppearance = appearance
        };return self
    }
    /// 用同一个 appearance 套到所有状态
    @available(iOS 13.0, *)
    @discardableResult
    public func byUnifiedAppearance(_ appearance: UINavigationBarAppearance) -> Self {
        self.standardAppearance = appearance
        self.scrollEdgeAppearance = appearance
        self.compactAppearance = appearance
        if #available(iOS 15.0, *) {
            self.compactScrollEdgeAppearance = appearance
        };return self
    }
}
// MARK: - 闭包重载@单参数
extension UINavigationBar {
    @discardableResult
    public func byBarStyle(_ builder: () -> UIBarStyle) -> Self {
        self.barStyle = builder()
        return self
    }

    @discardableResult
    public func byTranslucent(_ builder: () -> Bool) -> Self {
        self.isTranslucent = builder()
        return self
    }

    @discardableResult
    public func byBarTintColor(_ builder: () -> UIColor?) -> Self {
        self.barTintColor = builder()
        return self
    }

    @discardableResult
    public func byPrefersLargeTitles(_ builder: () -> Bool) -> Self {
        if #available(iOS 11.0, *) {
            self.prefersLargeTitles = builder()
        };return self
    }

    @available(iOS 15.0, *)
    @discardableResult
    public func byPreferredBehavioralStyle(_ builder: () -> UIBehavioralStyle) -> Self {
        if #available(iOS 16.0, *) {
            self.preferredBehavioralStyle = builder()
        };return self
    }

    @discardableResult
    public func byTitleTextAttributes(_ builder: () -> [NSAttributedString.Key: Any]?) -> Self {
        self.titleTextAttributes = builder()
        return self
    }

    @discardableResult
    public func byLargeTitleTextAttributes(_ builder: () -> [NSAttributedString.Key: Any]?) -> Self {
        self.largeTitleTextAttributes = builder()
        return self
    }

    @discardableResult
    public func byShadowImage(_ builder: () -> UIImage?) -> Self {
        self.shadowImage = builder()
        return self
    }

    @available(iOS 13.0, *)
    @discardableResult
    public func byStandardAppearance(_ builder: () -> UINavigationBarAppearance) -> Self {
        self.standardAppearance = builder()
        return self
    }

    @available(iOS 13.0, *)
    @discardableResult
    public func byCompactAppearance(_ builder: () -> UINavigationBarAppearance?) -> Self {
        self.compactAppearance = builder()
        return self
    }

    @available(iOS 13.0, *)
    @discardableResult
    public func byScrollEdgeAppearance(_ builder: () -> UINavigationBarAppearance?) -> Self {
        self.scrollEdgeAppearance = builder()
        return self
    }

    @available(iOS 13.0, *)
    @discardableResult
    public func byCompactScrollEdgeAppearance(_ builder: () -> UINavigationBarAppearance?) -> Self {
        if #available(iOS 15.0, *) {
            self.compactScrollEdgeAppearance = builder()
        };return self
    }

    @available(iOS 13.0, *)
    @discardableResult
    public func byUnifiedAppearance(_ builder: () -> UINavigationBarAppearance) -> Self {
        let appearance = builder()
        self.standardAppearance = appearance
        self.scrollEdgeAppearance = appearance
        self.compactAppearance = appearance
        if #available(iOS 15.0, *) {
            self.compactScrollEdgeAppearance = appearance
        };return self
    }
}

extension UINavigationBar {
    // ================================== 标题 attributes（旧 API，兼容 iOS13-） ==================================
    @discardableResult
    public func byLegacyTitleFont(_ font: UIFont?) -> Self {
        var attrs = titleTextAttributes ?? [:]
        if let font {
            attrs[.font] = font
        } else {
            attrs.removeValue(forKey: .font)
        };titleTextAttributes = attrs
        return self
    }

    @discardableResult
    public func byLegacyTitleColor(_ color: UIColor?) -> Self {
        var attrs = titleTextAttributes ?? [:]
        if let color {
            attrs[.foregroundColor] = color
        } else {
            attrs.removeValue(forKey: .foregroundColor)
        };titleTextAttributes = attrs
        return self
    }

    @discardableResult
    public func byLegacyLargeTitleFont(_ font: UIFont?) -> Self {
        if #available(iOS 11.0, *) {
            var attrs = largeTitleTextAttributes ?? [:]
            if let font {
                attrs[.font] = font
            } else {
                attrs.removeValue(forKey: .font)
            };largeTitleTextAttributes = attrs
        };return self
    }

    @discardableResult
    public func byLegacyLargeTitleColor(_ color: UIColor?) -> Self {
        if #available(iOS 11.0, *) {
            var attrs = largeTitleTextAttributes ?? [:]
            if let color {
                attrs[.foregroundColor] = color
            } else {
                attrs.removeValue(forKey: .foregroundColor)
            };largeTitleTextAttributes = attrs
        };return self
    }
    /// 垂直方向标题偏移（iOS13- 用得多）
    @discardableResult
    public func byTitleVerticalOffset(_ offset: CGFloat,
                                      for metrics: UIBarMetrics = .default) -> Self {
        setTitleVerticalPositionAdjustment(offset, for: metrics)
        return self
    }
    // ================================== 背景 & 阴影（老 API） ==================================
    /// 背景图片（简单版，按 barMetrics）
    @discardableResult
    public func byBackgroundImage(_ image: UIImage?,
                                  for metrics: UIBarMetrics = .default) -> Self {
        setBackgroundImage(image, for: metrics)
        return self
    }
    /// 背景图片（带 barPosition）
    @discardableResult
    public func byBackgroundImage(_ image: UIImage?,
                                  for position: UIBarPosition,
                                  metrics: UIBarMetrics = .default) -> Self {
        setBackgroundImage(image, for: position, barMetrics: metrics)
        return self
    }
    /// 返回按钮指示图标
    @discardableResult
    public func byBackIndicator(_ image: UIImage?, mask: UIImage? = nil) -> Self {
        backIndicatorImage = image
        backIndicatorTransitionMaskImage = mask ?? image
        return self
    }
    // ================================== Appearance（iOS13+） ==================================
    /// 配置 standardAppearance@闭包版
    @available(iOS 13.0, *)
    @discardableResult
    public func byStandardAppearance(_ builder: jobsByNavigationBarAppearanceBlock) -> Self {
        if #available(iOS 13.0, *) {
            let appearance = standardAppearance          // @NSCopying：这里拿到的是 copy
            builder(appearance)
            standardAppearance = appearance
        };return self
    }
    /// 配置 compactAppearance@闭包版（紧凑高度）
    @available(iOS 13.0, *)
    @discardableResult
    public func byCompactAppearance(_ builder: jobsByNavigationBarAppearanceBlock) -> Self {
        if #available(iOS 13.0, *) {
            let appearance = compactAppearance ?? standardAppearance
            builder(appearance)
            compactAppearance = appearance
        };return self
    }
    /// 配置 scrollEdgeAppearance@闭包版（滚动到边缘时）
    @available(iOS 13.0, *)
    @discardableResult
    public func byScrollEdgeAppearance(_ builder: jobsByNavigationBarAppearanceBlock) -> Self {
        if #available(iOS 13.0, *) {
            let appearance = scrollEdgeAppearance ?? standardAppearance
            builder(appearance)
            scrollEdgeAppearance = appearance
        };return self
    }
    /// 配置 compactScrollEdgeAppearance@闭包版（紧凑 + 滚动到边缘）
    @available(iOS 13.0, *)
    @discardableResult
    public func byCompactScrollEdgeAppearance(_ builder: jobsByNavigationBarAppearanceBlock) -> Self {
        if #available(iOS 15.0, *) {
            let appearance = compactScrollEdgeAppearance
                ?? scrollEdgeAppearance
                ?? compactAppearance
                ?? standardAppearance
            builder(appearance)
            compactScrollEdgeAppearance = appearance
        };return self
    }
    /// 一次把同一个appearance套到所有状态@闭包版（常用）
    @available(iOS 13.0, *)
    @discardableResult
    public func byUnifiedAppearance(_ builder: jobsByNavigationBarAppearanceBlock) -> Self {
        if #available(iOS 13.0, *) {
            let appearance = standardAppearance
            builder(appearance)
            standardAppearance = appearance
            scrollEdgeAppearance = appearance
            compactAppearance = appearance
            if #available(iOS 15.0, *) {
                compactScrollEdgeAppearance = appearance
            }
        };return self
    }
    /// 批量设置 items
    @discardableResult
    public func byItems(_ items: [UINavigationItem]?,
                 animated: Bool = false) -> Self {
        setItems(items, animated: animated)
        return self
    }
}
