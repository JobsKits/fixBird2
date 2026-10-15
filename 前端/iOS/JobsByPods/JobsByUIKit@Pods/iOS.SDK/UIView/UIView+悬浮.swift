//
//  UIView+悬浮.swift
//  JobsByUIKit
//
//  Created by Jobs on 2026年5月13日，星期三.
//

#if os(OSX)
import AppKit
#elseif os(iOS) || os(tvOS)
import UIKit
#endif

import ObjectiveC
import JobsSwiftDSL

// MARK: - 给任意 UIView 增加悬浮能力（可拖拽、吸附、尊重安全区），默认挂在活动窗口。
// 风格：链式 DSL（.suspend / .bySuspend），主线程 API 使用 @MainActor 保障。
// 注意：悬浮 view 使用 frame 驱动，勿再对其添加 AutoLayout 约束。
// 依赖：UIKit + ObjectiveC 运行时
/**【用法示例】
     /// 悬浮（可按需指定 container）
     UIView().bySuspend { cfg in
         cfg
             .byFallbackSize(CGSize(width: 88, height: 44)) // 给标题/副标题更宽松的空间
             .byDocking(.nearestEdge)
         cfg.insets = UIEdgeInsets(top: 20, left: 16, bottom: 34, right: 16)
         cfg.byHapticOnDock(true)
     }
 */
// MARK: - 悬浮视图@配置
public enum Start {
    case bottomRight, bottomLeft, topRight, topLeft, center
    case point(CGPoint) // 在“可用区域”(仅 safeArea)坐标系内
}

extension UIView {
    // MARK: - 吸附策略
    public enum SuspendDocking {
        case none            // 不吸附
        case nearestEdge     // 吸附最近边
        case nearestCorner   // 吸附最近角
        case auto            // 👈 新增：由 start 推导（默认）
    }
    // MARK: - 悬浮行为配置
    public struct SuspendConfig {
        public var start: Start = .bottomRight
        /// ✅ 新增：动态起点（返回值语义与 Start.point 一致：在“可用区域”(safeArea inset 后)坐标系内）
        /// - 返回 CGPoint(x:15,y:120) 等价于：safeArea 左上角向右 15、向下 120。
        /// - 若设置该闭包，会优先生效并覆盖 `start`。
        public var startPointBuilder: ((UIView) -> CGPoint)? = nil
        public var container: UIView? = nil
        public var fallbackSize: CGSize = .init(width: 56, height: 56)
        public var initialOrigin: CGPoint? = nil
        public var draggable: Bool = true
        public var docking: SuspendDocking = .auto  // 👈 默认改为 .auto
        public var animated: Bool = true
        public var hapticOnDock: Bool = false
        public var confineInContainer: Bool = true
        public init() {}
        public static var `default`: SuspendConfig { .init() }
    }
}
// MARK: - DSL（Non-mutating 副本风格）
public extension UIView.SuspendConfig {
    /// 工厂：链式外建
    static func dsl(_ build: (inout Self) -> Void) -> Self {
        var cfg = Self.default
        build(&cfg)
        return cfg
    }
    @discardableResult func byContainer(_ v: UIView?) -> Self {
        var c = self; c.container = v; return c
    }

    @discardableResult func byFallbackSize(_ v: CGSize) -> Self {
        var c = self; c.fallbackSize = v; return c
    }

    @discardableResult func byDocking(_ v: UIView.SuspendDocking) -> Self {
        var c = self; c.docking = v; return c
    }

    @discardableResult func byInitialOrigin(_ v: CGPoint?) -> Self {
        var c = self; c.initialOrigin = v; return c
    }

    @discardableResult func byDraggable(_ v: Bool) -> Self {
        var c = self; c.draggable = v; return c
    }

    @discardableResult func byAnimated(_ v: Bool) -> Self {
        var c = self; c.animated = v; return c
    }

    @discardableResult func byHapticOnDock(_ v: Bool) -> Self {
        var c = self; c.hapticOnDock = v; return c
    }

    @discardableResult func byConfineInContainer(_ v: Bool) -> Self {
        var c = self; c.confineInContainer = v; return c
    }

