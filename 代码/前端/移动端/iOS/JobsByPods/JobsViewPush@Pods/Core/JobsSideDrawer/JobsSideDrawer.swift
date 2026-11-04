//
//  JobsSideDrawer.swift
//  JobsViewPush
//
//  Created by Jobs on 2026年7月12日，星期日.
//

import UIKit

import JobsSwiftBaseDefines
import JobsSwiftDSL

public enum JobsSideDrawerDirection: Int, CaseIterable {
    case top, bottom, left, right
}

public enum JobsSideDrawerContentMode: Int, CaseIterable {
    case following
    case fixed
}

public final class JobsSideDrawerConfiguration {
    public var direction: JobsSideDrawerDirection
    public var contentMode: JobsSideDrawerContentMode
    public var presentedRatio: CGFloat
    public var animationDuration: TimeInterval
    public var dimColor: UIColor
    public var allowsInteractiveTransition: Bool
    /// 返回 `false` 时禁止本次边缘打开手势，不影响已打开抽屉的关闭手势。
    public var shouldBeginOpeningGesture: (() -> Bool)?
    /// 低速拖动完成开关所需的位移比例。
    public var interactiveCompletionThreshold: CGFloat
    /// 超过该速度时以甩动方向直接决定开关结果。
    public var interactiveVelocityThreshold: CGFloat
    /// 用当前速度预测松手后进度的时间窗口。
    public var interactiveProjectionTime: TimeInterval
    /// 主轴速度达到副轴速度的该比例后即可接管手势。
    public var interactiveAxisDominanceRatio: CGFloat
    /// 抽屉完成关闭后回调，模态预览可在此退出承载页面。
    public var onDidClose: (() -> Void)?

    public init(direction: JobsSideDrawerDirection = .left,
                contentMode: JobsSideDrawerContentMode = .following,
                presentedRatio: CGFloat = 0.5,
                animationDuration: TimeInterval = 0.28,
                dimColor: UIColor = JobsCor.black.withAlphaComponent(0.35),
                allowsInteractiveTransition: Bool = true,
                shouldBeginOpeningGesture: (() -> Bool)? = nil,
                interactiveCompletionThreshold: CGFloat = 0.28,
                interactiveVelocityThreshold: CGFloat = 360,
                interactiveProjectionTime: TimeInterval = 0.18,
                interactiveAxisDominanceRatio: CGFloat = 0.8,
                onDidClose: (() -> Void)? = nil) {
        self.direction = direction
        self.contentMode = contentMode
        self.presentedRatio = max(0.1, min(1, presentedRatio))
        self.animationDuration = max(animationDuration, 0)
        self.dimColor = dimColor
        self.allowsInteractiveTransition = allowsInteractiveTransition
        self.shouldBeginOpeningGesture = shouldBeginOpeningGesture
        self.interactiveCompletionThreshold = max(0.05, min(0.95, interactiveCompletionThreshold))
        self.interactiveVelocityThreshold = max(interactiveVelocityThreshold, 0)
        self.interactiveProjectionTime = max(interactiveProjectionTime, 0)
        self.interactiveAxisDominanceRatio = max(0, min(1, interactiveAxisDominanceRatio))
        self.onDidClose = onDidClose
    }
}

public final class JobsSideDrawerVC: UIViewController {
    private enum InteractionIntent {
        case opening
        case closing
    }

    private static let progressEpsilon: CGFloat = 0.001
    private static let minimumSettlementDuration: TimeInterval = 0.12

    public static var defaultMenuWidth: CGFloat { UIScreen.main.bounds.width * 0.5 }
    public private(set) var isOpen = false
    public let configuration: JobsSideDrawerConfiguration

