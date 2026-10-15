//
//  UISwitch.swift
//  JobsByUIKit
//
//  Created by Jobs on 2026年5月13日，星期三.
//

#if os(OSX)
import AppKit
#elseif os(iOS) || os(tvOS)
import UIKit
#endif

extension UISwitch {
    @discardableResult
    public func byOn(_ on: Bool) -> Self {
        self.setOn(on, animated: false)
        return self
    }

    @discardableResult
    public func byOnAnimated(_ on: Bool) -> Self {
        self.setOn(on, animated: true)
        return self
    }

    @discardableResult
    public func byOnTintColor(_ color: UIColor) -> Self {
        self.onTintColor = color
        return self
    }

    @discardableResult
    public func byThumbTintColor(_ color: UIColor) -> Self {
        self.thumbTintColor = color
        return self
    }
}
