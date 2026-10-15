//
//  UITabBarController.swift
//  JobsByUIKit
//
//  Created by Jobs on 2026年5月13日，星期三.
//

#if os(OSX)
import AppKit
#elseif os(iOS) || os(tvOS)
import UIKit
#endif

extension UITabBarController {
    @discardableResult
    public func byViewControllersByAnimated(_ controllers: [UIViewController]) -> Self {
        self.setViewControllers(controllers, animated: true)
        return self
    }

    @discardableResult
    public func byViewControllers(_ controllers: [UIViewController]) -> Self {
        self.setViewControllers(controllers, animated: false)
        return self
    }

    @discardableResult
    public func bySelectedIndex(_ index: Int) -> Self {
        self.selectedIndex = index
        return self
    }

    @discardableResult
    public func byDelegate(_ delegate: UITabBarControllerDelegate?) -> Self {
        self.delegate = delegate
        return self
    }

    @discardableResult
    public func byTabBarTintColor(_ color: UIColor) -> Self {
        self.tabBar.tintColor = color
        return self
    }

    @discardableResult
    public func byTabBarBackgroundColor(_ color: UIColor) -> Self {
        self.tabBar.barTintColor = color
        return self
    }
}