    private let drawerVC: UIViewController?
    private let mainVC: UIViewController?
    private let providedDrawerContentView: UIView?
    private let providedMainContentView: UIView?
    /// 子控制器完成父子关系装配后再读取 view，避免导航容器在零尺寸阶段提前布局。
    private lazy var drawerContentView: UIView = {
        if let providedDrawerContentView { return providedDrawerContentView }
        guard let drawerVC else {
            preconditionFailure("JobsSideDrawerVC 缺少抽屉内容")
        };return drawerVC.view
    }()
    /// 子控制器完成父子关系装配后再读取 view，避免导航容器在零尺寸阶段提前布局。
    private lazy var mainContentView: UIView = {
        if let providedMainContentView { return providedMainContentView }
        guard let mainVC else {
            preconditionFailure("JobsSideDrawerVC 缺少主内容")
        };return mainVC.view
    }()
    private let drawerContainerView = UIView.jobsMake { _ in }
    private let contentContainerView = UIView.jobsMake { _ in }
    private lazy var openGesture: UIScreenEdgePanGestureRecognizer = {
        UIScreenEdgePanGestureRecognizer
            .byConfig { [weak self] (gesture: UIScreenEdgePanGestureRecognizer) in
                self?.updateInteractiveTransition(gesture, intent: .opening)
            }
            .byDelegate(self)
            .byCancelsTouchesInView(true)
    }()
    private lazy var closeGesture: UIPanGestureRecognizer = {
        UIPanGestureRecognizer
            .byConfig { [weak self] (gesture: UIPanGestureRecognizer) in
                self?.updateInteractiveTransition(gesture, intent: .closing)
            }
            .byDelegate(self)
            .byCancelsTouchesInView(true)
    }()
    private var currentProgress: CGFloat = 0
    private var interactionStartProgress: CGFloat?
    private var interactionIntent: InteractionIntent?
    private var isAnimatingTransition = false
    private var transitionGeneration = 0
    private var didInstallContentViews = false
    private lazy var dimControl: UIControl = {
        let control = UIControl.jobsMake { _ in }
            .byBackgroundColor(configuration.dimColor)
            .byAlpha(0)
            .byHidden(true)
        control.addTarget(self, action: #selector(closeFromDim), for: .touchUpInside)
        return control
    }()

    public init(drawerViewController: UIViewController,
                mainViewController: UIViewController,
                configuration: JobsSideDrawerConfiguration = .init()) {
        drawerVC = drawerViewController
        mainVC = mainViewController
        providedDrawerContentView = nil
        providedMainContentView = nil
        self.configuration = configuration
        super.init(nibName: nil, bundle: nil)
    }

    public convenience init(menuVC: UIViewController,
                            mainVC: UIViewController,
                            menuWidth: CGFloat = JobsSideDrawerVC.defaultMenuWidth) {
        let ratio = menuWidth / max(UIScreen.main.bounds.width, 1)
        self.init(drawerViewController: menuVC,
                  mainViewController: mainVC,
                  configuration: .init(presentedRatio: ratio))
    }

    public init(drawerView: UIView,
                mainView: UIView,
                configuration: JobsSideDrawerConfiguration = .init()) {
        drawerVC = nil
        mainVC = nil
        providedDrawerContentView = drawerView
        providedMainContentView = mainView
        self.configuration = configuration
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    public override func viewDidLoad() {
        super.viewDidLoad()
        view.byBackgroundColor(JobsCor.systemBackground)
        installChildren()
        contentContainerView.byAddTo(view)
        drawerContainerView.byAddTo(view)
        view.jobs_addGestureRetView(openGesture)
            .jobs_addGestureRetView(closeGesture)
        updateGestureConfiguration()
    }

    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let progress = interactionStartProgress == nil ? (isOpen ? 1 : 0) : currentProgress
        layoutDrawer(progress: progress)
        installContentViewsIfNeeded()
        layoutContentViewsIfNeeded()
    }

    public func applyConfiguration(animated: Bool = false) {
        normalizeConfiguration()
        dimControl.byBackgroundColor(configuration.dimColor)
        updateGestureConfiguration()
        setDrawer(open: isOpen, animated: animated)
    }

    public func toggleDrawer(animated: Bool = true) {
        setDrawer(open: !isOpen, animated: animated)
    }

    public func openDrawer(animated: Bool = true) {
        setDrawer(open: true, animated: animated)
    }

    public func closeDrawer(animated: Bool = true) {
        setDrawer(open: false, animated: animated)
    }

    private func installChildren() {
        if let drawerVC { addChild(drawerVC) }
        if let mainVC { addChild(mainVC) }
    }

    /// 等父容器拿到真实尺寸后再装配导航子控制器，避开 UIKit 的零尺寸临时布局阶段。
    private func installContentViewsIfNeeded() {
        guard !didInstallContentViews,
              view.bounds.width > 0,
              view.bounds.height > 0 else { return }
        didInstallContentViews = true
        mainContentView.byAddTo(contentContainerView)
        dimControl.byAddTo(contentContainerView)
        drawerContentView.byAddTo(drawerContainerView)
        [mainContentView, drawerContentView, dimControl].forEach {
            $0.byAutoresizingMask([.flexibleWidth, .flexibleHeight])
        }
        mainVC?.didMove(toParent: self)
        drawerVC?.didMove(toParent: self)
    }

    /// 容器旋转或尺寸变化时只更新 frame，不触发子导航栏额外的强制布局。
    private func layoutContentViewsIfNeeded() {
        guard didInstallContentViews else { return }
        mainContentView.byFrame(contentContainerView.bounds)
        drawerContentView.byFrame(drawerContainerView.bounds)
        dimControl.byFrame(contentContainerView.bounds)
    }

    private func setDrawer(open: Bool,
                           animated: Bool,
                           initialVelocity: CGFloat = 0) {
        if open {
            dismissKeyboardBeforeOpening()
        }
        let startProgress = stopTransitionAtRenderedProgress()
        interactionStartProgress = nil
        interactionIntent = nil
        isOpen = open
        let targetProgress: CGFloat = open ? 1 : 0
        if open || startProgress > Self.progressEpsilon {
            dimControl.byHidden(false)
        }
        let remainingProgress = abs(targetProgress - startProgress)
        guard animated,
              configuration.animationDuration > 0,
              remainingProgress > Self.progressEpsilon else {
            layoutDrawer(progress: targetProgress)
            finishTransition(open: open)
            return
        }
        isAnimatingTransition = true
        updateGestureAvailability()
        transitionGeneration += 1
        let generation = transitionGeneration
        let changes: () -> Void = { [weak self] in
            guard let self else { return }
            self.layoutDrawer(progress: targetProgress)
        }
        let completion: (Bool) -> Void = { [weak self] _ in
            guard let self,
                  self.transitionGeneration == generation else { return }
            self.layoutDrawer(progress: targetProgress)
            self.finishTransition(open: open)
        }
        UIView.jobsAnimateWithOptions(
            settlementDuration(from: startProgress,
                               to: targetProgress,
                               initialVelocity: initialVelocity),
            delay: 0,
            options: [.curveEaseOut, .beginFromCurrentState, .allowUserInteraction],
            animations: changes,
            completion: completion
        )
    }

    private func layoutDrawer(progress: CGFloat) {
        let bounds = view.bounds
        let progress = max(0, min(1, progress))
        currentProgress = progress
        let frames = drawerFrames(in: bounds)
        let distance = interactiveDistance()
        drawerContainerView.byFrame(CGRect(
            x: frames.hidden.origin.x + (frames.shown.origin.x - frames.hidden.origin.x) * progress,
            y: frames.hidden.origin.y + (frames.shown.origin.y - frames.hidden.origin.y) * progress,
            width: frames.shown.width,
            height: frames.shown.height
        ))
        var contentFrame = bounds
        if configuration.contentMode == .following {
            switch configuration.direction {
            /// 处理 .left 分支
            case .left: contentFrame.origin.x += distance * progress
            /// 处理 .right 分支
            case .right: contentFrame.origin.x -= distance * progress
            /// 处理 .top 分支
            case .top: contentFrame.origin.y += distance * progress
            /// 处理 .bottom 分支
            case .bottom: contentFrame.origin.y -= distance * progress
            }
        }
        contentContainerView
            .byTransform(.identity)
            .byFrame(contentFrame)
        drawerContentView.byFrame(drawerContainerView.bounds)
        mainContentView.byFrame(contentContainerView.bounds)
        dimControl
            .byFrame(contentContainerView.bounds)
            .byAlpha(progress)
        view.byBringToFront(drawerContainerView)
    }

    private func updateGestureConfiguration() {
        switch configuration.direction {
        /// 处理 .left 分支
        case .left: openGesture.edges = .left
        /// 处理 .right 分支
        case .right: openGesture.edges = .right
        /// 处理 .top 分支
        case .top: openGesture.edges = .top
        /// 处理 .bottom 分支
        case .bottom: openGesture.edges = .bottom
        }
        updateGestureAvailability()
    }

    private func updateGestureAvailability() {
        let allowsGesture = configuration.allowsInteractiveTransition
        openGesture.byEnabled(allowsGesture && !isOpen)
        closeGesture.byEnabled(allowsGesture && isOpen)
    }

    private func interactiveDistance() -> CGFloat {
        let horizontal = configuration.direction == .left || configuration.direction == .right
        let length = horizontal ? view.bounds.width : view.bounds.height
        return max(length * configuration.presentedRatio, 1)
    }

    private func openingTranslation(for translation: CGPoint) -> CGFloat {
        switch configuration.direction {
        /// 处理 .left 分支
        case .left: return translation.x
        /// 处理 .right 分支
        case .right: return -translation.x
        /// 处理 .top 分支
        case .top: return translation.y
        /// 处理 .bottom 分支
        case .bottom: return -translation.y
        }
    }

    private func openingVelocity(for velocity: CGPoint) -> CGFloat {
        switch configuration.direction {
        /// 处理 .left 分支
        case .left: return velocity.x
        /// 处理 .right 分支
        case .right: return -velocity.x
        /// 处理 .top 分支
        case .top: return velocity.y
        /// 处理 .bottom 分支
        case .bottom: return -velocity.y
        }
    }

    private func updateInteractiveTransition(_ gesture: UIPanGestureRecognizer,
                                             intent: InteractionIntent) {
        switch gesture.state {
        /// 处理 .began 分支
        case .began:
            beginInteraction(intent: intent)
            updateInteractionProgress(using: gesture)
        /// 处理 .changed 分支
        case .changed:
            updateInteractionProgress(using: gesture)
        /// 合并处理 .ended、.cancelled、.failed 分支
        case .ended, .cancelled, .failed:
            updateInteractionProgress(using: gesture)
            finishInteraction(using: gesture, intent: intent)
        /// 未匹配已知分支时执行兜底处理
        default:
            break
        }
    }

    @objc private func closeFromDim() {
        closeDrawer()
    }
}

extension JobsSideDrawerVC: UIGestureRecognizerDelegate {
    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let panGesture = gestureRecognizer as? UIPanGestureRecognizer else { return true }
        let intent: InteractionIntent = gestureRecognizer === openGesture ? .opening : .closing
        if intent == .opening,
           let shouldBeginOpeningGesture = configuration.shouldBeginOpeningGesture,
           !shouldBeginOpeningGesture() {
            return false
        }
        let velocity = panGesture.velocity(in: view)
        let primaryVelocity = openingVelocity(for: velocity)
        guard isExpectedDirection(primaryVelocity, for: intent),
              isPrimaryAxisDominant(for: velocity) else { return false }
        if intent == .closing,
           let scrollView = touchedScrollView(for: panGesture),
           scrollViewCanConsume(velocity: velocity, in: scrollView) {
            return false
        };return true
    }

    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                                  shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        guard gestureRecognizer === openGesture || gestureRecognizer === closeGesture,
              otherGestureRecognizer.view is UIScrollView,
              let panGesture = gestureRecognizer as? UIPanGestureRecognizer else { return false }
        let intent: InteractionIntent = gestureRecognizer === openGesture ? .opening : .closing
        let velocity = panGesture.velocity(in: view)
        return isExpectedDirection(openingVelocity(for: velocity), for: intent)
            && isPrimaryAxisDominant(for: velocity)
    }
}

