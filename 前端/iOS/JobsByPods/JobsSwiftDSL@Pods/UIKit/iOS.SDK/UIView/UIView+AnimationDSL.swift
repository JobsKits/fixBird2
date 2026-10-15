//
//  UIView+AnimationDSL.swift
//  JobsSwiftDSL
//
//  Created by Jobs on 2026年7月10日，星期五.
//

#if os(OSX)
import AppKit
#elseif os(iOS) || os(tvOS)
import UIKit
#endif

// MARK: - Animation / Transition 终止动作
public extension UIView {
    static func jobsAnimate(_ duration: TimeInterval,
                            animations: @escaping () -> Void) {
        UIView.animate(withDuration: duration, animations: animations)
    }

    static func jobsAnimateWithCompletion(
        _ duration: TimeInterval,
        animations: @escaping () -> Void,
        completion: ((Bool) -> Void)? = nil
    ) {
        UIView.animate(
            withDuration: duration,
            animations: animations,
            completion: completion
        )
    }

    static func jobsAnimateWithOptions(
        _ duration: TimeInterval,
        delay: TimeInterval = 0,
        options: UIView.AnimationOptions = [],
        animations: @escaping () -> Void,
        completion: ((Bool) -> Void)? = nil
    ) {
        UIView.animate(
            withDuration: duration,
            delay: delay,
            options: options,
            animations: animations,
            completion: completion
        )
    }

    static func jobsAnimateWithSpring(
        _ duration: TimeInterval,
        delay: TimeInterval = 0,
        dampingRatio: CGFloat,
        initialVelocity: CGFloat,
        options: UIView.AnimationOptions = [],
        animations: @escaping () -> Void,
        completion: ((Bool) -> Void)? = nil
    ) {
        UIView.animate(
            withDuration: duration,
            delay: delay,
            usingSpringWithDamping: dampingRatio,
            initialSpringVelocity: initialVelocity,
            options: options,
            animations: animations,
            completion: completion
        )
    }

    static func jobsAnimateKeyframes(
        _ duration: TimeInterval,
        delay: TimeInterval = 0,
        options: UIView.KeyframeAnimationOptions = [],
        animations: @escaping () -> Void,
        completion: ((Bool) -> Void)? = nil
    ) {
        UIView.animateKeyframes(
            withDuration: duration,
            delay: delay,
            options: options,
            animations: animations,
            completion: completion
        )
    }

    static func jobsAddKeyframe(
        withRelativeStartTime startTime: Double,
        relativeDuration: Double,
        animations: @escaping () -> Void
    ) {
        UIView.addKeyframe(
            withRelativeStartTime: startTime,
            relativeDuration: relativeDuration,
            animations: animations
        )
    }

    static func jobsPerformWithoutAnimation(_ actions: () -> Void) {
        UIView.performWithoutAnimation(actions)
    }

    static func jobsTransition(
        with view: UIView,
        duration: TimeInterval,
        options: UIView.AnimationOptions = [],
        animations: (() -> Void)? = nil,
        completion: ((Bool) -> Void)? = nil
    ) {
        UIView.transition(
            with: view,
            duration: duration,
            options: options,
            animations: animations,
            completion: completion
        )
    }

    static func jobsTransitionFromViewToView(
        from fromView: UIView,
        to toView: UIView,
        duration: TimeInterval,
        options: UIView.AnimationOptions = [],
        completion: ((Bool) -> Void)? = nil
    ) {
        UIView.transition(
            from: fromView,
            to: toView,
            duration: duration,
            options: options,
            completion: completion
        )
    }
}
