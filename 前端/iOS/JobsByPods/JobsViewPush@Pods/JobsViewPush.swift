//
//  JobsViewPush.swift
//  JobsViewPush
//
//  Created by Jobs on 2026年6月21日，星期日.
//

#if os(iOS) || os(tvOS)
import UIKit
#endif

import ObjectiveC
import JobsSwiftBaseDefines
import JobsSwiftDSL

public enum JobsViewPushDirection: CaseIterable {
    case top
    case bottom
    case left
    case right
}

public struct JobsViewPushConfiguration {
    public var direction: JobsViewPushDirection
    public var presentedRatio: CGFloat
    public var animationDuration: TimeInterval
    public var allowsInteractiveDismiss: Bool
    public var dismissOnBackgroundTap: Bool
    public var backgroundColor: UIColor

    public init(
        direction: JobsViewPushDirection = .right,
        presentedRatio: CGFloat = 1,
        animationDuration: TimeInterval = 0.35,
        allowsInteractiveDismiss: Bool = true,
        dismissOnBackgroundTap: Bool = true,
        backgroundColor: UIColor = JobsCor.black.withAlphaComponent(0.18)
    ) {
        self.direction = direction
        self.presentedRatio = min(max(presentedRatio, 0.1), 1)
        self.animationDuration = max(animationDuration, 0)
        self.allowsInteractiveDismiss = allowsInteractiveDismiss
        self.dismissOnBackgroundTap = dismissOnBackgroundTap
        self.backgroundColor = backgroundColor
    }
}

public final class JobsViewPushPresentation: NSObject {
    public private(set) weak var sourceView: UIView?
    public private(set) weak var presentedView: UIView?
    public private(set) var isPresented = false

    public var onDismiss: (() -> Void)?

    private let configuration: JobsViewPushConfiguration
    private let transitionView = JobsViewPushTransitionView()
    private var panGesture: UIPanGestureRecognizer?
    private var backgroundTapGesture: UITapGestureRecognizer?
    private var isAnimatingTransition = false

    fileprivate init(
        sourceView: UIView,
        presentedView: UIView,
        configuration: JobsViewPushConfiguration
    ) {
        self.sourceView = sourceView
        self.presentedView = presentedView
        self.configuration = configuration
        super.init()
        install()
    }

    public func dismiss(animated: Bool = true, completion: (() -> Void)? = nil) {
        guard isPresented, let presentedView else {
            completion?()
            return
        }
        isPresented = false
        isAnimatingTransition = true
        let visibleFrame = visibleFrameForTransitionBounds()
        let targetFrame = hiddenFrame(for: visibleFrame)
        let currentFrame = presentedView.layer.presentation()?.frame ?? presentedView.frame
        let remainingDistance = max(
            abs(targetFrame.origin.x - currentFrame.origin.x),
            abs(targetFrame.origin.y - currentFrame.origin.y)
        )
        let remainingRatio = min(remainingDistance / interactiveDistance(), 1)
        let remainingDuration = configuration.animationDuration * TimeInterval(remainingRatio)
        let animations = { [weak self] in
            guard let self else { return }
            presentedView.byFrame(targetFrame)
            self.transitionView.byBackgroundColor(JobsCor.clear)
            presentedView.layoutIfNeeded()
        }
        let finish: (Bool) -> Void = { [weak self] _ in
            guard let self else { return }
            self.isAnimatingTransition = false
            presentedView.removeFromSuperview()
            self.transitionView.removeFromSuperview()
            self.releaseFromSourceView()
            self.onDismiss?()
            completion?()
        }
        guard animated, remainingDuration > 0 else {
            animations()
            finish(true)
            return
        }
        UIView.jobsAnimateWithOptions(
            remainingDuration,
            delay: 0,
            options: [.curveEaseInOut, .beginFromCurrentState],
            animations: animations,
            completion: finish
        )
    }
}

