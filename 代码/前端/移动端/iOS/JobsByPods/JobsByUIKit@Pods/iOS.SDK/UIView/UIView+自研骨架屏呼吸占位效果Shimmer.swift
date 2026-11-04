//
//  UIView+自研骨架屏呼吸占位效果Shimmer.swift
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
import os.lock
import JobsSwiftBaseDefines
import JobsSwiftDSL

//  ================================== 自述 ==================================
//  这是一个给任意 UIView 添加「Shimmer / 骨架屏扫光」效果的扩展。
//
//  ✅ 用法：
//  - 开启：view.jobs_startShimmer()
//  - 结束：view.jobs_stopShimmer()
//  - 尺寸变化（约束/旋转/复用）时：在 layoutSubviews / layoutSpecThatFits / didLayout 中调用
//    view.jobs_updateShimmerLayout()
//
//  ✅ 特性：
//  - 使用 CAGradientLayer + CABasicAnimation 实现水平扫光。
//  - 自动处理 bounds 变化：宽度变化时会重建动画，避免扫光距离不对。
//  - highlightWidthRatio / duration 做了安全 clamp，避免无效 locations 或 0 时长。
//  - 会临时开启 clipsToBounds，并在 stop 时恢复原值；同理会临时提升 cornerRadius 并恢复，
//    避免对宿主 view 产生“永久副作用”。
//  - 颜色使用 resolvedColor(with:) 支持暗黑模式动态色（若外部在 trait 变化时调用 refresh）。
//
//  ⚠️ 列表复用建议：cell.prepareForReuse() 里调用 jobs_stopShimmer()，避免残留 layer/动画。
//  ========================================================================
// MARK: - 自动跟随布局更新（无需子类化）
// 说明：很多时候 startShimmer 发生在 AutoLayout 真正出 frame 之前（bounds=0），
// 如果外部又无法在 layoutSubviews / viewDidLayoutSubviews 里手动调用 update，
// 那么 shimmer 可能永远不会“启动”。
//
// 这里通过轻量 swizzle UIView.layoutSubviews：
// - 仅当 view 正在 shimmer 时才调用 jobs_updateShimmerLayout()
// - 外部无需子类化 UIButton / UIView
private enum JobsShimmerSwizzle {
    static let once: Void = {
        let cls: AnyClass = UIView.self
        let originalSel = #selector(UIView.layoutSubviews)
        let swizzledSel = #selector(UIView.jobs_shimmer_layoutSubviews)
        guard let original = class_getInstanceMethod(cls, originalSel),
              let swizzled = class_getInstanceMethod(cls, swizzledSel) else {
            return
        };method_exchangeImplementations(original, swizzled)
    }()
}

/// 全局运行态：用于保证 shimmer 的 swizzle 对“未启用 shimmer 的视图”开销尽可能低。
/// 注意：即便如此，若同时存在 SkeletonView 等其它库也 swizzle 了 layoutSubviews，
/// 调用栈仍会串联出现（这是 swizzle 的机制决定的），但这里确保只有我们自己的 shimmer view
/// 才会执行 jobs_updateShimmerLayout()。
private enum JobsShimmerRuntime {
    private static var lock = os_unfair_lock_s()
    private static var _activeCount: Int = 0
    static var activeCount: Int {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) };return _activeCount
    }
    static func inc() {
        os_unfair_lock_lock(&lock)
        _activeCount += 1
        os_unfair_lock_unlock(&lock)
    }
    static func dec() {
        os_unfair_lock_lock(&lock)
        _activeCount = max(0, _activeCount - 1)
        os_unfair_lock_unlock(&lock)
    }
}

extension UIView {
    private static func jobs_enableShimmerAutoLayoutUpdatesOnce() {
        _ = JobsShimmerSwizzle.once
    }