private extension JobsSideDrawerVC {
    func normalizeConfiguration() {
        configuration.presentedRatio = max(0.1, min(1, configuration.presentedRatio))
        configuration.animationDuration = max(configuration.animationDuration, 0)
        configuration.interactiveCompletionThreshold = max(
            0.05,
            min(0.95, configuration.interactiveCompletionThreshold)
        )
        configuration.interactiveVelocityThreshold = max(configuration.interactiveVelocityThreshold, 0)
        configuration.interactiveProjectionTime = max(configuration.interactiveProjectionTime, 0)
        configuration.interactiveAxisDominanceRatio = max(
            0,
            min(1, configuration.interactiveAxisDominanceRatio)
        )
    }

    func drawerFrames(in bounds: CGRect) -> (shown: CGRect, hidden: CGRect) {
        let horizontal = configuration.direction == .left || configuration.direction == .right
        let distance = (horizontal ? bounds.width : bounds.height) * configuration.presentedRatio
        var shownFrame = bounds
        if horizontal {
            shownFrame.size.width = distance
        } else {
            shownFrame.size.height = distance
        }
        if configuration.direction == .right { shownFrame.origin.x = bounds.width - distance }
        if configuration.direction == .bottom { shownFrame.origin.y = bounds.height - distance }
        var hiddenFrame = shownFrame
        switch configuration.direction {
        /// 处理 .left 分支
        case .left: hiddenFrame.origin.x = -distance
        /// 处理 .right 分支
        case .right: hiddenFrame.origin.x = bounds.width
        /// 处理 .top 分支
        case .top: hiddenFrame.origin.y = -distance
        /// 处理 .bottom 分支
        case .bottom: hiddenFrame.origin.y = bounds.height
        };return (shownFrame, hiddenFrame)
    }

