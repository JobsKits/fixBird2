//
//  UIView+外圈Layer导火索倒计时效果.swift
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
import JobsSwiftBaseDefines
import JobsSwiftTimer
import JobsSwiftDSL
/// 导火索式倒计时：在任意 UIView 最外层画一圈可消耗的边框，随着时间递减
/// 导火索倒计时配置（按需可以继续扩）
/// 这里先做最小配置：线宽、颜色、内边距、结束后是否移除

public struct JobsFuseConfig {
    /// 动画方向：顺时针 / 逆时针
    public enum Direction {
        /// 逆时针：当前行为（strokeEnd: 1 → 0）
        case counterClockwise
        /// 顺时针：改为动 strokeStart: 0 → 1
        case clockwise
    }
    public var lineWidth: CGFloat
    public var color: UIColor
    public var inset: CGFloat
    public var removeOnFinish: Bool
    public var direction: Direction

    public init(lineWidth: CGFloat = 4,
                color: UIColor = JobsCor.systemRed,
                inset: CGFloat = 0,
                removeOnFinish: Bool = true,
                direction: Direction = .counterClockwise) {
        self.lineWidth = lineWidth
        self.color = color
        self.inset = inset
        self.removeOnFinish = removeOnFinish
        self.direction = direction
    }
}

