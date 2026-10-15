//
//  CAShapeLayer.swift
//  JobsByQuartzCore
//
//  Created by Jobs on 2026年5月13日，星期三.
//

#if os(OSX)
import AppKit
#elseif os(iOS) || os(tvOS)
import UIKit
#endif

extension CAShapeLayer {
    // MARK: - 基础属性
    @discardableResult
    public func byPath(_ path: CGPath?) -> Self {
        self.path = path
        return self
    }
    // MARK: - 颜色（支持 UIColor / CGColor）
    @discardableResult
    public func byFillColor(_ color: UIColor?) -> Self {
        self.fillColor = color?.cgColor
        return self
    }

    @discardableResult
    public func byFillCGColor(_ color: CGColor?) -> Self {
        self.fillColor = color
        return self
    }

    @discardableResult
    public func byStrokeColor(_ color: UIColor?) -> Self {
        self.strokeColor = color?.cgColor
        return self
    }

    @discardableResult
    public func byStrokeCGColor(_ color: CGColor?) -> Self {
        self.strokeColor = color
        return self
    }
    // MARK: - 线条相关
    @discardableResult
    public func byLineWidth(_ width: CGFloat) -> Self {
        self.lineWidth = width
        return self
    }

    @discardableResult
    public func byStrokeStart(_ value: CGFloat) -> Self {
        self.strokeStart = value
        return self
    }

    @discardableResult
    public func byStrokeEnd(_ value: CGFloat) -> Self {
        self.strokeEnd = value
        return self
    }

    @discardableResult
    public func byMiterLimit(_ value: CGFloat) -> Self {
        self.miterLimit = value
        return self
    }

    @discardableResult
    public func byLineDashPhase(_ phase: CGFloat) -> Self {
        self.lineDashPhase = phase
        return self
    }

    @discardableResult
    public func byLineDashPattern(_ pattern: [NSNumber]?) -> Self {
        self.lineDashPattern = pattern
        return self
    }
    // MARK: - 线条样式（枚举）
    @discardableResult
    public func byLineCap(_ cap: CAShapeLayerLineCap) -> Self {
        self.lineCap = cap
        return self
    }

    @discardableResult
    public func byLineJoin(_ join: CAShapeLayerLineJoin) -> Self {
        self.lineJoin = join
        return self
    }

    @discardableResult
    public func byFillRule(_ rule: CAShapeLayerFillRule) -> Self {
        self.fillRule = rule
        return self
    }
}
