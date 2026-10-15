//
//  UIView+Lottie.swift
//  JobsByUIKit
//
//  Created by Jobs on 2026年5月13日，星期三.
//

#if os(OSX)
import AppKit
#elseif os(iOS) || os(tvOS)
import UIKit
#endif

import JobsSwiftBlock
import JobsSwiftDSL

#if canImport(SnapKit) && canImport(Lottie)
import SnapKit
import Lottie
public extension UIView {
    // 关联存储：挂载在任意 UIView 上的唯一 LottieAnimationView（够用了；要多实例你可以自行扩展一个池）
    private struct _JobsLottieAssoc {
        static var viewKey: UInt8 = 0
    }
    /// 当前挂载在该视图上的 Lottie 动画视图
    var jobs_lottieView: LottieAnimationView? {
        get { objc_getAssociatedObject(self, &_JobsLottieAssoc.viewKey) as? LottieAnimationView }
        set { objc_setAssociatedObject(self, &_JobsLottieAssoc.viewKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
    // MARK: 入口：按资源名创建并挂载
    /// 在当前 UIView 上创建并挂载一个 Lottie 动画（默认贴满父视图）
    /// - Parameters:
    ///   - name: Assets / main bundle 中的动画文件名（不带扩展名）
    ///   - bundle: 动画所在 bundle（默认 .main）
    ///   - loop: 循环模式（默认 .loop）
    ///   - speed: 播放速度（默认 1.0）
    ///   - contentMode: 内容适配（默认 .scaleAspectFit）
    ///   - backgroundBehavior: 退后台行为（默认 .pauseAndRestore）
    ///   - autoPlay: 是否自动播放（默认 false）
    ///   - makeConstraints: SnapKit 约束（默认贴满父视图）
    ///   - configure: 最后补充配置（可选）
    /// - Returns: 新建并已挂载的 LottieAnimationView（链式继续 .play() 等）
    @discardableResult
    public func byLottieAnimation(
        _ name: String,
        bundle: Bundle = .main,
        loop: LottieLoopMode = .loop,
        speed: CGFloat = 1.0,
        contentMode: UIView.ContentMode = .scaleAspectFit,
        backgroundBehavior: LottieBackgroundBehavior = .pauseAndRestore,
        autoPlay: Bool = false,
        makeConstraints: ((ConstraintMaker) -> Void)? = { $0.edges.equalToSuperview() },
        configure: ((LottieAnimationView) -> Void)? = nil
    ) -> LottieAnimationView {
        // 1) 创建
        let lottieView = LottieAnimationView(name: name, bundle: bundle)
            .bySpeed(speed)
            .byLoop(loop)
            .byLottieContentMode(contentMode)
            .byBackgroundBehavior(backgroundBehavior)
        // 2) 挂载 + 约束
        if lottieView.superview !== self {
            addSubview(lottieView)
        }
        if let make = makeConstraints {
            lottieView.snp.makeConstraints(make)
        }
        // 3) 额外配置
        configure?(lottieView)
        // 4) 记录引用
        self.jobs_lottieView = lottieView
        // 5) 自动播放（可选）
        if autoPlay { lottieView.play() };return lottieView
    }
    // MARK: 入口（重载）：直接传 LottieAnimation
    /// 你也可以先用 `LottieAnimation.named(...)` 自行解析，再走这个重载
    @discardableResult
    public func byLottieAnimation(
        _ animation: LottieAnimation,
        loop: LottieLoopMode = .loop,
        speed: CGFloat = 1.0,
        contentMode: UIView.ContentMode = .scaleAspectFit,
        backgroundBehavior: LottieBackgroundBehavior = .pauseAndRestore,
        autoPlay: Bool = false,
        makeConstraints: ((ConstraintMaker) -> Void)? = { $0.edges.equalToSuperview() },
        configure: ((LottieAnimationView) -> Void)? = nil
    ) -> LottieAnimationView {
        let lottieView = LottieAnimationView(animation: animation)
        lottieView.loopMode = loop
        lottieView.animationSpeed = speed
        lottieView.contentMode = contentMode
        lottieView.byBackgroundBehavior(backgroundBehavior)
        if lottieView.superview !== self {
            addSubview(lottieView)
        }
        if let make = makeConstraints {
            lottieView.snp.makeConstraints(make)
        }
        configure?(lottieView)
        self.jobs_lottieView = lottieView
        if autoPlay { lottieView.play() };return lottieView
    }
    // MARK: - UIView 层便捷控制（保持语义链式）
    @discardableResult
    public func lottiePlay(completion: (jobsByBoolBlock)? = nil) -> Self {
        jobs_lottieView?.play(completion: completion)
        return self
    }

    @discardableResult
    public func lottiePause() -> Self {
        jobs_lottieView?.pause()
        return self
    }
    /// 停止并可选重置到起点
    @discardableResult
    public func lottieStop(resetToBeginning: Bool = false) -> Self {
        jobs_lottieView?.stop()
        if resetToBeginning { jobs_lottieView?.currentProgress = 0 };return self
    }
    /// 设置进度（0~1）
    @discardableResult
    public func lottieProgress(_ progress: CGFloat) -> Self {
        jobs_lottieView?.currentProgress = min(max(progress, 0), 1)
        return self
    }
    /// 替换动画资源（保留其他播放参数）
    @discardableResult
    public func lottieReplace(name: String, bundle: Bundle = .main, autoPlay: Bool = false) -> Self {
        guard let v = jobs_lottieView else { return self }
        v.animation = LottieAnimation.named(name, bundle: bundle)
        if autoPlay { v.play() };return self
    }
    /// 卸载当前挂载的 Lottie 视图
    @discardableResult
    public func lottieRemove() -> Self {
        jobs_lottieView?.removeFromSuperview()
        jobs_lottieView = nil
        return self
    }
}
// MARK: - LottieAnimationView 小型 DSL（可选：增强链式体验）
public extension LottieAnimationView {
    @discardableResult
    func byLoop(_ mode: LottieLoopMode) -> Self { loopMode = mode; return self }

    @discardableResult
    func bySpeed(_ value: CGFloat) -> Self { animationSpeed = value; return self }

    @discardableResult
    func byLottieContentMode(_ mode: UIView.ContentMode) -> Self { contentMode = mode; return self }

    @discardableResult
    func byBackgroundBehavior(_ behavior: LottieBackgroundBehavior) -> Self {
        backgroundBehavior = behavior
        return self
    }
}
#endif
