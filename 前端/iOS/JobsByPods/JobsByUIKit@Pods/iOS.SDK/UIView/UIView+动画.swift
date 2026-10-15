//
//  UIView+动画.swift
//  JobsByUIKit
//
//  Created by Jobs on 2026年5月13日，星期三.
//

#if os(OSX)
import AppKit
#elseif os(iOS) || os(tvOS)
import UIKit
#endif

import JobsSwiftDSL
import JobsSwiftBaseDefines

// MARK: 动画@旋转（✅ 默认转 sublayers：不影响悬浮拖动/点击）
private var _jobs_spinPausedAngleKey: UInt8 = 0   // Double：暂停时角度
private var _jobs_spinRevKey: UInt8 = 0           // Double：转速（rev/s）
extension UIView {
    /// 是否正在旋转（装了动画就算）
    public var jobs_isSpinning: Bool {
        layer.animation(forKey: "jobs.spin") != nil
    }
    /// 是否处于“暂停态”（没有动画，但记录了角度）
    public var jobs_isSpinPaused: Bool {
        !jobs_isSpinning && (objc_getAssociatedObject(self, &_jobs_spinPausedAngleKey) as? Double) != nil
    }
    /// 开始旋转（默认旋转 sublayers：✅ 不改变 view 自身 transform/不干扰手势）
    @discardableResult
    public func bySpinStart(revPerSec: Double = 1.0) -> Self {
        let r = max(0.001, revPerSec)
        objc_setAssociatedObject(
            self,
            &_jobs_spinRevKey,
            r,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
        // 如果已经在转，直接返回
        if layer.animation(forKey: "jobs.spin") != nil { return self }
        // 如果是从暂停恢复：从记录角度继续；否则从 0 开始
        let startAngle = (objc_getAssociatedObject(self, &_jobs_spinPausedAngleKey) as? Double) ?? 0
        // 先把 model 层固定到当前角度，避免 add animation 时跳变
        layer.sublayerTransform = CATransform3DMakeRotation(CGFloat(startAngle), 0, 0, 1)
        let a = CABasicAnimation(keyPath: "sublayerTransform.rotation.z")
            .byFromValue(startAngle)
            .byToValue(startAngle + Double.pi * 2)
            .byDuration(1.0 / r)                  // 一秒转 r 圈
            .byRepeatCount(.infinity)
            .byRemovedOnCompletion(false)
            .byFillMode(.forwards)
        layer.add(a, forKey: "jobs.spin")
        // 清掉暂停角度（现在已经在运行）
        objc_setAssociatedObject(
            self,
            &_jobs_spinPausedAngleKey,
            nil,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        );return self
    }
    /// 暂停旋转（保持当前角度）—— 不再用 layer.speed/timeOffset，避免影响其他动画/拖动
    @discardableResult
    public func bySpinPause() -> Self {
        guard layer.animation(forKey: "jobs.spin") != nil else { return self }
        // 取 presentation 的当前 sublayerTransform，冻结到 model
        let current3D = layer.presentation()?.sublayerTransform ?? layer.sublayerTransform
        layer.sublayerTransform = current3D
        // 从矩阵里解出当前 z 旋转角（atan2）
        let angle = Double(atan2(current3D.m12, current3D.m11))
        objc_setAssociatedObject(
            self,
            &_jobs_spinPausedAngleKey,
            angle,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
        layer.removeAnimation(forKey: "jobs.spin")
        return self
    }
    /// 恢复旋转（从暂停角度继续）
    @discardableResult
    public func bySpinResume() -> Self {
        let r = (objc_getAssociatedObject(self, &_jobs_spinRevKey) as? Double) ?? 1.0
        return bySpinStart(revPerSec: r)
    }
    /// 停止并移除旋转动画（回到初始角度）
    @discardableResult
    public func bySpinStop() -> Self {
        layer.removeAnimation(forKey: "jobs.spin")
        layer.sublayerTransform = CATransform3DIdentity
        objc_setAssociatedObject(
            self,
            &_jobs_spinPausedAngleKey,
            nil,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        );return self
    }
}
// MARK: 动画@点击放大
private var _jobs_bounceAnimatingKey: UInt8 = 0
@MainActor
extension UIView {
    /// 仅执行一轮“放大→回弹”动画（不挂手势/不注册事件）
    public func playTapBounce(
        scale: CGFloat = 1.08,
        upDuration: TimeInterval = 0.08,
        downDuration: TimeInterval = 0.30,
        damping: CGFloat = 0.66,
        velocity: CGFloat = 0.9,
        haptic: UIImpactFeedbackGenerator.FeedbackStyle? = nil
    ) {
        // 去抖：正在做上一轮就不叠加
        if (objc_getAssociatedObject(self, &_jobs_bounceAnimatingKey) as? Bool) == true { return }
        objc_setAssociatedObject(
            self,
            &_jobs_bounceAnimatingKey,
            true,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
        // 以“当前 transform”为基准，避免覆盖你已有的缩放
        let original = self.transform
        if let style = haptic { UIImpactFeedbackGenerator(style: style).impactOccurred() }
        UIView.animate(withDuration: upDuration,
                       delay: 0,
                       options: [.beginFromCurrentState, .allowUserInteraction, .curveEaseOut]) { [weak self] in
            guard let self else { return }
            self.transform = original.scaledBy(x: max(0.01, scale), y: max(0.01, scale))
        } completion: { [weak self] _ in
            guard let self else { return }
            UIView.animate(withDuration: downDuration,
                           delay: 0,
                           usingSpringWithDamping: max(0.05, min(1, damping)),
                           initialSpringVelocity: max(0, velocity),
                           options: [.beginFromCurrentState, .allowUserInteraction]) { [weak self] in
                self?.transform = original
            } completion: { [weak self] _ in
                objc_setAssociatedObject(
                    self as Any,
                    &_jobs_bounceAnimatingKey,
                    false,
                    .OBJC_ASSOCIATION_RETAIN_NONATOMIC
                )
            }
        }
    }
}
// MARK: 动画@视图左右晃动
extension UIView {
    public func shake(duration: CFTimeInterval = 0.5, repeatCount: Float = 1) {
        self.layer.add(
            CAKeyframeAnimation(keyPath: "transform.translation.x")
                .byTimingFunction(CAMediaTimingFunction(name: .linear))
                .byDuration(duration)
                .byValues([-10, 10, -8, 8, -5, 5, 0])   // 左右偏移
                .byRepeatCount(repeatCount) ,            // 注意 repeatCount 是 Float,
            forKey: "shake")
    }
}
// MARK: 呼吸灯动画效果
extension UIView {
    public func doShineAnimation() {
        self.layer.add(CABasicAnimation(keyPath: "opacity")
            .byFromValue(NSNumber(1.0))
            .byToValue(NSNumber(1.0))
            .byAutoreverses(true)
            .byDuration(1)
            .byRepeatCount(3)
            .byFillMode(CAMediaTimingFillMode.forwards)
            .byRemovedOnCompletion(true), forKey: "A")
    }
}
// MARK: 动画@哪里来哪里去
#if canImport(SnapKit)
import SnapKit
public enum JobsSlideCase {
    /// 从某个方向“来”（展开到 size）
    case show(from: JobsDirection, size: CGFloat)
    /// 到某个方向“去”（收起到 collapsedSize，默认 0）
    case hide(to: JobsDirection)
}

extension UIView {
    public func jobs_slide(
        _ slide: JobsSlideCase,
        sizeConstraint: Constraint?,
        collapsedSize: CGFloat = 0,
        duration: TimeInterval = 0.25,
        options: UIView.AnimationOptions = [.curveEaseInOut],
        fade: Bool = true,
        autoHide: Bool = true,
        completion: (() -> Void)? = nil
    ) {
        guard let superview else { completion?(); return }
        guard let sizeConstraint else { completion?(); return }
        superview.layoutIfNeeded()
        switch slide {
        /// 处理 .show 分支
        case let .show(from: _, size: size):
            isHidden = false
            if fade { alpha = 0 }
            sizeConstraint.update(offset: size)
            UIView.animate(withDuration: duration,
                           delay: 0,
                           options: options) {
                if fade { self.alpha = 1 }
                superview.layoutIfNeeded()
            } completion: { _ in
                completion?()
            }
        /// 处理 .hide 分支
        case .hide(to: _):
            sizeConstraint.update(offset: collapsedSize)
            UIView.animate(withDuration: duration,
                           delay: 0,
                           options: options) {
                if fade { self.alpha = 0 }
                superview.layoutIfNeeded()
            } completion: { _ in
                if autoHide { self.isHidden = true }
                completion?()
            }
        }
    }
}
#endif
