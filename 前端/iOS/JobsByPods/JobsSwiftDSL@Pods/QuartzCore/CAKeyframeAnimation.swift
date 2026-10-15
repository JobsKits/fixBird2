//
//  CAKeyframeAnimation.swift
//  JobsByQuartzCore
//
//  Created by Jobs on 2026年5月13日，星期三.
//

import QuartzCore
import CoreGraphics

extension CAKeyframeAnimation {
    /// values
    @discardableResult
    public func byValues(_ values: [Any]?) -> Self {
        self.values = values
        return self
    }
    /// path（用 CGPath）
    @discardableResult
    public func byPath(_ path: CGPath?) -> Self {
        self.path = path
        return self
    }
    /// keyTimes
    @discardableResult
    public func byKeyTimes(_ keyTimes: [NSNumber]?) -> Self {
        self.keyTimes = keyTimes
        return self
    }
    /// timingFunctions（逐段 timing）
    @discardableResult
    public func byTimingFunctions(_ functions: [CAMediaTimingFunction]?) -> Self {
        self.timingFunctions = functions
        return self
    }
    /// calculationMode
    @discardableResult
    public func byCalculationMode(_ mode: CAAnimationCalculationMode) -> Self {
        self.calculationMode = mode
        return self
    }
    /// tensionValues
    @discardableResult
    public func byTensionValues(_ values: [NSNumber]?) -> Self {
        self.tensionValues = values
        return self
    }
    /// continuityValues
    @discardableResult
    public func byContinuityValues(_ values: [NSNumber]?) -> Self {
        self.continuityValues = values
        return self
    }
    /// biasValues
    @discardableResult
    public func byBiasValues(_ values: [NSNumber]?) -> Self {
        self.biasValues = values
        return self
    }
    /// rotationMode
    @discardableResult
    public func byRotationMode(_ mode: CAAnimationRotationMode?) -> Self {
        self.rotationMode = mode
        return self
    }
    #if canImport(UIKit)
    /// 方便直接传 UIBezierPath
    @discardableResult
    public func byPath(_ bezierPath: UIBezierPath?) -> Self {
        self.path = bezierPath?.cgPath
        return self
    }
    #endif
}
