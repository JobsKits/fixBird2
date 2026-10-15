//
//  UIActivityIndicatorView+DSL.swift
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
extension UIActivityIndicatorView {
    @discardableResult
    public func byStyle(_ style: UIActivityIndicatorView.Style) -> Self {
        self.style = style
        return self
    }

    @discardableResult
    public func byColor(_ color: UIColor) -> Self {
        self.color = color
        return self
    }

    @discardableResult
    public func byHidesWhenStopped(_ hides: Bool) -> Self {
        self.hidesWhenStopped = hides
        return self
    }
}
// MARK: - 闭包重载@单参数
extension UIActivityIndicatorView {
    @discardableResult
    public func byStyle(_ builder: () -> UIActivityIndicatorView.Style) -> Self {
        self.style = builder()
        return self
    }

    @discardableResult
    public func byColor(_ builder: () -> UIColor) -> Self {
        self.color = builder()
        return self
    }

    @discardableResult
    public func byHidesWhenStopped(_ builder: () -> Bool) -> Self {
        self.hidesWhenStopped = builder()
        return self
    }
}

extension UIActivityIndicatorView {
    @discardableResult
    public func start() -> Self {
        self.startAnimating()
        return self
    }

    @discardableResult
    public func stop() -> Self {
        self.stopAnimating()
        return self
    }
}