    func stopTransitionAtRenderedProgress() -> CGFloat {
        let progress = isAnimatingTransition ? renderedProgress() : currentProgress
        transitionGeneration += 1
        [drawerContainerView, contentContainerView, dimControl].forEach {
            $0.layer.removeAllAnimations()
        }
        isAnimatingTransition = false
        layoutDrawer(progress: progress)
        return progress
    }

    func renderedProgress() -> CGFloat {
        guard let presentationFrame = drawerContainerView.layer.presentation()?.frame else {
            return currentProgress
        }
        let frames = drawerFrames(in: view.bounds)
        let shownOrigin: CGFloat
        let hiddenOrigin: CGFloat
        let currentOrigin: CGFloat
        switch configuration.direction {
        /// 合并处理 .left、.right 分支
        case .left, .right:
            shownOrigin = frames.shown.origin.x
            hiddenOrigin = frames.hidden.origin.x
            currentOrigin = presentationFrame.origin.x
        /// 合并处理 .top、.bottom 分支
        case .top, .bottom:
            shownOrigin = frames.shown.origin.y
            hiddenOrigin = frames.hidden.origin.y
            currentOrigin = presentationFrame.origin.y
        }
        let travel = shownOrigin - hiddenOrigin
        guard abs(travel) > Self.progressEpsilon else { return currentProgress };return max(
            0,
            min(1, (currentOrigin - hiddenOrigin) / travel)
        )
    }

