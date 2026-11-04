//
//  UIButton+旋转动画.swift
//  JobsByUIKit
//
//  Created by Jobs on 2026年5月13日，星期三.
//

#if os(OSX)
import AppKit
#elseif os(iOS) || os(tvOS)
import UIKit
#endif

import JobsByQuartzCore
import JobsSwiftDSL

// MARK: - 旋转动画
extension UIButton {
    public static let rotationKey = "jobs.rotation"
    public enum RotationScope { case imageView, wholeButton, layer(CALayer) }

    private func targetLayer(for scope: RotationScope) -> CALayer? {
        switch scope {
        /// 处理 .imageView 分支
        case .imageView: return self.imageView?.layer ?? self.layer
        /// 处理 .wholeButton 分支
        case .wholeButton: return self.layer
        /// 处理 .layer 分支
        case .layer(let l): return l
        }
    }

    @discardableResult
    public func isRotating(scope: RotationScope = .imageView,
                           key: String = UIButton.rotationKey) -> Bool {
        guard let tl = targetLayer(for: scope) else { return false };return tl.animation(forKey: key) != nil
    }

    @discardableResult
    public func setRotating(_ on: Bool,
                            scope: RotationScope = .imageView,
                            duration: CFTimeInterval = 1.0,
                            repeatCount: Float = .infinity,
                            clockwise: Bool = true,
                            key: String = UIButton.rotationKey,
                            resetTransformOnStop: Bool = true) -> Self {
        guard let tl = targetLayer(for: scope) else { return self }
        if on {
            guard tl.animation(forKey: key) == nil else { return self }
            tl.add(
                CABasicAnimation(keyPath: "transform.rotation")
                    .byFromValue(0)
                    .byToValue(CGFloat.pi * 2 * (clockwise ? 1 : -1))
                    .byDuration(max(0.001, duration))
                    .byRepeatCount(repeatCount)
                    .byCumulative(true)
                    .byRemovedOnCompletion(false),
                forKey: key)
        } else {
            tl.removeAnimation(forKey: key)
            if resetTransformOnStop {
                switch scope {
                /// 处理 .imageView 分支
                case .imageView: self.imageView?.transform = .identity
                /// 处理 .wholeButton 分支
                case .wholeButton: self.transform = .identity
                /// 处理 .layer 分支
                case .layer: break
                }
            }
        };return self
    }

    @discardableResult
    public func startRotating(duration: CFTimeInterval = 1.0,
                              scope: RotationScope = .imageView,
                              clockwise: Bool = true,
                              key: String = UIButton.rotationKey) -> Self {
        setRotating(
            true,
            scope: scope,
            duration: duration,
            repeatCount: .infinity,
            clockwise: clockwise,
            key: key
        )
    }

    @discardableResult
    public func stopRotating(scope: RotationScope = .imageView,
                             key: String = UIButton.rotationKey,
                             resetTransformOnStop: Bool = true) -> Self {
        setRotating(
            false,
            scope: scope,
            duration: 0,
            repeatCount: 0,
            clockwise: true,
            key: key,
            resetTransformOnStop: resetTransformOnStop)
    }
}
