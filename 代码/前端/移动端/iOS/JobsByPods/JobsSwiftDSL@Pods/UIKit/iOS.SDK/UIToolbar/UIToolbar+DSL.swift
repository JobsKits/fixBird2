//
//  UIToolbar+DSL.swift
//  JobsByUIKit
//
//  Created by Jobs on 2026年5月13日，星期三.
//

#if os(OSX)
import AppKit
#elseif os(iOS) || os(tvOS)
import UIKit
#endif

// MARK: - 直接赋值@单参数
extension UIToolbar {
    // MARK: - Items
    @discardableResult
    public func byItemsAnimated(_ items: [UIBarButtonItem]?) -> Self {
        self.setItems(items, animated: true)
        return self
    }
    @discardableResult
    public func byItems(_ items: [UIBarButtonItem]?) -> Self {
        self.setItems(items, animated: false)
        return self
    }
    // MARK: - Style
    @discardableResult
    public func byBarStyle(_ style: UIBarStyle) -> Self {
        self.barStyle = style
        return self
    }

    @discardableResult
    public func byTranslucent(_ isTranslucent: Bool) -> Self {
        self.isTranslucent = isTranslucent
        return self
    }
    // MARK: - Colors
    @discardableResult
    public func byBarTintColor(_ color: UIColor?) -> Self {
        self.barTintColor = color
        return self
    }
    // MARK: - Background / Shadow
    @discardableResult
    public func byBackgroundImage(_ image: UIImage?,
                                  forToolbarPosition position: UIBarPosition,
                                  barMetrics: UIBarMetrics = .default) -> Self {
        self.setBackgroundImage(image, forToolbarPosition: position, barMetrics: barMetrics)
        return self
    }

    @discardableResult
    public func byShadowImage(_ image: UIImage?,
                              forToolbarPosition position: UIBarPosition) -> Self {
        self.setShadowImage(image, forToolbarPosition: position)
        return self
    }
    // MARK: - Appearance (iOS 13+ / 15+)
    @available(iOS 13.0, *)
    @discardableResult
    public func byStandardAppearance(_ appearance: UIToolbarAppearance) -> Self {
        self.standardAppearance = appearance
        return self
    }

    @available(iOS 13.0, *)
    @discardableResult
    public func byCompactAppearance(_ appearance: UIToolbarAppearance?) -> Self {
        self.compactAppearance = appearance
        return self
    }

    @available(iOS 15.0, *)
    @discardableResult
    public func byScrollEdgeAppearance(_ appearance: UIToolbarAppearance?) -> Self {
        self.scrollEdgeAppearance = appearance
        return self
    }

    @available(iOS 15.0, *)
    @discardableResult
    public func byCompactScrollEdgeAppearance(_ appearance: UIToolbarAppearance?) -> Self {
        self.compactScrollEdgeAppearance = appearance
        return self
    }
    // MARK: - Delegate
    @discardableResult
    public func byDelegate(_ delegate: UIToolbarDelegate?) -> Self {
        self.delegate = delegate
        return self
    }
}
// MARK: - 闭包重载@单参数
extension UIToolbar {
    @discardableResult
    public func byItemsAnimated(_ builder: () -> [UIBarButtonItem]?) -> Self {
        self.setItems(builder(), animated: true)
        return self
    }

    @discardableResult
    public func byItems(_ builder: () -> [UIBarButtonItem]?) -> Self {
        self.setItems(builder(), animated: false)
        return self
    }

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
    public func byStandardAppearance(_ builder: () -> UIToolbarAppearance) -> Self {
        if #available(iOS 13.0, *) {
            self.standardAppearance = builder()
        };return self
    }

    @discardableResult
    public func byCompactAppearance(_ builder: () -> UIToolbarAppearance?) -> Self {
        if #available(iOS 13.0, *) {
            self.compactAppearance = builder()
        };return self
    }

    @discardableResult
    public func byScrollEdgeAppearance(_ builder: () -> UIToolbarAppearance?) -> Self {
        if #available(iOS 15.0, *) {
            self.scrollEdgeAppearance = builder()
        };return self
    }

    @discardableResult
    public func byCompactScrollEdgeAppearance(_ builder: () -> UIToolbarAppearance?) -> Self {
        if #available(iOS 15.0, *) {
            self.compactScrollEdgeAppearance = builder()
        };return self
    }

    @discardableResult
    public func byDelegate(_ builder: () -> UIToolbarDelegate?) -> Self {
        self.delegate = builder()
        return self
    }
}