    @discardableResult func byStart(_ v: Start) -> Self {
        var c = self
        c.start = v
        c.startPointBuilder = nil
        return c
    }
    /// 动态起点（返回值语义与 Start.point 一致：在“可用区域”(safeArea inset 后)坐标系内）
    /// - 例：.byStart { _ in CGPoint(x: 15, y: 120) }
    /// - 说明：无需自己加 safeAreaInsets.top；内部会基于 safeArea 计算。
    @discardableResult func byStart(_ builder: @escaping (UIView) -> CGPoint) -> Self {
        var c = self
        c.startPointBuilder = builder
        return c
    }
}
// MARK: - 关联键
private enum SuspendKeys {
    static var configKey: UInt8 = 0
    static var panKey: UInt8 = 0
    static var suspendedKey: UInt8 = 0
    static var panDelegateKey: UInt8 = 0   // ✅ 新增：持有手势 delegate（delegate 是 weak，不持有会被释放）
}
// MARK: - 主功能
extension UIView {
    /// 是否已经悬浮（关联对象标记）
    public var isSuspended: Bool {
        (objc_getAssociatedObject(self, &SuspendKeys.suspendedKey) as? Bool) ?? false
    }
    /// 解除悬浮：从容器移除并清理内部手势/配置
    @MainActor
    public func unsuspend() {
        guard isSuspended else { return }
        if let pan = objc_getAssociatedObject(self, &SuspendKeys.panKey) as? UIPanGestureRecognizer {
            removeGestureRecognizer(pan)
        }
        objc_setAssociatedObject(
            self,
            &SuspendKeys.configKey,
            nil,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
        objc_setAssociatedObject(
            self,
            &SuspendKeys.panKey,
            nil,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
        objc_setAssociatedObject(
            self,
            &SuspendKeys.panDelegateKey,
            nil,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
        objc_setAssociatedObject(
            self,
            &SuspendKeys.suspendedKey,
            false,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
        removeFromSuperview()
    }
    /// 悬浮：挂到活动窗口或指定容器；支持拖拽/吸附/安全区
    @discardableResult
    @MainActor
    public func suspend(_ config: SuspendConfig = .default) -> Self {
        // 1) 保存配置
        objc_setAssociatedObject(
            self,
            &SuspendKeys.configKey,
            config,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
        // 2) 容器
        let container: UIView = config.container ?? (UIApplication.jobsKeyWindow() ?? Self._fallbackWindow())
        container.layoutIfNeeded()
        // 3) 添加
        if superview == nil { container.addSubview(self) }
        // 4) 尺寸兜底
        if bounds.size == .zero { frame.size = config.fallbackSize }
        // 5) 初始位置：优先 initialOrigin -> startPointBuilder -> start 推导 -> 右下角保底
        if let origin = config.initialOrigin {
            frame.origin = origin
        } else if frame.origin == .zero {
            let area = Self._availableBounds(in: container) // ✅ 去掉 extraInsets
            if let builder = config.startPointBuilder {
                // 语义：返回值与 Start.point 一致，处在“可用区域”(safeArea inset 后)坐标系内。
                frame.origin = _origin(for: .point(builder(container)), size: frame.size, in: area)
            } else {
                frame.origin = _origin(for: config.start, size: frame.size, in: area)
            }
        }
        // 6) 边界夹紧
        if config.confineInContainer { _clampFrameWithinContainer() }
        // 7) 拖拽手势
        if config.draggable {
            let pan: UIPanGestureRecognizer
            if let old = objc_getAssociatedObject(self, &SuspendKeys.panKey) as? UIPanGestureRecognizer {
                pan = old
            } else {
                pan = self.jobs_addGesture(
                    /// 悬浮视图@手势算法实现
                    UIPanGestureRecognizer
                        .byConfig { [weak self] gr in
                            guard let self else { return }
                            guard let pan = gr as? UIPanGestureRecognizer else { return }
                            guard
                                let cfg = objc_getAssociatedObject(self, &SuspendKeys.configKey) as? UIView.SuspendConfig,
                                let container = self.superview
                            else { return }
                            switch pan.state {
                            /// 处理 .changed 分支
                            case .changed:
                                let delta = pan.translation(in: container)
                                self.frame.origin.x += delta.x
                                self.frame.origin.y += delta.y
                                pan.setTranslation(.zero, in: container)
                                if cfg.confineInContainer { self._clampFrameWithinContainer() }
                            /// 合并处理 .ended、.cancelled、.failed 分支
                            case .ended, .cancelled, .failed:
                                let mode = self._effectiveDocking(cfg)
                                let target = self._snapOrigin(for: mode, in: container, cfg: cfg, currentFrame: self.frame)
                                if cfg.animated {
                                    UIView.animate(withDuration: 0.25,
                                                   delay: 0,
                                                   options: [.curveEaseOut]) {
                                        self.frame.origin = target
                                    } completion: { _ in
                                        if cfg.hapticOnDock {
                                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                        }
                                    }
                                } else {
                                    self.frame.origin = target
                                    if cfg.hapticOnDock {
                                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    }
                                }
                            /// 未匹配已知分支时执行兜底处理
                            default:
                                break
                            }
                        }
                        .byMinTouches(1)
                        .byMaxTouches(2)
                        .byCancelsTouchesInView(true)
                )!
                objc_setAssociatedObject(
                    self,
                    &SuspendKeys.panKey,
                    pan,
                    .OBJC_ASSOCIATION_RETAIN_NONATOMIC
                )
            }
            // 悬浮模块只管理自己的 Pan，不接管外部手势的 delegate。
            _enableSimultaneousPanWithLongPress(pan)
        }
        // 8) 标记
        objc_setAssociatedObject(
            self,
            &SuspendKeys.suspendedKey,
            true,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        );return self
    }
    /// Builder 版本
    @MainActor
    @discardableResult
    public func bySuspend(_ build: (SuspendConfig) -> SuspendConfig) -> Self {
        suspend(build(.default))
    }
}
// MARK: - 私有实现
extension UIView {
    // MARK: - ✅ 手势冲突处理（Pan + LongPress 同时识别）
    private final class JobsSuspendGestureDelegate: NSObject, UIGestureRecognizerDelegate {
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                               shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            // 只放行 Pan <-> LongPress 这组（避免影响你别的手势逻辑）
            let aIsPan = gestureRecognizer is UIPanGestureRecognizer
            let bIsPan = otherGestureRecognizer is UIPanGestureRecognizer
            let aIsLong = gestureRecognizer is UILongPressGestureRecognizer
            let bIsLong = otherGestureRecognizer is UILongPressGestureRecognizer
            return (aIsPan && bIsLong) || (aIsLong && bIsPan)
        }
    }

    private func _suspendGestureDelegate() -> JobsSuspendGestureDelegate {
        if let d = objc_getAssociatedObject(self, &SuspendKeys.panDelegateKey) as? JobsSuspendGestureDelegate {
            return d
        }
        let d = JobsSuspendGestureDelegate()
        objc_setAssociatedObject(self, &SuspendKeys.panDelegateKey, d, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        return d
    }

    private func _enableSimultaneousPanWithLongPress(_ pan: UIPanGestureRecognizer) {
        let d = _suspendGestureDelegate()
        // 任一手势的 delegate 返回 true 即可允许同时识别。
        pan.delegate = d
        pan.cancelsTouchesInView = false
    }
    /// 根据 start & 可用区域推导初始 origin
    private func _origin(for start: Start, size: CGSize, in bounds: CGRect) -> CGPoint {
        switch start {
        /// 处理 .bottomRight 分支
        case .bottomRight:
            return CGPoint(x: bounds.maxX - size.width, y: bounds.maxY - size.height)
        /// 处理 .bottomLeft 分支
        case .bottomLeft:
            return CGPoint(x: bounds.minX, y: bounds.maxY - size.height)
        /// 处理 .topRight 分支
        case .topRight:
            return CGPoint(x: bounds.maxX - size.width, y: bounds.minY)
        /// 处理 .topLeft 分支
        case .topLeft:
            return CGPoint(x: bounds.minX, y: bounds.minY)
        /// 处理 .center 分支
        case .center:
            return CGPoint(x: bounds.midX - size.width * 0.5, y: bounds.midY - size.height * 0.5)
        /// 处理 .point 分支
        case .point(let p):
            // “可用区域”坐标（(0,0) 即 safeArea 左上角）
            return CGPoint(x: bounds.minX + p.x, y: bounds.minY + p.y)
        }
    }
    /// `.auto` → 用 start 推导实际吸附模式
    private func _effectiveDocking(_ cfg: UIView.SuspendConfig) -> UIView.SuspendDocking {
        switch cfg.docking {
        /// 处理 .auto 分支
        case .auto:
            switch cfg.start {
            /// 合并处理 .topLeft、.topRight、.bottomLeft、.bottomRight 分支
            case .topLeft, .topRight, .bottomLeft, .bottomRight:
                return .nearestCorner        // 角起步 → 吸角
            /// 合并处理 .center、.point 分支
            case .center, .point:
                return .nearestEdge          // 中心/点起步 → 吸边
            }
        /// 未匹配已知分支时执行兜底处理
        default:
            return cfg.docking
        }
    }
    /// 计算吸附目标 origin
    private func _snapOrigin(for mode: UIView.SuspendDocking,
                             in container: UIView,
                             cfg: UIView.SuspendConfig,
                             currentFrame f: CGRect) -> CGPoint {
        let b = Self._availableBounds(in: container) // ✅ 去掉 extraInsets
        let w = f.width, h = f.height
        let center = CGPoint(x: f.midX, y: f.midY)
        switch mode {
        /// 处理 .none 分支
        case .none:
            return _clamped(f.origin, size: f.size, in: b, clamp: cfg.confineInContainer)
        /// 处理 .nearestEdge 分支
        case .nearestEdge:
            let dLeft   = abs(center.x - b.minX)
            let dRight  = abs(b.maxX - center.x)
            let dTop    = abs(center.y - b.minY)
            let dBottom = abs(b.maxY - center.y)
            let minD = min(dLeft, dRight, dTop, dBottom)
            if minD == dLeft   { return CGPoint(x: b.minX,          y: min(max(b.minY, f.origin.y), b.maxY - h)) }
            if minD == dRight  { return CGPoint(x: b.maxX - w,      y: min(max(b.minY, f.origin.y), b.maxY - h)) }
            if minD == dTop    { return CGPoint(x: min(max(b.minX, f.origin.x), b.maxX - w), y: b.minY) }
            /* minD == dBottom */ return CGPoint(x: min(max(b.minX, f.origin.x), b.maxX - w), y: b.maxY - h)
        /// 合并处理 .nearestCorner、.auto 分支
        case .nearestCorner, .auto:
            let corners: [CGPoint] = [
                CGPoint(x: b.minX,       y: b.minY),
                CGPoint(x: b.maxX - w,   y: b.minY),
                CGPoint(x: b.minX,       y: b.maxY - h),
                CGPoint(x: b.maxX - w,   y: b.maxY - h)
            ]
            var best = corners.first!
            var bestD = CGFloat.greatestFiniteMagnitude
            for c in corners {
                let dx = center.x - (c.x + w * 0.5)
                let dy = center.y - (c.y + h * 0.5)
                let d  = dx*dx + dy*dy
                if d < bestD { bestD = d; best = c }
            };return best
        }
    }

    private func _clamped(_ origin: CGPoint,
                          size: CGSize,
                          in bounds: CGRect,
                          clamp: Bool) -> CGPoint {
        guard clamp else { return origin }
        let maxX = bounds.maxX - size.width
        let maxY = bounds.maxY - size.height
        return CGPoint(x: min(max(bounds.minX, origin.x), maxX),
                       y: min(max(bounds.minY, origin.y), maxY))
    }

    private func _clampFrameWithinContainer() {
        guard
            let cfg = objc_getAssociatedObject(self, &SuspendKeys.configKey) as? UIView.SuspendConfig,
            let container = self.superview
        else { return }
        let b = Self._availableBounds(in: container) // ✅ 去掉 extraInsets
        frame.origin = _clamped(frame.origin, size: frame.size, in: b, clamp: cfg.confineInContainer)
    }
    /// 可用区域（仅叠加 safeAreaInsets）
    private static func _availableBounds(in container: UIView) -> CGRect {
        let safe = container.safeAreaInsets
        return container.bounds.inset(by: safe)
    }
    /// 悬浮视图@窗口几何
    /// 构造一个兜底窗口（极少会走到这里）
    private static func _fallbackWindow() -> UIWindow {
        if #available(iOS 13.0, *),
           let scene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first {
            let win = UIWindow(windowScene: scene)
                .byFrame(scene.coordinateSpace.bounds)
                .byWindowLevel(.alert + 1)
                .byHidden(false)
            if win.rootViewController == nil {
                win.byRootViewController(UIViewController())
            };return win
        } else {
            let win = UIWindow(frame: UIScreen.main.bounds)
                .byWindowLevel(.alert + 1)
                .byHidden(false)
            if win.rootViewController == nil {
                win.byRootViewController(UIViewController())
            };return win
        }
    }
}