    @objc
    internal func jobs_shimmer_layoutSubviews() {
        // 注意：交换实现后，这里调用的是“原始 layoutSubviews”（可能已被其它库 swizzle 过）。
        self.jobs_shimmer_layoutSubviews()
        // 全局没有任何 shimmer 活跃时，直接返回（避免对非 shimmer view 产生额外开销）。
        guard JobsShimmerRuntime.activeCount > 0 else { return }
        // 只对我们自己的 shimmer view 生效
        guard jobs_isShimmeringStored else { return }
        jobs_updateShimmerLayout()
    }
}
// MARK: - 配置对象
public struct JobsShimmerConfig {
    public var baseColor: UIColor
    public var highlightColor: UIColor
    public var duration: CFTimeInterval       // 单次扫光时长
    public var pauseDuration: CFTimeInterval  // 每次扫光后的停顿时长
    public var highlightWidthRatio: CGFloat   // 0 ~ 1
    public static let `default` = JobsShimmerConfig()
    public init(
        baseColor: UIColor = UIColor(gray: 0.90 * 255),
        highlightColor: UIColor = UIColor(gray: 255, alpha: 0.9),
        duration: CFTimeInterval = 1.4,
        pauseDuration: CFTimeInterval = 0,
        highlightWidthRatio: CGFloat = 0.35
    ) {
        self.baseColor = baseColor
        self.highlightColor = highlightColor
        self.duration = duration
        self.pauseDuration = pauseDuration
        self.highlightWidthRatio = highlightWidthRatio
    }
}
// MARK: - 关联 Key
private enum JobsShimmerAssociatedKeys {
    static var containerLayerKey: UInt8 = 0
    static var layerKey: UInt8  = 0
    static var configKey: UInt8 = 0
    static var isOnKey: UInt8   = 0
    static var originClipsKey: UInt8 = 0
    static var originCornerKey: UInt8 = 0
    static var lastAnimWidthKey: UInt8 = 0
}
// MARK: - 私有工具
extension UIView {
    private func jobs_withoutImplicitAnimations(_ block: () -> Void) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        block()
        CATransaction.commit()
    }

    private var jobs_originalClipsToBounds: Bool? {
        get { objc_getAssociatedObject(self, &JobsShimmerAssociatedKeys.originClipsKey) as? Bool }
        set {
            objc_setAssociatedObject(
                self,
                &JobsShimmerAssociatedKeys.originClipsKey,
                newValue,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
        }
    }

    private var jobs_originalCornerRadius: CGFloat? {
        get {
            if let n = objc_getAssociatedObject(self, &JobsShimmerAssociatedKeys.originCornerKey) as? NSNumber {
                return CGFloat(truncating: n)
            };return nil
        }
        set {
            let boxed = newValue.map { NSNumber(value: Double($0)) }
            objc_setAssociatedObject(
                self,
                &JobsShimmerAssociatedKeys.originCornerKey,
                boxed,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
        }
    }

    private var jobs_lastAnimationWidth: CGFloat? {
        get {
            if let n = objc_getAssociatedObject(self, &JobsShimmerAssociatedKeys.lastAnimWidthKey) as? NSNumber {
                return CGFloat(truncating: n)
            };return nil
        }
        set {
            let boxed = newValue.map { NSNumber(value: Double($0)) }
            objc_setAssociatedObject(
                self,
                &JobsShimmerAssociatedKeys.lastAnimWidthKey,
                boxed,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
        }
    }

    private var jobs_shimmerContainerLayer: CALayer? {
        get {
            objc_getAssociatedObject(self, &JobsShimmerAssociatedKeys.containerLayerKey) as? CALayer
        }
        set {
            objc_setAssociatedObject(
                self,
                &JobsShimmerAssociatedKeys.containerLayerKey,
                newValue,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
        }
    }

    private var jobs_shimmerLayer: CAGradientLayer? {
        get {
            objc_getAssociatedObject(self, &JobsShimmerAssociatedKeys.layerKey) as? CAGradientLayer
        }
        set {
            objc_setAssociatedObject(
                self,
                &JobsShimmerAssociatedKeys.layerKey,
                newValue,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
        }
    }

    private var jobs_shimmerConfig: JobsShimmerConfig {
        get {
            (objc_getAssociatedObject(self, &JobsShimmerAssociatedKeys.configKey) as? JobsShimmerConfig)
            ?? .default
        }
        set {
            objc_setAssociatedObject(
                self,
                &JobsShimmerAssociatedKeys.configKey,
                newValue,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
        }
    }

    private var jobs_isShimmeringStored: Bool {
        get {
            (objc_getAssociatedObject(self, &JobsShimmerAssociatedKeys.isOnKey) as? Bool) ?? false
        }
        set {
            objc_setAssociatedObject(
                self,
                &JobsShimmerAssociatedKeys.isOnKey,
                newValue,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
        }
    }

    private func jobs_prepareShimmerLayerIfNeeded() -> CAGradientLayer {
        if let layer = jobs_shimmerLayer {
            return layer
        }
        let containerLayer = CALayer()
            .byName("jobs.shimmer.container")
            .byMasksToBounds(true)
            .byActions([
                "bounds": NSNull(),
                "position": NSNull(),
                "frame": NSNull(),
                "cornerRadius": NSNull(),
                "mask": NSNull()
            ])
        self.layer.byAddSublayer(containerLayer)
        let layer = CAGradientLayer()
            .byName("jobs.shimmer.layer")
            // 禁用布局更新时的隐式动画（避免闪一下）
            .byActions([
                "bounds": NSNull(),
                "position": NSNull(),
                "frame": NSNull(),
                "cornerRadius": NSNull(),
                "contents": NSNull(),
                "colors": NSNull(),
                "locations": NSNull()
            ])
            .byStartPoint(CGPoint(x: 0, y: 0.5))
            .byEndPoint(CGPoint(x: 1, y: 0.5))
        containerLayer.byAddSublayer(layer)
        jobs_shimmerContainerLayer = containerLayer
        jobs_shimmerLayer = layer
        return layer
    }

    private func jobs_updateShimmerColors() {
        guard let layer = jobs_shimmerLayer else { return }
        let cfg = jobs_shimmerConfig
        // 动态色支持：resolvedColor(with:) 可跟随暗黑模式变化
        let base = cfg.baseColor.jobsResolvedColor(with: traitCollection)
        let highlight = cfg.highlightColor.jobsResolvedColor(with: traitCollection)
        let c1 = base.cgColor
        let c2 = highlight.cgColor
        let ratio = min(max(cfg.highlightWidthRatio, 0), 1)
        let mid = 0.5
        let half = Double(ratio) / 2.0
        let start = max(0, mid - half)
        let end   = min(1, mid + half)
        layer
            .byColors([c1, c1, c2, c1, c1])
            .byLocations([
                0.0 as NSNumber,
                NSNumber(value: start),
                NSNumber(value: mid),
                NSNumber(value: end),
                1.0 as NSNumber
            ])
    }

    private func jobs_startShimmerAnimationIfNeeded(forceRestartIfWidthChanged: Bool = false) {
        guard let layer = jobs_shimmerLayer else { return }
        guard jobs_isShimmeringStored else { return }
        let cfg = jobs_shimmerConfig
        let w = bounds.width
        guard w > 0 else { return }
        if forceRestartIfWidthChanged {
            let last = jobs_lastAnimationWidth ?? 0
            if abs(last - w) > 0.5 {
                layer.removeAnimation(forKey: "jobs.shimmer")
            }
        }
        guard layer.animation(forKey: "jobs.shimmer") == nil else {
            jobs_lastAnimationWidth = w
            return
        }
        let sweepDuration = max(cfg.duration, 0.01)
        let pauseDuration = max(cfg.pauseDuration, 0)
        let cycleDuration = sweepDuration + pauseDuration
        let sweepProgress = sweepDuration / cycleDuration
        layer.add(
            CAKeyframeAnimation(keyPath: "transform.translation.x")
                .byValues([
                    NSNumber(value: Double(-w)),
                    NSNumber(value: Double(w)),
                    NSNumber(value: Double(w))
                ])
                .byKeyTimes([
                    0.0 as NSNumber,
                    NSNumber(value: sweepProgress),
                    1.0 as NSNumber
                ])
                .byTimingFunctions([
                    CAMediaTimingFunction(controlPoints: 0.4, 0, 0.2, 1),
                    CAMediaTimingFunction(name: .linear)
                ])
                .byCalculationMode(.linear)
                .byDuration(cycleDuration)
                .byRepeatCount(.greatestFiniteMagnitude)
                .byRemovedOnCompletion(false), forKey: "jobs.shimmer")
        jobs_lastAnimationWidth = w
    }
}
// MARK: - 公共 API
extension UIView {
    /// 是否正在呼吸
    public var jobs_isShimmering: Bool {
        get {
            jobs_isShimmeringStored
        }
        set {
            if newValue {
                // 用当前已经保存的 config 重新开启（不会丢自定义配置）
                jobs_startShimmer(config: jobs_shimmerConfig)
            } else {
                jobs_stopShimmer()
            }
        }
    }
    /// 开始呼吸效果
    public func jobs_startShimmer(config: JobsShimmerConfig = .default) {
        // ✅ 无需子类化：自动跟随布局变化刷新 shimmer layer frame
        UIView.jobs_enableShimmerAutoLayoutUpdatesOnce()
        // 记录原始状态（仅首次开启时记录，stop 时会清理）
        if jobs_originalClipsToBounds == nil {
            jobs_originalClipsToBounds = clipsToBounds
        }
        if jobs_originalCornerRadius == nil {
            jobs_originalCornerRadius = layer.cornerRadius
        }
        jobs_shimmerConfig = config
        if jobs_isShimmeringStored == false {
            JobsShimmerRuntime.inc()
        }
        jobs_isShimmeringStored = true
        // 临时开启裁剪：因为 shimmer layer 会比 bounds 更宽（-w...3w）
        clipsToBounds = true
        let layer = jobs_prepareShimmerLayerIfNeeded()
        // 布局和颜色
        jobs_updateShimmerLayout()
        jobs_updateShimmerColors()
        // 动画
        jobs_startShimmerAnimationIfNeeded(forceRestartIfWidthChanged: true)
        layer.byHidden(false)
    }
    /// 停止呼吸效果
    public func jobs_stopShimmer() {
        if jobs_isShimmeringStored {
            JobsShimmerRuntime.dec()
        }
        jobs_isShimmeringStored = false
        jobs_shimmerLayer?.removeAnimation(forKey: "jobs.shimmer")
        jobs_shimmerContainerLayer?.removeFromSuperlayer()
        jobs_shimmerLayer = nil
        jobs_shimmerContainerLayer = nil
        // 恢复原始属性，避免对宿主 view 产生永久副作用
        if let originClips = jobs_originalClipsToBounds {
            clipsToBounds = originClips
        }
        if let originCorner = jobs_originalCornerRadius {
            jobs_withoutImplicitAnimations { layer.cornerRadius = originCorner }
        }
        jobs_originalClipsToBounds = nil
        jobs_originalCornerRadius = nil
        jobs_lastAnimationWidth = nil
    }
    /// 视图尺寸变化时调用，更新渐变层 layout（建议在 layoutSubviews 里调用）
    public func jobs_updateShimmerLayout() {
        guard let containerLayer = jobs_shimmerContainerLayer,
              let layer = jobs_shimmerLayer,
              jobs_isShimmeringStored else { return }
        let w = bounds.width
        let h = bounds.height
        guard w > 0, h > 0 else { return }
        jobs_withoutImplicitAnimations {
            containerLayer.byFrame(bounds)
            layer.byFrame(CGRect(x: -w, y: 0, width: w * 3, height: h))
            // 复刻“bar view”常见的圆角效果：
            // - 如果外部已经给 view 配了 cornerRadius，则尊重外部
            // - 否则默认使用 pill（h/2）
            let baseCorner = jobs_originalCornerRadius ?? self.layer.cornerRadius
            let desiredCorner = max(baseCorner, h / 2)
            containerLayer.byCornerRadius(desiredCorner)
            layer.byCornerRadius(desiredCorner)
            self.layer.byCornerRadius(max(self.layer.cornerRadius, desiredCorner))
        }
        // ✅ 尺寸变化后，确保动画距离正确
        jobs_startShimmerAnimationIfNeeded(forceRestartIfWidthChanged: true)
    }
    /// 仅给呼吸层设置 mask（SlideToUnlock 用这个来裁掉滑块经过区域）
    public func jobs_setShimmerMask(_ maskLayer: CALayer?) {
        // mask 必须挂在静止容器上，否则会跟着渐变层一起平移，导致可见区域被裁空。
        jobs_shimmerContainerLayer?.mask = maskLayer
    }
}
// MARK: - DSL
extension UIView {
    /// DSL：启用/关闭呼吸效果
    @discardableResult
    public func byShimmering(_ enabled: Bool,
                      config: JobsShimmerConfig = .default) -> Self {
        if enabled {
            jobs_startShimmer(config: config)
        } else {
            jobs_stopShimmer()
        };return self
    }
    /// DSL：修改呼吸颜色（不改变开关状态）
    @discardableResult
    public func byShimmerColors(base: UIColor, highlight: UIColor) -> Self {
        var cfg = jobs_shimmerConfig
        cfg.baseColor = base
        cfg.highlightColor = highlight
        jobs_shimmerConfig = cfg
        jobs_updateShimmerColors()
        return self
    }

    /// DSL：修改单次扫光时长（不改变开关状态）
    @discardableResult
    public func byShimmerDuration(_ duration: CFTimeInterval) -> Self {
        var cfg = jobs_shimmerConfig
        cfg.duration = max(duration, 0.01)
        jobs_shimmerConfig = cfg
        if jobs_isShimmeringStored {
            jobs_shimmerLayer?.removeAnimation(forKey: "jobs.shimmer")
            jobs_startShimmerAnimationIfNeeded()
        };return self
    }

    /// DSL：修改每次扫光后的停顿时长（不改变开关状态）
    @discardableResult
    public func byShimmerPauseDuration(_ duration: CFTimeInterval) -> Self {
        var cfg = jobs_shimmerConfig
        cfg.pauseDuration = max(duration, 0)
        jobs_shimmerConfig = cfg
        if jobs_isShimmeringStored {
            jobs_shimmerLayer?.removeAnimation(forKey: "jobs.shimmer")
            jobs_startShimmerAnimationIfNeeded()
        };return self
    }

    /// DSL：修改高光宽度比例（不改变开关状态）
    @discardableResult
    public func byShimmerHighlightWidthRatio(_ ratio: CGFloat) -> Self {
        var cfg = jobs_shimmerConfig
        cfg.highlightWidthRatio = min(max(ratio, 0), 1)
        jobs_shimmerConfig = cfg
        jobs_updateShimmerColors()
        return self
    }
}
// MARK: - UIButton 前景图 Loading Shimmer Overlay（无需子类化）
private enum JobsUIButtonFGOverlayAOKeys {
    static var overlayKey: UInt8 = 0
    static var targetSizeKey: UInt8 = 0
}

private enum JobsUIButtonFGOverlaySwizzle {
    static let once: Void = {
        let cls: AnyClass = UIButton.self
        let originalSel = #selector(UIButton.layoutSubviews)
        let swizzledSel = #selector(UIButton.jobs_fgOverlay_layoutSubviews)
        guard let original = class_getInstanceMethod(cls, originalSel),
              let swizzled = class_getInstanceMethod(cls, swizzledSel) else { return }
        method_exchangeImplementations(original, swizzled)
    }()
}

extension UIButton {
    private static func jobs_enableForegroundOverlayAutoLayoutUpdatesOnce() {
        _ = JobsUIButtonFGOverlaySwizzle.once
    }

    private var jobs_fgOverlayTargetSize: CGSize? {
        get {
            if let v = objc_getAssociatedObject(self, &JobsUIButtonFGOverlayAOKeys.targetSizeKey) as? NSValue {
                return v.cgSizeValue
            };return nil
        }
        set {
            let boxed = newValue.map { NSValue(cgSize: $0) }
            objc_setAssociatedObject(self, &JobsUIButtonFGOverlayAOKeys.targetSizeKey, boxed, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }

    private var jobs_fgShimmerOverlayView: UIView? {
        get { objc_getAssociatedObject(self, &JobsUIButtonFGOverlayAOKeys.overlayKey) as? UIView }
        set { objc_setAssociatedObject(self, &JobsUIButtonFGOverlayAOKeys.overlayKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    private func jobs_getOrCreateFGOverlayView() -> UIView {
        if let v = jobs_fgShimmerOverlayView { return v }
        // overlay 尺寸/位置完全由 jobs_layoutFGOverlayIfNeeded() 决定
        let v = UIView(frame: .zero)
        v.isUserInteractionEnabled = false
        v.backgroundColor = JobsCor.clear
        v.isHidden = true
        self.addSubview(v)
        jobs_fgShimmerOverlayView = v
        return v
    }

    private func jobs_fgOverlayRect(targetSize: CGSize) -> CGRect {
        let b = self.bounds
        guard b.width > 1, b.height > 1 else { return .zero }
        // ✅ 最优先：直接使用 imageView 的最终 frame（最贴近系统真实呈现）
        // - 在你“先灌兜底图撑开”的策略下，这里通常能拿到稳定 frame
        if let iv = self.imageView {
            let s = iv.bounds.size
            if s.width > 1, s.height > 1 {
                return iv.frame.integral
            }
        }
        let content = jobs_effectiveContentRect(in: b)
        guard content.width > 1, content.height > 1 else { return .zero }
        // 使用 targetSize / currentImage 尺寸兜底（避免调用 iOS15 起 deprecated 的 imageRect/contentRect）
        var baseSize = targetSize
        if baseSize.width <= 1 || baseSize.height <= 1, let img = self.currentImage {
            baseSize = img.size
        }
        guard baseSize.width > 1, baseSize.height > 1 else { return .zero }
        let w = min(max(baseSize.width, 1), content.width)
        let h = min(max(baseSize.height, 1), content.height)
        var x: CGFloat
        switch self.contentHorizontalAlignment {
        /// 处理 .right 分支
        case .right:  x = content.maxX - w
        /// 处理 .center 分支
        case .center: x = content.midX - w / 2
        /// 处理 .fill 分支
        case .fill:   x = content.minX
        /// 未匹配已知分支时执行兜底处理
        default:      x = content.minX
        }
        var y: CGFloat
        switch self.contentVerticalAlignment {
        /// 处理 .top 分支
        case .top:    y = content.minY
        /// 处理 .bottom 分支
        case .bottom: y = content.maxY - h
        /// 处理 .fill 分支
        case .fill:   y = content.minY
        /// 未匹配已知分支时执行兜底处理
        default:      y = content.midY - h / 2
        }
        var rect = CGRect(x: x, y: y, width: w, height: h)
        // legacy：imageEdgeInsets 做个近似偏移（configuration 模式下不走这套）
        // ⚠️ iOS15+ 直接访问 imageEdgeInsets 会产生 deprecated warning；
        // 这里改为走你统一的兼容读取（KVC），既保留 legacy 行为，也不污染编译输出。
        if #available(iOS 15.0, *), self.configuration != nil {
            // no-op
        } else {
            let insets = self.jobs_legacyImageEdgeInsets
            rect.origin.x += insets.left - insets.right
            rect.origin.y += insets.top - insets.bottom
        };return rect.integral
    }

    private func jobs_effectiveContentRect(in bounds: CGRect) -> CGRect {
        if #available(iOS 15.0, *), let cfg = self.configuration {
            let di = cfg.contentInsets
            let isRTL = (self.effectiveUserInterfaceLayoutDirection == .rightToLeft)
            let left = isRTL ? di.trailing : di.leading
            let right = isRTL ? di.leading : di.trailing
            return bounds.inset(by: UIEdgeInsets(top: di.top, left: left, bottom: di.bottom, right: right))
        } else {
            // ⚠️ iOS15+ 直接访问 contentEdgeInsets 会产生 deprecated warning；
            // 改为走兼容读取（KVC）。
            return bounds.inset(by: self.jobs_legacyContentEdgeInsets)
        }
    }

    private func jobs_layoutFGOverlayIfNeeded() {
        guard let overlay = jobs_fgShimmerOverlayView, !overlay.isHidden else { return }
        let size = jobs_fgOverlayTargetSize ?? CGSize(width: 48, height: 48)
        let r = jobs_fgOverlayRect(targetSize: size)
        guard r.width > 1, r.height > 1 else { return }
        overlay.frame = r
        // ✅ 圆角：优先贴合 imageView，其次走默认
        if let iv = self.imageView, iv.layer.cornerRadius > 0 {
            overlay.layer.cornerRadius = iv.layer.cornerRadius
        } else {
            overlay.layer.cornerRadius = min(r.height / 2, 12)
        }
        overlay.clipsToBounds = true
        // ✅ 兜底：确保 overlay 永远在最上面（避免 UIButton 内部重排子视图后被盖住）
        bringSubviewToFront(overlay)
        // 只有在 shimmer 开启时才刷新 shimmer layer
        if overlay.jobs_isShimmering {
            overlay.jobs_updateShimmerLayout()
        }
    }

    @objc
    internal func jobs_fgOverlay_layoutSubviews() {
        // 注意：交换实现后，这里调用的是“原始 layoutSubviews”
        self.jobs_fgOverlay_layoutSubviews()
        jobs_layoutFGOverlayIfNeeded()
    }
}

extension UIButton {
    /// 前景图 loading：直接作用于当前 imageView，不向 UIButton 内部层级插入 overlay。
    public func _jobs_startForegroundShimmerOverlay(targetSize _: CGSize) {
        // UIButton.Configuration 会重建内部 imageView；旧 imageView 被替换时，shimmer layer 随之释放。
        self.imageView?.jobs_startShimmer()
    }
    /// 前景图 loading：关闭 shimmer
    public func _jobs_stopForegroundShimmerOverlay() {
        self.imageView?.jobs_stopShimmer()
    }
}
