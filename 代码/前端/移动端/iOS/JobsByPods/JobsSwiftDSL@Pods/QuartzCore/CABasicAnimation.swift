//
//  CABasicAnimation.swift
//  JobsByQuartzCore
//
//  Created by Jobs on 2026年5月13日，星期三.
//

import QuartzCore

extension CABasicAnimation {
    /// fromValue
    @discardableResult
    public func byFromValue(_ value: Any?) -> Self {
        self.fromValue = value
        return self
    }
    /// toValue
    @discardableResult
    public func byToValue(_ value: Any?) -> Self {
        self.toValue = value
        return self
    }
    /// byValue
    @discardableResult
    public func byByValue(_ value: Any?) -> Self {
        self.byValue = value
        return self
    }
}
