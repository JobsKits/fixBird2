//
//  UINavigationBarAppearance.swift
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
@available(iOS 15.0, *)
extension UINavigationBarAppearance {
    /// 设置普通标题字体
    @discardableResult
    public func byTitleFont(_ font: UIFont?) -> Self {
        if let font {
            self.titleTextAttributes[.font] = font
        } else {
            self.titleTextAttributes.removeValue(forKey: .font)
        };return self
    }
    /// 设置普通标题颜色
    @discardableResult
    public func byTitleColor(_ color: UIColor?) -> Self {
        if let color {
            self.titleTextAttributes[.foregroundColor] = color
        } else {
            self.titleTextAttributes.removeValue(forKey: .foregroundColor)
        };return self
    }
    /// 整体设置普通标题的 attributes
    @discardableResult
    public func byTitleAttributes(_ attrs: [NSAttributedString.Key: Any]) -> Self {
        self.titleTextAttributes = attrs
        return self
    }
    /// 标题位置微调
    @discardableResult
    public func byTitlePositionAdjustment(_ offset: UIOffset) -> Self {
        self.titlePositionAdjustment = offset
        return self
    }
    /// 设置大标题字体
    @discardableResult
    public func byLargeTitleFont(_ font: UIFont?) -> Self {
        if let font {
            self.largeTitleTextAttributes[.font] = font
        } else {
            self.largeTitleTextAttributes.removeValue(forKey: .font)
        };return self
    }
    /// 设置大标题颜色
    @discardableResult
    public func byLargeTitleColor(_ color: UIColor?) -> Self {
        if let color {
            self.largeTitleTextAttributes[.foregroundColor] = color
        } else {
            self.largeTitleTextAttributes.removeValue(forKey: .foregroundColor)
        };return self
    }
    /// 整体设置大标题 attributes
    @discardableResult
    public func byLargeTitleAttributes(_ attrs: [NSAttributedString.Key: Any]) -> Self {
        self.largeTitleTextAttributes = attrs
        return self
    }
    /// 副标题文本 attributes
    @discardableResult
    @available(iOS 26.0, *)
    public func bySubtitleAttributes(_ attrs: [NSAttributedString.Key: Any]) -> Self {
        self.subtitleTextAttributes = attrs
        return self
    }
    @discardableResult
    @available(iOS 26.0, *)
    public func bySubtitleFont(_ font: UIFont?) -> Self {
        if let font {
            self.subtitleTextAttributes[.font] = font
        } else {
            self.subtitleTextAttributes.removeValue(forKey: .font)
        };return self
    }
    @discardableResult
    @available(iOS 26.0, *)
    public func bySubtitleColor(_ color: UIColor?) -> Self {
        if let color {
            self.subtitleTextAttributes[.foregroundColor] = color
        } else {
            self.subtitleTextAttributes.removeValue(forKey: .foregroundColor)
        };return self
    }
    /// 大标题下副标题
    @discardableResult
    @available(iOS 26.0, *)
    public func byLargeSubtitleAttributes(_ attrs: [NSAttributedString.Key: Any]) -> Self {
        self.largeSubtitleTextAttributes = attrs
        return self
    }
}
// MARK: - 闭包重载@单参数
@available(iOS 15.0, *)
extension UINavigationBarAppearance {
    @discardableResult
    public func byTitleFont(_ builder: () -> UIFont?) -> Self {
        let font = builder()
        if let font {
            self.titleTextAttributes[.font] = font
        } else {
            self.titleTextAttributes.removeValue(forKey: .font)
        };return self
    }

    @discardableResult
    public func byTitleColor(_ builder: () -> UIColor?) -> Self {
        let color = builder()
        if let color {
            self.titleTextAttributes[.foregroundColor] = color
        } else {
            self.titleTextAttributes.removeValue(forKey: .foregroundColor)
        };return self
    }

    @discardableResult
    public func byTitleAttributes(_ builder: () -> [NSAttributedString.Key: Any]) -> Self {
        self.titleTextAttributes = builder()
        return self
    }

    @discardableResult
    public func byTitlePositionAdjustment(_ builder: () -> UIOffset) -> Self {
        self.titlePositionAdjustment = builder()
        return self
    }

    @discardableResult
    public func byLargeTitleFont(_ builder: () -> UIFont?) -> Self {
        let font = builder()
        if let font {
            self.largeTitleTextAttributes[.font] = font
        } else {
            self.largeTitleTextAttributes.removeValue(forKey: .font)
        };return self
    }

    @discardableResult
    public func byLargeTitleColor(_ builder: () -> UIColor?) -> Self {
        let color = builder()
        if let color {
            self.largeTitleTextAttributes[.foregroundColor] = color
        } else {
            self.largeTitleTextAttributes.removeValue(forKey: .foregroundColor)
        };return self
    }

    @discardableResult
    public func byLargeTitleAttributes(_ builder: () -> [NSAttributedString.Key: Any]) -> Self {
        self.largeTitleTextAttributes = builder()
        return self
    }

    @discardableResult
    @available(iOS 26.0, *)
    public func bySubtitleAttributes(_ builder: () -> [NSAttributedString.Key: Any]) -> Self {
        self.subtitleTextAttributes = builder()
        return self
    }

    @discardableResult
    @available(iOS 26.0, *)
    public func bySubtitleFont(_ builder: () -> UIFont?) -> Self {
        let font = builder()
        if let font {
            self.subtitleTextAttributes[.font] = font
        } else {
            self.subtitleTextAttributes.removeValue(forKey: .font)
        };return self
    }

    @discardableResult
    @available(iOS 26.0, *)
    public func bySubtitleColor(_ builder: () -> UIColor?) -> Self {
        let color = builder()
        if let color {
            self.subtitleTextAttributes[.foregroundColor] = color
        } else {
            self.subtitleTextAttributes.removeValue(forKey: .foregroundColor)
        };return self
    }

    @discardableResult
    @available(iOS 26.0, *)
    public func byLargeSubtitleAttributes(_ builder: () -> [NSAttributedString.Key: Any]) -> Self {
        self.largeSubtitleTextAttributes = builder()
        return self
    }
}

@available(iOS 15.0, *)
extension UINavigationBarAppearance {
    /// Back指示图标@同时设置 backIndicatorImage / transitionMaskImage
    @discardableResult
    public func byBackIndicator(_ image: UIImage?, mask: UIImage? = nil) -> Self {
        setBackIndicatorImage(image, transitionMaskImage: mask ?? image)
        return self
    }
    // ================================== 按钮外观 ==================================
    /// 配置普通按钮外观
    @discardableResult
    public func byButtonAppearance(_ builder: jobsByBarButtonItemAppearanceBlock) -> Self {
        builder(buttonAppearance)
        return self
    }
    /// 配置「突出」按钮外观（UIBarButtonItemStyleProminent）
    @discardableResult
    public func byProminentButtonAppearance(_ builder: jobsByBarButtonItemAppearanceBlock) -> Self {
        builder(prominentButtonAppearance)
        return self
    }
    /// 配置返回按钮外观
    @discardableResult
    public func byBackButtonAppearance(_ builder: jobsByBarButtonItemAppearanceBlock) -> Self {
        builder(backButtonAppearance)
        return self
    }
    /// 配置 done 按钮外观（13.0~25.x）
    @discardableResult
    public func byDoneButtonAppearance(_ builder: jobsByBarButtonItemAppearanceBlock) -> Self {
        builder(doneButtonAppearance)
        return self
    }
}