public extension UIView {
    @discardableResult
    func jobsPush(
        _ presentedView: UIView,
        configuration: JobsViewPushConfiguration = .init(),
        completion: (() -> Void)? = nil
    ) -> JobsViewPushPresentation {
        jobsViewPushPresentation?.dismiss(animated: false)
        layoutIfNeeded()
        let presentation = JobsViewPushPresentation(
            sourceView: self,
            presentedView: presentedView,
            configuration: configuration
        )
        objc_setAssociatedObject(
            self,
            &jobsViewPushPresentationKey,
            presentation,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
        presentation.present(completion: completion)
        return presentation
    }

    func jobsDismissPushedView(animated: Bool = true, completion: (() -> Void)? = nil) {
        jobsViewPushPresentation?.dismiss(animated: animated, completion: completion)
    }
}

private extension JobsViewPushPresentation {
    func install() {
        guard let sourceView, let presentedView else { return }
        transitionView
            .byFrame(sourceView.bounds)
            .byAutoresizingMask([.flexibleWidth, .flexibleHeight])
            .byBackgroundColor(JobsCor.clear)
        transitionView.layoutHandler = { [weak self] in
            self?.layoutPresentedView()
        }
        transitionView.byAddTo(sourceView)
        presentedView.byAddTo(transitionView)
        layoutPresentedView()
        if configuration.dismissOnBackgroundTap {
            let tapGesture = UITapGestureRecognizer(target: self, action: #selector(backgroundTapped(_:)))
            tapGesture.byDelegate(self)
            transitionView.addGestureRecognizer(tapGesture)
            backgroundTapGesture = tapGesture
        }
        if configuration.allowsInteractiveDismiss {
            let panGesture = UIPanGestureRecognizer(target: self, action: #selector(panned(_:)))
            presentedView.addGestureRecognizer(panGesture)
            self.panGesture = panGesture
        }
    }

    func present(completion: (() -> Void)?) {
        guard let presentedView else { return }
        isPresented = true
        isAnimatingTransition = true
        let visibleFrame = visibleFrameForTransitionBounds()
        presentedView
            .byTransform(.identity)
            .byFrame(hiddenFrame(for: visibleFrame))
        UIView.jobsAnimateWithOptions(
            configuration.animationDuration,
            delay: 0,
            options: [.curveEaseInOut, .beginFromCurrentState],
            animations: { [weak self] in
                guard let self else { return }
                presentedView.byFrame(visibleFrame)
                self.transitionView.byBackgroundColor(self.configuration.backgroundColor)
                presentedView.layoutIfNeeded()
            },
            completion: { [weak self] _ in
                self?.isAnimatingTransition = false
                completion?()
            }
        )
    }

    func layoutPresentedView() {
        guard let presentedView else { return }
        guard !isAnimatingTransition else { return }
        let visibleFrame = visibleFrameForTransitionBounds()
        presentedView
            .byTransform(.identity)
            .byFrame(isPresented ? visibleFrame : hiddenFrame(for: visibleFrame))
    }

    func visibleFrameForTransitionBounds() -> CGRect {
        let bounds = transitionView.bounds
        let ratio = configuration.presentedRatio
        switch configuration.direction {
        /// 处理 .top 分支
        case .top:
            return CGRect(x: 0, y: 0, width: bounds.width, height: bounds.height * ratio)
        /// 处理 .bottom 分支
        case .bottom:
            let height = bounds.height * ratio
            return CGRect(x: 0, y: bounds.height - height, width: bounds.width, height: height)
        /// 处理 .left 分支
        case .left:
            return CGRect(x: 0, y: 0, width: bounds.width * ratio, height: bounds.height)
        /// 处理 .right 分支
        case .right:
            let width = bounds.width * ratio
            return CGRect(x: bounds.width - width, y: 0, width: width, height: bounds.height)
        }
    }

    func hiddenFrame(for visibleFrame: CGRect) -> CGRect {
        var hiddenFrame = visibleFrame
        switch configuration.direction {
        /// 处理 .top 分支
        case .top:
            hiddenFrame.origin.y = -visibleFrame.height
        /// 处理 .bottom 分支
        case .bottom:
            hiddenFrame.origin.y = transitionView.bounds.maxY
        /// 处理 .left 分支
        case .left:
            hiddenFrame.origin.x = -visibleFrame.width
        /// 处理 .right 分支
        case .right:
            hiddenFrame.origin.x = transitionView.bounds.maxX
        };return hiddenFrame
    }

    func interactiveDistance() -> CGFloat {
        guard let presentedView else { return 1 }
        switch configuration.direction {
        /// 合并处理 .top、.bottom 分支
        case .top, .bottom:
            return max(presentedView.bounds.height, 1)
        /// 合并处理 .left、.right 分支
        case .left, .right:
            return max(presentedView.bounds.width, 1)
        }
    }

    func interactiveOffset(for translation: CGPoint) -> CGFloat {
        switch configuration.direction {
        /// 处理 .top 分支
        case .top:
            return min(translation.y, 0)
        /// 处理 .bottom 分支
        case .bottom:
            return max(translation.y, 0)
        /// 处理 .left 分支
        case .left:
            return min(translation.x, 0)
        /// 处理 .right 分支
        case .right:
            return max(translation.x, 0)
        }
    }

    func interactiveVelocity(for velocity: CGPoint) -> CGFloat {
        switch configuration.direction {
        /// 处理 .top 分支
        case .top:
            return -velocity.y
        /// 处理 .bottom 分支
        case .bottom:
            return velocity.y
        /// 处理 .left 分支
        case .left:
            return -velocity.x
        /// 处理 .right 分支
        case .right:
            return velocity.x
        }
    }

    func applyInteractiveOffset(_ offset: CGFloat) {
        guard let presentedView else { return }
        let visibleFrame = visibleFrameForTransitionBounds()
        let distance = interactiveDistance()
        let progress = min(abs(offset) / distance, 1)
        let limitedOffset = distance * progress
        switch configuration.direction {
        /// 处理 .top 分支
        case .top:
            presentedView.byFrame(visibleFrame.offsetBy(dx: 0, dy: -limitedOffset))
        /// 处理 .bottom 分支
        case .bottom:
            presentedView.byFrame(visibleFrame.offsetBy(dx: 0, dy: limitedOffset))
        /// 处理 .left 分支
        case .left:
            presentedView.byFrame(visibleFrame.offsetBy(dx: -limitedOffset, dy: 0))
        /// 处理 .right 分支
        case .right:
            presentedView.byFrame(visibleFrame.offsetBy(dx: limitedOffset, dy: 0))
        }
        transitionView.byBackgroundColor(
            configuration.backgroundColor.withAlphaComponent(
                configuration.backgroundColor.cgColor.alpha * (1 - progress)
            )
        )
    }

    func restoreAfterInteractiveDismiss() {
        guard let presentedView else { return }
        UIView.jobsAnimateWithOptions(
            0.25,
            delay: 0,
            options: [.curveEaseOut, .beginFromCurrentState],
            animations: { [weak self] in
                guard let self else { return }
                presentedView
                    .byTransform(.identity)
                    .byFrame(self.visibleFrameForTransitionBounds())
                self.transitionView.byBackgroundColor(self.configuration.backgroundColor)
                presentedView.layoutIfNeeded()
            }
        )
    }

    func releaseFromSourceView() {
        guard let sourceView, sourceView.jobsViewPushPresentation === self else { return }
        objc_setAssociatedObject(sourceView, &jobsViewPushPresentationKey, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }

    @objc func backgroundTapped(_ gesture: UITapGestureRecognizer) {
        guard gesture.state == .ended else { return }
        dismiss()
    }

    @objc func panned(_ gesture: UIPanGestureRecognizer) {
        guard presentedView != nil else { return }
        let offset = interactiveOffset(for: gesture.translation(in: transitionView))
        switch gesture.state {
        /// 合并处理 .began、.changed 分支
        case .began, .changed:
            applyInteractiveOffset(offset)
        /// 合并处理 .ended、.cancelled、.failed 分支
        case .ended, .cancelled, .failed:
            let progress = min(abs(offset) / interactiveDistance(), 1)
            let velocity = interactiveVelocity(for: gesture.velocity(in: transitionView))
            let shouldDismiss = gesture.state == .ended && (progress >= 0.35 || velocity >= 500)
            if shouldDismiss {
                dismiss()
            } else {
                restoreAfterInteractiveDismiss()
            }
        /// 未匹配已知分支时执行兜底处理
        default:
            break
        }
    }
}

extension JobsViewPushPresentation: UIGestureRecognizerDelegate {
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        guard gestureRecognizer === backgroundTapGesture, let presentedView else { return true }
        guard let touchedView = touch.view else { return true };return !touchedView.isDescendant(of: presentedView)
    }
}

private final class JobsViewPushTransitionView: UIView {
    var layoutHandler: (() -> Void)?

    override func layoutSubviews() {
        super.layoutSubviews()
        layoutHandler?()
    }
}

private var jobsViewPushPresentationKey: UInt8 = 0

private extension UIView {
    var jobsViewPushPresentation: JobsViewPushPresentation? {
        objc_getAssociatedObject(self, &jobsViewPushPresentationKey) as? JobsViewPushPresentation
    }
}
