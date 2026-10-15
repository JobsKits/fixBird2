//
//  UIPageViewController.swift
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

extension UIPageViewController {
    @discardableResult
    public func byViewControllers(_ viewControllers: [UIViewController],
                                  direction: NavigationDirection,
                                  animated: Bool = true,
                                  completion: (jobsByBoolBlock)? = nil) -> Self {
        self.setViewControllers(viewControllers,
                                direction: direction,
                                animated: animated,
                                completion: completion)
        return self
    }

    @discardableResult
    public func byDataSource(_ dataSource: UIPageViewControllerDataSource?) -> Self {
        self.dataSource = dataSource
        return self
    }

    @discardableResult
    public func byDelegate(_ delegate: UIPageViewControllerDelegate?) -> Self {
        self.delegate = delegate
        return self
    }

    @discardableResult
    public func byTransitionStyle(_ style: UIPageViewController.TransitionStyle,
                                  navigationOrientation: UIPageViewController.NavigationOrientation,
                                  options: [UIPageViewController.OptionsKey : Any]? = nil) -> Self {
        UIPageViewController(transitionStyle: style,
                                    navigationOrientation: navigationOrientation,
                                    options: options) as! Self
    }
}
