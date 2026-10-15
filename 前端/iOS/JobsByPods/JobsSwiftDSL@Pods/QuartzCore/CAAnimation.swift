//
//  CAAnimation.swift
//  JobsByQuartzCore
//
//  Created by Jobs on 2026年5月13日，星期三.
//

import QuartzCore

extension CAAnimation {
    /// timingFunction
    @discardableResult
    public func byTimingFunction(_ function: CAMediaTimingFunction?) -> Self {
        self.timingFunction = function
        return self
    }
    /// delegate
    @discardableResult
    public func byDelegate(_ delegate: CAAnimationDelegate?) -> Self {
        self.delegate = delegate
        return self
    }
    /// removedOnCompletion
    @discardableResult
    public func byRemovedOnCompletion(_ flag: Bool) -> Self {
        self.isRemovedOnCompletion = flag
        return self
    }
    /// preferredFrameRateRange（跟系统可用性保持一致）
    @available(iOS 15.0,*)
    @discardableResult
    public func byPreferredFrameRateRange(_ range: CAFrameRateRange) -> Self {
        self.preferredFrameRateRange = range
        return self
    }
}
