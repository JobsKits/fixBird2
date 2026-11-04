//
//  UIView+SkeletonView.swift
//  JobsByUIKit
//
//  Created by Jobs on 2026年5月13日，星期三.
//

#if os(OSX)
import AppKit
#elseif os(iOS) || os(tvOS)
import UIKit
#endif

import JobsSwiftBaseDefines

#if canImport(SkeletonView)
import SkeletonView
// MARK: - UIView · 基础属性与显隐
extension UIView {
    /// 标记为可骨架
    @discardableResult
    public func bySkeletonable(_ enabled: Bool = true) -> Self {
        self.isSkeletonable = enabled
        return self
    }
    /// 骨架激活时是否隐藏该视图
    @discardableResult
    public func bySkeletonHiddenWhenActive(_ hidden: Bool = true) -> Self {
        self.isHiddenWhenSkeletonIsActive = hidden
        return self
    }
    /// 骨架激活时是否禁用交互
    @discardableResult
    public func bySkeletonDisableInteractionWhenActive(_ disabled: Bool = true) -> Self {
        self.isUserInteractionDisabledWhenSkeletonIsActive = disabled
        return self
    }
    /// 骨架圆角（仅影响骨架形状）
    @discardableResult
    public func bySkeletonCornerRadius(_ radius: CGFloat) -> Self {
        self.skeletonCornerRadius = Float(radius)
        return self
    }
    /// 一次性配置
    @discardableResult
    public func bySkeleton(
        enabled: Bool = true,
        cornerRadius: CGFloat? = nil,
        hiddenWhenActive: Bool? = nil,
        disableInteractionWhenActive: Bool? = nil
    ) -> Self {
        self.isSkeletonable = enabled
        if let r = cornerRadius { self.skeletonCornerRadius = Float(r) }
        if let h = hiddenWhenActive { self.isHiddenWhenSkeletonIsActive = h }
        if let d = disableInteractionWhenActive { self.isUserInteractionDisabledWhenSkeletonIsActive = d };return self
    }
    /// 纯色“脉冲”骨架（可传自定义动画，不传则用内置 pulse）
    @discardableResult
    public func byShowSolidSkeleton(
        baseColor: UIColor = JobsCor.systemGray5,
        transition: TimeInterval = 0.2,
        customAnimation: SkeletonLayerAnimation? = nil
    ) -> Self {
        self.showAnimatedSkeleton(
            usingColor: baseColor,
            animation: customAnimation,
            transition: .crossDissolve(transition)
        );return self
    }
    /// 渐变骨架（sliding）
    @discardableResult
    public func byShowGradientSkeleton(
        baseColor: UIColor = JobsCor.systemGray5,
        direction: GradientDirection = .leftRight,
        transition: TimeInterval = 0.2
    ) -> Self {
        let gradient = SkeletonGradient(baseColor: baseColor)
        let animation = SkeletonAnimationBuilder().makeSlidingAnimation(withDirection: direction)
        self.showAnimatedGradientSkeleton(
            usingGradient: gradient,
            animation: animation,
            transition: .crossDissolve(transition)
        );return self
    }
    /// 隐藏骨架
    @discardableResult
    public func byHideSkeleton(transition: TimeInterval = 0.25) -> Self {
        self.hideSkeleton(transition: .crossDissolve(transition))
        return self
    }
}
// MARK: - 表格/集合 · 隐藏并 reload
extension UITableView {
    @discardableResult
    public func byHideSkeletonAndReload(transition: TimeInterval = 0.25) -> Self {
        self.hideSkeleton(reloadDataAfter: true, transition: .crossDissolve(transition))
        return self
    }
}

extension UICollectionView {
    @discardableResult
    public func byHideSkeletonAndReload(transition: TimeInterval = 0.25) -> Self {
        self.hideSkeleton(reloadDataAfter: true, transition: .crossDissolve(transition))
        return self
    }
}
// MARK: - UILabel · 文本骨架细节
extension UILabel {
    /// 骨架文本行圆角
    @discardableResult
    public func bySkeletonLinesCornerRadius(_ radius: Int) -> Self {
        self.linesCornerRadius = radius
        return self
    }
    /// 末行填充百分比（0~100）
    @discardableResult
    public func bySkeletonLastLineFillPercent(_ percent: Int) -> Self {
        self.lastLineFillPercent = percent
        return self
    }
}
// MARK: - 可选：自定义“脉冲”动画工厂（需要更快/更慢时）
public enum JobsSkeletonPulse {
    public static func make(duration: CFTimeInterval = 0.8,
                            from: Float = 1.0,
                            to: Float = 0.6) -> SkeletonLayerAnimation {
        { _ in
            let a = CABasicAnimation(keyPath: "opacity")
            a
                .byFromValue(from)
                .byToValue(to)
            a.duration = duration
            a.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            a.autoreverses = true
            a.repeatCount = .infinity
            a.isRemovedOnCompletion = false
            return a
        }
    }
}
#endif
