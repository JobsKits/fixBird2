//
//  CATransition.swift
//  JobsByQuartzCore
//
//  Created by Jobs on 2026年5月13日，星期三.
//

import QuartzCore
import JobsSwiftBlock

extension CATransition {
    /// 统一入口：CATransition.make { $0.byType(...).bySubtype(...) }
    public static func make(_ configure: jobsByCATransitionBlock) -> CATransition {
        let t = CATransition()
        configure(t)
        return t
    }
}

extension CATransition {
    @discardableResult
    public func byType(_ type: CATransitionType) -> Self {
        self.type = type
        return self
    }

    @discardableResult
    public func bySubtype(_ subtype: CATransitionSubtype?) -> Self {
        self.subtype = subtype
        return self
    }

    @discardableResult
    public func byStartProgress(_ value: Float) -> Self {
        self.startProgress = value
        return self
    }

    @discardableResult
    public func byEndProgress(_ value: Float) -> Self {
        self.endProgress = value
        return self
    }

    #if targetEnvironment(macCatalyst)
    @available(macCatalyst 13.1, *)
    @discardableResult
    public func byCIFilter(_ filter: CIFilter?) -> Self {
        self.filter = filter
        return self
    }
    #endif
}
