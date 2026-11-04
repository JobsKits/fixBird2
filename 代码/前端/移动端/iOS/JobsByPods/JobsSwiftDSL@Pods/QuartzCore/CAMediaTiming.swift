//
//  CAMediaTiming.swift
//  JobsByQuartzCore
//
//  Created by Jobs on 2026年5月13日，星期三.
//

import QuartzCore

extension CAMediaTiming where Self: AnyObject {
    // beginTime
    @discardableResult
    public func byBeginTime(_ value: CFTimeInterval) -> Self {
        self.beginTime = value
        return self
    }
    // duration
    @discardableResult
    public func byDuration(_ value: CFTimeInterval) -> Self {
        self.duration = value
        return self
    }
    // speed
    @discardableResult
    public func bySpeed(_ value: Float) -> Self {
        self.speed = value
        return self
    }
    // timeOffset
    @discardableResult
    public func byTimeOffset(_ value: CFTimeInterval) -> Self {
        self.timeOffset = value
        return self
    }
    // repeatCount
    @discardableResult
    public func byRepeatCount(_ value: Float) -> Self {
        self.repeatCount = value
        return self
    }
    // repeatDuration
    @discardableResult
    public func byRepeatDuration(_ value: CFTimeInterval) -> Self {
        self.repeatDuration = value
        return self
    }
    // autoreverses
    @discardableResult
    public func byAutoreverses(_ flag: Bool) -> Self {
        self.autoreverses = flag
        return self
    }
    // fillMode
    @discardableResult
    public func byFillMode(_ mode: CAMediaTimingFillMode) -> Self {
        self.fillMode = mode
        return self
    }
}