    func finishTransition(open: Bool) {
        isAnimatingTransition = false
        if !open { dimControl.byHidden(true) }
        updateGestureAvailability()
        if !open { configuration.onDidClose?() }
    }

    func settlementDuration(from startProgress: CGFloat,
                            to targetProgress: CGFloat,
                            initialVelocity: CGFloat) -> TimeInterval {
        let remainingProgress = abs(targetProgress - startProgress)
        let maximumDuration = configuration.animationDuration
        let minimumDuration = min(Self.minimumSettlementDuration, maximumDuration)
        var duration = max(minimumDuration, maximumDuration * TimeInterval(remainingProgress))
        let velocity = abs(initialVelocity)
        if velocity >= configuration.interactiveVelocityThreshold,
           velocity > 0 {
            let remainingPoints = remainingProgress * interactiveDistance()
            let velocityDuration = TimeInterval(remainingPoints / velocity) * 0.85
            duration = min(duration, max(minimumDuration, velocityDuration))
        }
        if UIAccessibility.isReduceMotionEnabled {
            duration = min(duration, minimumDuration)
        };return min(duration, maximumDuration)
    }

    private func beginInteraction(intent: InteractionIntent) {
        if intent == .opening {
            dismissKeyboardBeforeOpening()
        }
        let progress = stopTransitionAtRenderedProgress()
        interactionIntent = intent
        interactionStartProgress = progress
        if progress > Self.progressEpsilon || intent == .opening {
            dimControl.byHidden(false)
        }
    }

    private func dismissKeyboardBeforeOpening() {
        mainContentView.endEditing(true)
    }

    func updateInteractionProgress(using gesture: UIPanGestureRecognizer) {
        guard let startProgress = interactionStartProgress else { return }
        let translation = openingTranslation(for: gesture.translation(in: view))
        let progress = startProgress + translation / interactiveDistance()
        layoutDrawer(progress: progress)
    }

