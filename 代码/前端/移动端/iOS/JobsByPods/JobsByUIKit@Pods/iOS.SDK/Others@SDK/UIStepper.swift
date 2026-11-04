//
//  UIStepper.swift
//  JobsByUIKit
//
//  Created by Jobs on 2026年5月13日，星期三.
//

#if os(OSX)
import AppKit
#elseif os(iOS) || os(tvOS)
import UIKit
#endif

extension UIStepper {
    @discardableResult
    public func byValue(_ value: Double) -> Self {
        self.value = value
        return self
    }

    @discardableResult
    public func byMinimumValue(_ min: Double) -> Self {
        self.minimumValue = min
        return self
    }

    @discardableResult
    public func byMaximumValue(_ max: Double) -> Self {
        self.maximumValue = max
        return self
    }

    @discardableResult
    public func byStepValue(_ step: Double) -> Self {
        self.stepValue = step
        return self
    }

    @discardableResult
    public func byContinuous(_ continuous: Bool) -> Self {
        self.isContinuous = continuous
        return self
    }

    @discardableResult
    public func byAutorepeat(_ autorepeat: Bool) -> Self {
        self.autorepeat = autorepeat
        return self
    }

    @discardableResult
    public func byWraps(_ wraps: Bool) -> Self {
        self.wraps = wraps
        return self
    }
}