extension UIView {
    // MARK: - Associated Keys
    private struct JobsFuseKeys {
        static var processKey: UInt8 = 0   // 先保留，外部类型不改
        static var layerKey: UInt8 = 0
        static var configKey: UInt8 = 0
        static var completionKey: UInt8 = 0
    }
    /// 旧的倒计时 Process（现在基本不用了，只是为了兼容）
    private var jobs_fuseProcess: JobsSwiftTimerCountdown? {
        get {
            objc_getAssociatedObject(self, &JobsFuseKeys.processKey) as? JobsSwiftTimerCountdown
        }
        set {
            objc_setAssociatedObject(
                self,
                &JobsFuseKeys.processKey,
                newValue,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }

    private var jobs_fuseLayer: CAShapeLayer? {
        get {
            objc_getAssociatedObject(self, &JobsFuseKeys.layerKey) as? CAShapeLayer
        }
        set {
            objc_setAssociatedObject(
                self,
                &JobsFuseKeys.layerKey,
                newValue,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }

    private var jobs_fuseConfig: JobsFuseConfig? {
        get {
            objc_getAssociatedObject(self, &JobsFuseKeys.configKey) as? JobsFuseConfig
        }
        set {
            objc_setAssociatedObject(
                self,
                &JobsFuseKeys.configKey,
                newValue,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }

    private var jobs_fuseCompletion: (() -> Void)? {
        get {
            objc_getAssociatedObject(self, &JobsFuseKeys.completionKey) as? (() -> Void)
        }
        set {
            objc_setAssociatedObject(
                self,
                &JobsFuseKeys.completionKey,
                newValue,
                .OBJC_ASSOCIATION_COPY_NONATOMIC)
        }
    }
    // MARK: - 公共 API
    /// DSL 写法：在当前视图上挂一个导火索倒计时
    @discardableResult
    public func byFuseCountdown(duration: TimeInterval,
                                config: JobsFuseConfig = JobsFuseConfig(),
                                finished: (() -> Void)? = nil) -> Self {
        jobs_startFuseCountdown(duration: duration,
                                config: config,
                                finished: finished)
        return self
    }
    /// 显式启动导火索倒计时（现在用 CABasicAnimation 驱动 strokeEnd / strokeStart）
    ///
    /// - Parameters:
    ///   - duration: 总时长（秒）
    ///   - config: 外观配置（线宽、颜色、inset、方向）
    ///   - finished: 结束时回调
    @discardableResult
    public func jobs_startFuseCountdown(duration: TimeInterval,
                                        config: JobsFuseConfig = JobsFuseConfig(),
                                        finished: (() -> Void)? = nil) -> JobsSwiftTimerCountdown? {
        layoutIfNeeded()
        guard bounds.width > 0,
              bounds.height > 0,
              duration > 0 else {
            // 没尺寸或者 duration <= 0，直接清掉
            jobs_cancelFuseCountdown()
            finished?()
            return nil
        }
        // 先停掉旧的 Process & 动画（保留 layer）
        jobs_cancelFuseCountdown(removeLayer: false)
        jobs_fuseConfig = config
        jobs_fuseCompletion = finished
        // 拿到 / 创建 Layer
        let fuseLayer: CAShapeLayer
        if let existing = jobs_fuseLayer {
            fuseLayer = existing
        } else {
            fuseLayer = CAShapeLayer()
                .byFillColor(JobsCor.clear)
                .byLineCap(.round)
                .byAddTo(layer)
            jobs_fuseLayer = fuseLayer
        }
        let inset = config.inset + config.lineWidth / 2.0
        let rect = bounds.insetBy(dx: inset, dy: inset)
        let cornerRadius = self.layer.cornerRadius
        let path = UIBezierPath.make(roundedRect: rect, cornerRadius: cornerRadius)
        // 配置 Layer 几何与样式
        fuseLayer
            .byFrame(bounds)
            .byPath(path.cgPath)
            .byLineWidth(config.lineWidth)
            .byStrokeColor(config.color)
        // 重置到“满格”状态（禁用隐式动画）
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        fuseLayer.byStrokeStart(0).byStrokeEnd(1)
        CATransaction.commit()
        // 用 CABasicAnimation 按方向动 strokeStart / strokeEnd
        let animKey = "jobsFuseStroke"
        CATransaction.begin()
        CATransaction.setCompletionBlock { [weak self] in
            guard let self else { return }
            if config.removeOnFinish {
                self.jobs_removeFuseLayer()
            } else {
                // 不移除时，保持最终状态
                switch config.direction {
                /// 处理 .counterClockwise 分支
                case .counterClockwise:
                    self.jobs_fuseLayer?.strokeEnd = 0
                /// 处理 .clockwise 分支
                case .clockwise:
                    self.jobs_fuseLayer?.strokeStart = 1
                }
            }
            self.jobs_fuseCompletion?()
            self.jobs_fuseCompletion = nil
        }
        let anim: CABasicAnimation
        switch config.direction {
        /// 处理 .counterClockwise 分支
        case .counterClockwise:
            // 旧行为：尾巴往回缩，视觉上逆时针烧
            anim = CABasicAnimation(keyPath: "strokeEnd").byFromValue(1.0).byToValue(0.0)
        /// 处理 .clockwise 分支
        case .clockwise:
            // 固定 end = 1，头往前推，视觉上顺时针烧
            anim = CABasicAnimation(keyPath: "strokeStart").byFromValue(0.0).byToValue(1.0)
        }
        anim.byDuration(duration)
            .byTimingFunction(CAMediaTimingFunction(name: .linear))
            .byFillMode(.forwards)
            .byRemovedOnCompletion(false)
        fuseLayer.add(anim, forKey: animKey)
        CATransaction.commit()
        // 现在不再依赖 JobsSwiftTimerCountdown，直接返回 nil 即可
        jobs_fuseProcess = nil
        return nil
    }
    /// 取消导火索倒计时
    public func jobs_cancelFuseCountdown(removeLayer: Bool = true) {
        // 兼容旧的 Process
        jobs_fuseProcess?.cancel()
        jobs_fuseProcess = nil
        // 移除动画
        jobs_fuseLayer?.removeAnimation(forKey: "jobsFuseStroke")
        if removeLayer {
            jobs_removeFuseLayer()
        }
    }
    // MARK: - 手动刷新布局（如果你在动画中改变了 view 的大小，可选调用）
    /// 如果 view 的 bounds 发生改变，想让导火索跟着更新一圈，可以在外面的 layoutSubviews/动画回调里手动调一下
    public func jobs_layoutFuseIfNeeded() {
        guard let fuseLayer = jobs_fuseLayer,
              let config = jobs_fuseConfig else { return }
        layoutIfNeeded()
        let inset = config.inset + config.lineWidth / 2.0
        let rect = bounds.insetBy(dx: inset, dy: inset)
        let cornerRadius = self.layer.cornerRadius
        let path = UIBezierPath.make(roundedRect: rect, cornerRadius: cornerRadius)
        fuseLayer.byFrame(bounds).byPath(path.cgPath)
    }
    // MARK: - Private
    private func jobs_removeFuseLayer() {
        jobs_fuseLayer?.removeFromSuperlayer()
        jobs_fuseLayer = nil
    }
}
// MARK: - ✅ 正计时（Progress）支持：准备一圈 + 按 progress 更新
extension UIView {
    /// 准备外圈（progress 初始为 0）
    /// - 注意：这里不做 CABasicAnimation，只是把 layer/path/样式准备好
    public func jobs_prepareFuseProgress(config: JobsFuseConfig = JobsFuseConfig()) {
        layoutIfNeeded()
        guard bounds.width > 0, bounds.height > 0 else { return }
        // 停掉倒计时动画，但保留 layer
        jobs_cancelFuseCountdown(removeLayer: false)
        jobs_fuseConfig = config
        // 拿到 / 创建 Layer（复用你倒计时那套思路）
        let fuseLayer: CAShapeLayer
        if let existing = jobs_fuseLayer {
            fuseLayer = existing
        } else {
            fuseLayer = CAShapeLayer()
                .byFillColor(JobsCor.clear)
                .byLineCap(.round)
                .byAddTo(layer)
            jobs_fuseLayer = fuseLayer
        }
        // 配置几何与样式（复用你倒计时的 path 计算方式）
        let inset = config.inset + config.lineWidth / 2.0
        let rect = bounds.insetBy(dx: inset, dy: inset)
        let cornerRadius = self.layer.cornerRadius
        let path = UIBezierPath.make(roundedRect: rect, cornerRadius: cornerRadius)
        fuseLayer.byFrame(bounds)
            .byPath(path.cgPath)
            .byLineWidth(config.lineWidth)
            .byStrokeColor(config.color)
        // progress 初始=0（禁用隐式动画）
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        switch config.direction {
        /// 处理 .clockwise 分支
        case .clockwise:
            fuseLayer
                .byStrokeStart(0)
                .byStrokeEnd(0)
        /// 处理 .counterClockwise 分支
        case .counterClockwise:
            // 反向增长：先“空”出来（start=end=1）
            fuseLayer
                .byStrokeStart(1)
                .byStrokeEnd(1)
        }
        CATransaction.commit()
    }
    /// 更新外圈 progress（0...1）
    public func jobs_updateFuseProgress(_ progress: CGFloat, animated: Bool = false) {
        let p = max(0, min(1, progress))
        guard let fuseLayer = jobs_fuseLayer else {
            // 没准备过就先准备（用默认 config）
            jobs_prepareFuseProgress()
            jobs_updateFuseProgress(p, animated: animated)
            return
        }
        guard let config = jobs_fuseConfig else {
            jobs_fuseConfig = JobsFuseConfig()
            jobs_updateFuseProgress(p, animated: animated)
            return
        }
        CATransaction.begin()
        CATransaction.setDisableActions(!animated)
        switch config.direction {
        /// 处理 .clockwise 分支
        case .clockwise:
            fuseLayer.byStrokeStart(0)
                .byStrokeEnd(p)
        /// 处理 .counterClockwise 分支
        case .counterClockwise:
            // 反向增长：露出“尾部”那一段
            fuseLayer.byStrokeStart(1 - p).byStrokeEnd(1)
        }
        CATransaction.commit()
    }
}
