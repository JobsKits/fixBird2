//
//  UILabel+动效数字.swift
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
import JobsSwiftTimer
import JobsSwiftDSL

// MARK: - Associated Store
private final class _JobsAnimatedNumberStore {
    // config (只配置，不启动)
    var start: Double?
    var step: Double?
    var duration: TimeInterval = 0.8
    var minimumInterval: TimeInterval = 1.0 / 60.0
    var completion: (() -> Void)?
    // runtime
    var timer: JobsTimer?
    var targetValue: Double = 0
    var currentValue: Double = 0
    var deltaPerTick: Double = 0
    var decimals: Int = 0
    var originalText: String = "0"
}
// MARK: - DSL
extension _JobsAnimatedNumberStore {
    /// DSL: .byTimer { $0.duration = 1 }
    @discardableResult
    func byTimer(_ configure: (_JobsAnimatedNumberStore) -> Void) -> Self {
        configure(self)
        return self
    }
    /// DSL: .byStep(0.5)
    @discardableResult
    func byStep(_ value: Double?) -> Self {
        self.step = value
        return self
    }
    /// DSL: .byStart(0)
    @discardableResult
    func byStart(_ value: Double?) -> Self {
        self.start = value
        return self
    }
    /// DSL: .byDuration(1)
    @discardableResult
    func byDuration(_ value: TimeInterval) -> Self {
        self.duration = value
        return self
    }
    /// DSL: .byFPS(60)
    @discardableResult
    func byFPS(_ fps: Double) -> Self {
        self.minimumInterval = 1.0 / max(0.000_001, fps)
        return self
    }
    /// DSL: .byMinimumInterval(1.0 / 60.0)
    @discardableResult
    func byMinimumInterval(_ value: TimeInterval) -> Self {
        self.minimumInterval = max(0.000_001, value)
        return self
    }
    /// DSL: .byCompletion { }
    @discardableResult
    func byCompletion(_ block: (() -> Void)?) -> Self {
        self.completion = block
        return self
    }
}

private enum _JobsAnimatedNumberAssocKey {
    static var storeKey: UInt8 = 0
}

private extension UILabel {
    var _jobsAnimatedNumberStore: _JobsAnimatedNumberStore {
        if let obj = objc_getAssociatedObject(self, &_JobsAnimatedNumberAssocKey.storeKey) as? _JobsAnimatedNumberStore {
            return obj
        }
        let obj = _JobsAnimatedNumberStore()
        objc_setAssociatedObject(
            self,
            &_JobsAnimatedNumberAssocKey.storeKey,
            obj,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        );return obj
    }
}
// MARK: - Public Chain API
extension UILabel {
    /// ✅ 仅配置（不启动）——链式
    @discardableResult
    public func byAnimatedTextNumber(start: Double? = nil,
                                     step: Double? = nil,
                                     duration: TimeInterval = 0.8,
                                     minimumInterval: TimeInterval = 1.0 / 60.0,
                                     completion: (() -> Void)? = nil) -> UILabel {
        _jobsAnimatedNumberStore
            .byStart(start)
            .byStep(step)
            .byDuration(max(0, duration))
            .byMinimumInterval(minimumInterval)
            .byCompletion(completion)
        return self
    }
    /// ✅ 启动（读取 byAnimatedTextNumber 的配置）——链式
    @discardableResult
    public func byStartAnimatedTextNumber(_ text: String) -> UILabel {
        let s = _jobsAnimatedNumberStore
        // 每次启动先停掉旧的
        _jobsStopAnimatedNumberTimer()
        // 非数字：直接设置文本
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let target = _jobsParseNumber(trimmed) else {
            self.byText(text)
            s.completion?()
            return self
        }
        // 起点
        let from = s.start ?? _jobsParseNumber((self.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
        if from == target {
            // 已经是目标：直接落到原文本（保持格式）
            self.byText(text)
            s.completion?()
            return self
        }
        // decimals：以目标文本的小数位为准
        let decimals = _jobsDecimalPlaces(of: trimmed)
        // interval / ticks
        let interval = max(0.000_001, s.minimumInterval)
        let ticks = max(1, Int((s.duration / interval).rounded(.toNearestOrAwayFromZero)))
        let delta = target - from
        // 每 tick 增量：优先用用户 step，否则自动按 duration 平滑到达
        let perTick: Double
        if let userStep = s.step, userStep != 0 {
            // userStep 表示“每 tick 变化量”，方向由 delta 决定
            let stepAbs = abs(userStep)
            perTick = delta > 0 ? stepAbs : -stepAbs
        } else {
            perTick = delta / Double(ticks)
        }
        // 保存运行态
        s.targetValue = target
        s.currentValue = from
        s.deltaPerTick = perTick
        s.decimals = decimals
        s.originalText = text
        // 先显示起点（更直观）
        self.byText(_jobsFormatNumber(from, decimals: decimals))
        // JobsSwiftTimer 驱动
        let timer = JobsTimer(kind: .foundation,
                              config: JobsSwiftTimerConfig(
                                interval: interval,
                                repeats: true,
                                tolerance: 0,
                                queue: .main,
                                runLoop: .main,
                                runLoopMode: .common,
                                pauseInBackground: true,
                                autoManageAppState: true
                            )) { [weak self] in
                                guard let self else { return }
                                self._jobsTickAnimatedNumber()
                            }
        s.timer = timer.start()
        return self
    }
    /// ✅ 停止 —— 链式
    @discardableResult
    public func byStopAnimatedTextNumber() -> UILabel {
        _jobsStopAnimatedNumberTimer()
        return self
    }
}
// MARK: - Internal Tick / Stop
extension UILabel {
    private func _jobsStopAnimatedNumberTimer() {
        let s = _jobsAnimatedNumberStore
        s.timer?.stop()
        s.timer = nil
    }

    private func _jobsTickAnimatedNumber() {
        let s = _jobsAnimatedNumberStore
        guard s.timer != nil else { return }
        let target = s.targetValue
        var cur = s.currentValue
        let step = s.deltaPerTick
        cur += step
        s.currentValue = cur
        // 到达判定（避免浮点误差）
        let reached: Bool
        if step > 0 {
            reached = cur >= target
        } else {
            reached = cur <= target
        }
        if reached {
            // 结束：落到原始文本（保持用户传入的格式）
            self.byText(s.originalText)
            _jobsStopAnimatedNumberTimer()
            s.completion?()
            return
        }
        // 中间帧：按 decimals 格式化显示
        self.byText(_jobsFormatNumber(cur, decimals: s.decimals))
    }
}
// MARK: - Helpers
extension UILabel {
    /// 解析数字：支持 -123 / 123.45 / +12.3
    private func _jobsParseNumber(_ str: String) -> Double? {
        // Double() 本身已经支持正负号与小数点；不支持千分位逗号
        // 如果你需要 "1,234.56" 这种格式，再加 NumberFormatter 即可
        return Double(str)
    }
    /// 以目标文本的小数位决定展示小数位
    private func _jobsDecimalPlaces(of str: String) -> Int {
        guard let dotRange = str.range(of: ".") else { return 0 }
        let fraction = str[dotRange.upperBound...]
        // 过滤掉可能的尾部空格
        let digits = fraction.prefix { $0.isNumber };return digits.count
    }

    private func _jobsFormatNumber(_ value: Double, decimals: Int) -> String {
        if decimals <= 0 {
            return "\(Int(value.rounded()))"
        } else {
            return String(format: "%.\(decimals)f", value)
        }
    }
}
