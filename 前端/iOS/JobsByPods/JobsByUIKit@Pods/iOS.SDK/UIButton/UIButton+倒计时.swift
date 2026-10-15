//
//  UIButton+倒计时.swift
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
import JobsSwiftBlock
import JobsSwiftTimer
import JobsTextTools
import JobsSwiftBaseDefines

// MARK: - Associated Keys
private var _timerTickAnyKey: UInt8 = 0
private var _timerFinishAnyKey: UInt8 = 0
private var _legacyCountdownTickKey: UInt8 = 0
private var _legacyCountdownFinishKey: UInt8 = 0
private var _timerCoreKey: UInt8 = 0
private var _timerKindKey: UInt8 = 0
private var _timerModeKey: UInt8 = 0
private var _timerStateKey: UInt8 = 0
private var _timerStateDidChangeKey: UInt8 = 0
// MARK: - Core
extension UIButton {
    public var timer: JobsSwiftTimerProtocol? {
        get { objc_getAssociatedObject(self, &_timerCoreKey) as? JobsSwiftTimerProtocol }
        set {
            objc_setAssociatedObject(
                self,
                &_timerCoreKey,
                newValue,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
        }
    }

    public var timerState: TimerState {
        get { (objc_getAssociatedObject(self, &_timerStateKey) as? TimerState) ?? .idle }
        set {
            let old = timerState
            objc_setAssociatedObject(self,
                                     &_timerStateKey,
                                     newValue,
                                     .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            if let hook = objc_getAssociatedObject(self, &_timerStateDidChangeKey) as? TimerStateChangeHandler {
                hook(self, old, newValue)
            } else {
                applyDefaultTimerUI(for: newValue)
            }
            if #available(iOS 15.0, *) { setNeedsUpdateConfiguration() }
        }
    }

    @discardableResult
    public func onTimerStateChange(_ handler: @escaping TimerStateChangeHandler) -> Self {
        objc_setAssociatedObject(self,
                                 &_timerStateDidChangeKey,
                                 handler,
                                 .OBJC_ASSOCIATION_COPY_NONATOMIC)
        return self
    }

    private func applyDefaultTimerUI(for state: TimerState) {
        switch state {
        /// 合并处理 .idle、.stopped 分支
        case .idle, .stopped:
            isEnabled = true
            alpha = 1.0
        /// 处理 .running 分支
        case .running:
            isEnabled = true
            alpha = 1.0
        /// 处理 .paused 分支
        case .paused:
            isEnabled = true
            alpha = 0.85
        }
    }
    // MARK: - Callbacks
    @discardableResult
    public func onTimerTick(_ handler: @escaping (_ button: UIButton,
                                                  _ current: Int,
                                                  _ total: Int?,
                                                  _ kind: JobsTimerKind) -> Void) -> Self {
        objc_setAssociatedObject(
            self,
            &_timerTickAnyKey,
            handler,
            .OBJC_ASSOCIATION_COPY_NONATOMIC
        );return self
    }

    @discardableResult
    public func onTimerFinish(_ handler: @escaping (_ button: UIButton,
                                                    _ kind: JobsTimerKind) -> Void) -> Self {
        objc_setAssociatedObject(
            self,
            &_timerFinishAnyKey,
            handler,
            .OBJC_ASSOCIATION_COPY_NONATOMIC
        );return self
    }

    @discardableResult
    public func onCountdownTick(_ handler: @escaping (_ button: UIButton,
                                                      _ remain: Int,
                                                      _ total: Int,
                                                      _ kind: JobsTimerKind) -> Void) -> Self {
        onTimerTick { btn, current, totalOpt, kind in
            if let total = totalOpt { handler(btn, current, total, kind) }
        }
    }

    @discardableResult
    public func onCountdownFinish(_ handler: @escaping (_ button: UIButton,
                                                        _ kind: JobsTimerKind) -> Void) -> Self {
        onTimerFinish(handler)
    }
    // MARK: - Start / Pause / Resume / Stop
    @discardableResult
    public func startTimer(
        total: Int? = nil,
        interval: TimeInterval = 1.0,
        kind: JobsTimerKind? = nil,
        onStartBlock: ((UIButton) -> Void)? = nil
    ) -> Self {
        let kind = kind ?? .gcd
        stopTimer()
        if let total {
            objc_setAssociatedObject(
                self,
                &_timerModeKey,
                _TimerMode.countdown(remain: total, total: total),
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
            isEnabled = false
            onStartBlock?(self)
        } else {
            objc_setAssociatedObject(
                self,
                &_timerModeKey,
                _TimerMode.countUp(elapsed: 0),
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            );onStartBlock?(self)
        }
        objc_setAssociatedObject(
            self,
            &_timerKindKey,
            kind,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
        let core = JobsTimer(kind: kind,
                             config: JobsSwiftTimerConfig(
                                interval: interval,
                                repeats: true,
                                tolerance: 0.01,
                                queue: .main))
        { [weak self] in
            guard let self else { return }
            // ✅ Swift 6：handler 是 @Sendable，触 UI 统一回 MainActor
            onMainAsync(self) { vc in
                guard var mode = objc_getAssociatedObject(self, &_timerModeKey) as? _TimerMode else { return }
                let k = (objc_getAssociatedObject(self, &_timerKindKey) as? JobsTimerKind) ?? kind
                switch mode {
                /// 处理 .countUp 分支
                case .countUp(let elapsed0):
                    let elapsed = elapsed0 + 1
                    mode = .countUp(elapsed: elapsed)
                    objc_setAssociatedObject(
                        self,
                        &_timerModeKey,
                        mode,
                        .OBJC_ASSOCIATION_RETAIN_NONATOMIC
                    )
                    self.setTitle("\(elapsed)", for: .normal)
                    if let tick = objc_getAssociatedObject(self, &_timerTickAnyKey)
                        as? (UIButton, Int, Int?, JobsTimerKind) -> Void {
                        tick(self, elapsed, nil, k)
                    }
                /// 处理 .countdown 分支
                case .countdown(let remain0, let total):
                    let remain = remain0 - 1
                    if remain > 0 {
                        mode = .countdown(remain: remain, total: total)
                        objc_setAssociatedObject(
                            self,
                            &_timerModeKey,
                            mode,
                            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
                        )
                        self.setTitle("\(remain)s", for: .normal)
                        if let tick = objc_getAssociatedObject(self, &_timerTickAnyKey)
                            as? (UIButton, Int, Int?, JobsTimerKind) -> Void {
                            tick(self, remain, total, k)
                        }
                        if let legacy = objc_getAssociatedObject(self, &_legacyCountdownTickKey) as? (Int, Int) -> Void {
                            legacy(remain, total)
                        }
                    } else {
                        if let fin = objc_getAssociatedObject(self, &_timerFinishAnyKey)
                            as? (UIButton, JobsTimerKind) -> Void {
                            fin(self, k)
                        }
                        if let legacyFin = objc_getAssociatedObject(self, &_legacyCountdownFinishKey) as? jobsByVoidBlock {
                            legacyFin()
                        }
                        self.stopTimer()
                        self.isEnabled = true
                        self.setTitle("重新获取".tr, for: .normal)
                    }
                }
            }
        }
        self.timer = core
        self.timerState = .running
        core.start()
        return self
    }

    @discardableResult
    public func pauseTimer() -> Self {
        timer?.pause()
        timerState = .paused
        return self
    }

    @discardableResult
    public func resumeTimer() -> Self {
        timer?.resume()
        timerState = .running
        return self
    }
    // MARK: - ✅ fireOnce 适配：新版 protocol 没有 fireOnce()，这里手动“执行一次 tick 语义”
    @discardableResult
    public func fireTimerOnce() -> Self {
        guard let mode0 = objc_getAssociatedObject(self, &_timerModeKey) as? _TimerMode else {
            timerState = .stopped
            return self
        }
        let k = (objc_getAssociatedObject(self, &_timerKindKey) as? JobsTimerKind) ?? .gcd
        onMainAsync(self) { vc in
            var mode = mode0
            switch mode {
            /// 处理 .countUp 分支
            case .countUp(let elapsed0):
                let elapsed = elapsed0 + 1
                mode = .countUp(elapsed: elapsed)
                objc_setAssociatedObject(
                    self,
                    &_timerModeKey,
                    mode,
                    .OBJC_ASSOCIATION_RETAIN_NONATOMIC
                )
                self.setTitle("\(elapsed)", for: .normal)
                if let tick = objc_getAssociatedObject(self, &_timerTickAnyKey)
                    as? (UIButton, Int, Int?, JobsTimerKind) -> Void {
                    tick(self, elapsed, nil, k)
                }
            /// 处理 .countdown 分支
            case .countdown(let remain0, let total):
                let remain = remain0 - 1
                if remain > 0 {
                    mode = .countdown(remain: remain, total: total)
                    objc_setAssociatedObject(
                        self,
                        &_timerModeKey,
                        mode,
                        .OBJC_ASSOCIATION_RETAIN_NONATOMIC
                    )
                    self.setTitle("\(remain)s", for: .normal)
                    if let tick = objc_getAssociatedObject(self, &_timerTickAnyKey)
                        as? (UIButton, Int, Int?, JobsTimerKind) -> Void {
                        tick(self, remain, total, k)
                    }
                    if let legacy = objc_getAssociatedObject(self, &_legacyCountdownTickKey) as? (Int, Int) -> Void {
                        legacy(remain, total)
                    }
                } else {
                    if let fin = objc_getAssociatedObject(self, &_timerFinishAnyKey)
                        as? (UIButton, JobsTimerKind) -> Void {
                        fin(self, k)
                    }
                    if let legacyFin = objc_getAssociatedObject(self, &_legacyCountdownFinishKey) as? jobsByVoidBlock {
                        legacyFin()
                    }
                    self.stopTimer()
                    self.isEnabled = true
                    self.setTitle("重新获取".tr, for: .normal)
                }
            }
            // fireOnce 不改变 timer 的真实运行态；但你原逻辑是标记 stopped
            self.timerState = .stopped
        };return self
    }

    @discardableResult
    public func stopTimer() -> Self {
        let mode = objc_getAssociatedObject(self, &_timerModeKey) as? _TimerMode
        timer?.stop()
        timer = nil
        objc_setAssociatedObject(
            self,
            &_timerModeKey,
            nil,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
        timerState = .stopped
        if mode?.isCountdown == true {
            isEnabled = true
            setTitle("重新获取".tr, for: .normal)
        };return self
    }
}
// MARK: - Convenience API（保持你原对外接口不变）
extension UIButton {
    @discardableResult
    public func startJobsTimer(total: Int? = nil,
                               interval: TimeInterval = 1.0,
                               kind: JobsTimerKind = .gcd) -> Self {
        startTimer(total: total, interval: interval, kind: kind)
    }

    @discardableResult
    public func pauseJobsTimer() -> Self { pauseTimer() }

    @discardableResult
    public func resumeJobsTimer() -> Self { resumeTimer() }

    @discardableResult
    public func fireJobsTimerOnce() -> Self { fireTimerOnce() }

    @discardableResult
    public func stopJobsTimer() -> Self { stopTimer() }

    @discardableResult
    public func startJobsCountdown(total: Int,
                                   interval: TimeInterval = 1.0,
                                   kind: JobsTimerKind = .gcd) -> Self {
        startTimer(total: total, interval: interval, kind: kind)
    }

    @discardableResult
    public func stopJobsCountdown(triggerFinish: Bool = false) -> Self {
        if triggerFinish {
            if let k = objc_getAssociatedObject(self, &_timerKindKey) as? JobsTimerKind,
               let fin = objc_getAssociatedObject(self, &_timerFinishAnyKey) as? (UIButton, JobsTimerKind) -> Void {
                fin(self, k)
            }
            if let legacyFin = objc_getAssociatedObject(self, &_legacyCountdownFinishKey) as? jobsByVoidBlock {
                legacyFin()
            }
        };return stopTimer()
    }

    @discardableResult
    public func onJobsCountdownTick(_ block: @escaping (_ remain: Int, _ total: Int) -> Void) -> Self {
        objc_setAssociatedObject(
            self,
            &_legacyCountdownTickKey,
            block,
            .OBJC_ASSOCIATION_COPY_NONATOMIC
        );return self
    }

    @discardableResult
    public func onJobsCountdownFinish(_ block: @escaping jobsByVoidBlock) -> Self {
        objc_setAssociatedObject(
            self,
            &_legacyCountdownFinishKey,
            block,
                .OBJC_ASSOCIATION_COPY_NONATOMIC
        );return self
    }
}
