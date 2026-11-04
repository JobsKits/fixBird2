//
//  UIPageControl+DSL.swift
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
extension UIPageControl {
    @discardableResult
    public func byNumberOfPages(_ count: Int) -> Self {
        self.numberOfPages = count
        return self
    }

    @discardableResult
    public func byCurrentPage(_ page: Int) -> Self {
        self.currentPage = page
        return self
    }

    @discardableResult
    public func byPageIndicatorTintColor(_ color: UIColor) -> Self {
        self.pageIndicatorTintColor = color
        return self
    }

    @discardableResult
    public func byCurrentPageIndicatorTintColor(_ color: UIColor) -> Self {
        self.currentPageIndicatorTintColor = color
        return self
    }
}
// MARK: - 闭包重载@单参数
extension UIPageControl {
    @discardableResult
    public func byNumberOfPages(_ builder: () -> Int) -> Self {
        self.numberOfPages = builder()
        return self
    }

    @discardableResult
    public func byCurrentPage(_ builder: () -> Int) -> Self {
        self.currentPage = builder()
        return self
    }

    @discardableResult
    public func byPageIndicatorTintColor(_ builder: () -> UIColor) -> Self {
        self.pageIndicatorTintColor = builder()
        return self
    }

    @discardableResult
    public func byCurrentPageIndicatorTintColor(_ builder: () -> UIColor) -> Self {
        self.currentPageIndicatorTintColor = builder()
        return self
    }
}