    private func finishInteraction(using gesture: UIPanGestureRecognizer,
                                   intent: InteractionIntent) {
        guard interactionIntent == intent else { return }
        let velocity = openingVelocity(for: gesture.velocity(in: view))
        let shouldOpen: Bool
        if gesture.state != .ended {
            shouldOpen = intent == .closing
        } else if abs(velocity) >= configuration.interactiveVelocityThreshold {
            shouldOpen = velocity > 0
        } else {
            let projectedProgress = max(
                0,
                min(
                    1,
                    currentProgress
                        + velocity / interactiveDistance() * CGFloat(configuration.interactiveProjectionTime)
                )
            )
            switch intent {
            /// 处理 .opening 分支
            case .opening:
                shouldOpen = max(currentProgress, projectedProgress)
                    >= configuration.interactiveCompletionThreshold
            /// 处理 .closing 分支
            case .closing:
                shouldOpen = min(currentProgress, projectedProgress)
                    > 1 - configuration.interactiveCompletionThreshold
            }
        }
        setDrawer(open: shouldOpen,
                  animated: true,
                  initialVelocity: velocity)
    }

    private func isExpectedDirection(_ openingVelocity: CGFloat,
                                     for intent: InteractionIntent) -> Bool {
        switch intent {
        /// 处理 .opening 分支
        case .opening: return openingVelocity > 0
        /// 处理 .closing 分支
        case .closing: return openingVelocity < 0
        }
    }

    func isPrimaryAxisDominant(for velocity: CGPoint) -> Bool {
        let horizontal = configuration.direction == .left || configuration.direction == .right
        let primary = horizontal ? abs(velocity.x) : abs(velocity.y)
        let secondary = horizontal ? abs(velocity.y) : abs(velocity.x)
        return primary >= secondary * configuration.interactiveAxisDominanceRatio
    }

    func touchedScrollView(for gesture: UIPanGestureRecognizer) -> UIScrollView? {
        let location = gesture.location(in: view)
        var touchedView = view.hitTest(location, with: nil)
        while let currentView = touchedView {
            if let scrollView = currentView as? UIScrollView { return scrollView }
            touchedView = currentView.superview
        };return nil
    }

    func scrollViewCanConsume(velocity: CGPoint,
                              in scrollView: UIScrollView) -> Bool {
        guard scrollView.isScrollEnabled else { return false }
        let horizontal = configuration.direction == .left || configuration.direction == .right
        let axisVelocity = horizontal ? velocity.x : velocity.y
        let contentLength = horizontal ? scrollView.contentSize.width : scrollView.contentSize.height
        let boundsLength = horizontal ? scrollView.bounds.width : scrollView.bounds.height
        let leadingInset: CGFloat
        let trailingInset: CGFloat
        if #available(iOS 11.0, *) {
            leadingInset = horizontal ? scrollView.adjustedContentInset.left : scrollView.adjustedContentInset.top
            trailingInset = horizontal ? scrollView.adjustedContentInset.right : scrollView.adjustedContentInset.bottom
        } else {
            leadingInset = horizontal ? scrollView.contentInset.left : scrollView.contentInset.top
            trailingInset = horizontal ? scrollView.contentInset.right : scrollView.contentInset.bottom
        }
        guard contentLength + leadingInset + trailingInset > boundsLength + 1 else { return false }
        let currentOffset = horizontal ? scrollView.contentOffset.x : scrollView.contentOffset.y
        let minimumOffset = -leadingInset
        let maximumOffset = max(minimumOffset, contentLength - boundsLength + trailingInset)
        if axisVelocity < 0 { return currentOffset < maximumOffset - 1 }
        if axisVelocity > 0 { return currentOffset > minimumOffset + 1 };return false
    }
}

public extension UIViewController {
    var jobsSideDrawer: JobsSideDrawerVC? {
        var current: UIViewController? = self
        while let controller = current {
            if let drawer = controller as? JobsSideDrawerVC { return drawer }
            current = controller.parent
        };return nil
    }

    func jobs_findMainNavFromAncestors(closeDrawer: Bool = true,
                                       animated: Bool = true) -> UINavigationController? {
        if let drawer = jobsSideDrawer {
            if closeDrawer { drawer.closeDrawer(animated: animated) };return drawer.children.compactMap { $0 as? UINavigationController }.last
        };return navigationController
    }
}
