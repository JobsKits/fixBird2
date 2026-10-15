//
//  CAPropertyAnimation.swift
//  JobsByQuartzCore
//
//  Created by Jobs on 2026年5月13日，星期三.
//

import QuartzCore

extension CAPropertyAnimation {
    /// keyPath
    @discardableResult
    public func byKeyPath(_ path: String?) -> Self {
        self.keyPath = path
        return self
    }
    /// additive
    @discardableResult
    public func byAdditive(_ flag: Bool) -> Self {
        self.isAdditive = flag
        return self
    }
    /// cumulative
    @discardableResult
    public func byCumulative(_ flag: Bool) -> Self {
        self.isCumulative = flag
        return self
    }
    /// valueFunction
    @discardableResult
    public func byValueFunction(_ fn: CAValueFunction?) -> Self {
        self.valueFunction = fn
        return self
    }
}
