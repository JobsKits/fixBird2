//
//  UISlider.swift
//  JobsByUIKit
//
//  Created by Jobs on 2026年5月13日，星期三.
//

#if os(OSX)
import AppKit
#elseif os(iOS) || os(tvOS)
import UIKit
#endif

extension UISlider {
    @discardableResult
    public func byValueByAnimated(_ value: Float) -> Self {
        self.setValue(value, animated: true)
        return self
    }

    @discardableResult
    public func byValue(_ value: Float) -> Self {
        self.setValue(value, animated: false)
        return self
    }

    @discardableResult
    public func byMinimumValue(_ value: Float) -> Self {
        self.minimumValue = value
        return self
    }

    @discardableResult
    public func byMaximumValue(_ value: Float) -> Self {
        self.maximumValue = value
        return self
    }

    @discardableResult
    public func byMinimumTrackTintColor(_ color: UIColor) -> Self {
        self.minimumTrackTintColor = color
        return self
    }

    @discardableResult
    public func byMaximumTrackTintColor(_ color: UIColor) -> Self {
        self.maximumTrackTintColor = color
        return self
    }

    @discardableResult
    public func byThumbTintColor(_ color: UIColor) -> Self {
        self.thumbTintColor = color
        return self
    }
}
