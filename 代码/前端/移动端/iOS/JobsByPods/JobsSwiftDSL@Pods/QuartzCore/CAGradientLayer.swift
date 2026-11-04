//
//  CAGradientLayer.swift
//  JobsByQuartzCore
//
//  Created by Jobs on 2026年5月13日，星期三.
//

#if os(OSX)
import AppKit
#elseif os(iOS) || os(tvOS)
import UIKit
#endif

import ObjectiveC
import JobsSwiftBaseDefines

// MARK: - CAGradientLayer DSL
extension CAGradientLayer {
    @discardableResult
    public func byColors(_ uiColors: [UIColor]) -> Self {
        self.colors = uiColors.map { $0.cgColor };return self
    }

    @discardableResult
    public func byColors(_ cgColors: [CGColor]) -> Self {
        self.colors = cgColors
        return self
    }

    @discardableResult
    public func byCGColors(_ cgColors: [CGColor]) -> Self {
        self.colors = cgColors
        return self
    }

    @discardableResult
    public func byLocations(_ locs: [CGFloat]) -> Self {
        self.locations = locs.map { NSNumber(value: Double($0)) };return self
    }

    @discardableResult
    public func byLocations(_ locs: [NSNumber]) -> Self {
        self.locations = locs
        return self
    }

    @discardableResult
    public func byStartPoint(_ p: CGPoint) -> Self {
        self.startPoint = p
        return self
    }

    @discardableResult
    public func byEndPoint(_ p: CGPoint) -> Self {
        self.endPoint = p
        return self
    }

    @discardableResult
    public func byPoints(_ start: CGPoint, _ end: CGPoint) -> Self {
        self.startPoint = start
        self.endPoint = end
        return self
    }

    @discardableResult
    public func byType(_ t: CAGradientLayerType) -> Self {
        self.type = t
        return self
    }

    @discardableResult
    public func byLayerFrame(_ f: CGRect) -> Self {
        self.frame = f
        return self
    }
    /// 插入到某个 view 的 layer（默认最底层）
    @discardableResult
    public func byInsert(into view: UIView, at index: UInt32 = 0) -> Self {
        view.layer.insertSublayer(self, at: index)
        CATransaction.begin(); CATransaction.setDisableActions(true)
        self.frame = view.bounds
        CATransaction.commit()
        return self
    }
    @discardableResult
    public func byDirection(_ d: JobsGradientDirection) -> Self {
        switch d {
        /// 处理 .leftToRight 分支
        case .leftToRight:
            startPoint = .init(x: 0, y: 0.5)
            endPoint   = .init(x: 1, y: 0.5)
        /// 处理 .rightToLeft 分支
        case .rightToLeft:
            startPoint = .init(x: 1, y: 0.5)
            endPoint   = .init(x: 0, y: 0.5)
        /// 处理 .topToBottom 分支
        case .topToBottom:
            startPoint = .init(x: 0.5, y: 0)
            endPoint   = .init(x: 0.5, y: 1)
        /// 处理 .bottomToTop 分支
        case .bottomToTop:
            startPoint = .init(x: 0.5, y: 1)
            endPoint   = .init(x: 0.5, y: 0)
        /// 处理 .topLeftToBottomRight 分支
        case .topLeftToBottomRight:
            startPoint = .init(x: 0, y: 0)
            endPoint   = .init(x: 1, y: 1)
        /// 处理 .bottomRightToTopLeft 分支
        case .bottomRightToTopLeft:
            startPoint = .init(x: 1, y: 1)
            endPoint   = .init(x: 0, y: 0)
        /// 处理 .topRightToBottomLeft 分支
        case .topRightToBottomLeft:
            startPoint = .init(x: 1, y: 0)
            endPoint   = .init(x: 0, y: 1)
        /// 处理 .bottomLeftToTopRight 分支
        case .bottomLeftToTopRight:
            startPoint = .init(x: 0, y: 1)
            endPoint   = .init(x: 1, y: 0)
        /// 处理 .custom 分支
        case let .custom(start, end):
            startPoint = start
            endPoint   = end
        };return self
    }
}
