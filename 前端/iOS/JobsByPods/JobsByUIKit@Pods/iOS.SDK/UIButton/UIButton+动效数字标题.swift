//
//  UIButton+动效数字标题.swift
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
import QuartzCore
import JobsSwiftTimer
import JobsSwiftDSL
import JobsSwiftBaseDefines

/**
 
     - 一个 API 配完主/副标题动画 + 金融格式（分隔/小数/样式）
     - 动画未结束不允许再次 start（倒计时禁止重入）
     - 修复开启 decimals 后“无动画/无标题”问题：Attributed 需补齐整段 font/color
     - 修复点击高亮/选中时标题丢失：Title/Attributed 同步写入常见状态（legacy）
     - ✅ 写入统一走 DSL：byTitle/bySubTitle（Configuration/Legacy 由 DSL 接管）
     - ✅ byStartAnim 回调 model：主标题/副标题/当前秒数（elapsedSeconds）
     - ✅ 支持主/副标题"整体富文本 Builder" ➤ 比如：¥ + 数字 + /月；整数/小数不同字体颜色；前后缀不变只动数字
 */
// MARK: - Tick Model
public struct JobsButtonNumberAnimTickModel {
    public let title: String?
    public let subTitle: String?
    /// 当前秒数（已过去 elapsedSeconds）
    public let seconds: Double
    public init(title: String?, subTitle: String?, seconds: Double) {
        self.title = title
        self.subTitle = subTitle
        self.seconds = seconds
    }
}
// MARK: - Associated Keys
private var _jobsAnimTitleCfgKey: UInt8 = 0
private var _jobsAnimSubTitleCfgKey: UInt8 = 0
private var _jobsAnimTitleRunnerKey: UInt8 = 0
private var _jobsAnimSubTitleRunnerKey: UInt8 = 0
// tick 回调（每帧一次）
private var _jobsAnimTickVoidKey: UInt8 = 0
private var _jobsAnimTickValueKey: UInt8 = 0
private var _jobsAnimTickModelKey: UInt8 = 0
private var _jobsAnimTickGateKey: UInt8 = 0
// tick 最新值缓存（来自 runner 的“已变化值”）
private var _jobsAnimLatestTitleKey: UInt8 = 0
private var _jobsAnimLatestSubTitleKey: UInt8 = 0
private var _jobsAnimLatestSecondsKey: UInt8 = 0
// end 回调（全部结束）
private var _jobsAnimEndKey: UInt8 = 0
// MARK: - Public API
extension UIButton {
    // MARK: Config Entry
    /// 主标题数字动效配置
    @discardableResult
    public func byAnimationTitleConfig(_ block: (JobsButtonNumberAnimConfig.Title) -> Void) -> Self {
        let cfg = JobsButtonNumberAnimConfig.Title(button: self)
        block(cfg)
        objc_setAssociatedObject(
            self,
            &_jobsAnimTitleCfgKey,
            cfg.snapshot,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        );return self
    }
    /// 副标题数字动效配置
    @discardableResult
    public func byAnimationSubTitleConfig(_ block: (JobsButtonNumberAnimConfig.SubTitle) -> Void) -> Self {
        let cfg = JobsButtonNumberAnimConfig.SubTitle(button: self)
        block(cfg)
        objc_setAssociatedObject(
            self,
            &_jobsAnimSubTitleCfgKey,
            cfg.snapshot,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        );return self
    }
    // MARK: Start / End Hook
    /// ✅ 每次 tick 回调一次（无参）
    @discardableResult
    public func byStartAnim(_ onTick: (() -> Void)? = nil) -> Self {
        if let onTick {
            objc_setAssociatedObject(
                self,
                &_jobsAnimTickVoidKey,
                onTick,
                .OBJC_ASSOCIATION_COPY_NONATOMIC
            )
        };return _jobsStartAnimIfNeeded()
    }
    /// ✅ 每次 tick 回调“已变化后的 title/subTitle”
    @discardableResult
    public func byStartAnim(_ onTick: ((String?, String?) -> Void)?) -> Self {
        if let onTick {
            objc_setAssociatedObject(
                self,
                &_jobsAnimTickValueKey,
                onTick,
                .OBJC_ASSOCIATION_COPY_NONATOMIC
            )
        };return _jobsStartAnimIfNeeded()
    }
    /// ✅ 每次 tick 回调一个 model（title/subTitle/seconds）
    @discardableResult
    public func byStartAnim(_ onTick: ((JobsButtonNumberAnimTickModel) -> Void)?) -> Self {
        if let onTick {
            objc_setAssociatedObject(
                self,
                &_jobsAnimTickModelKey,
                onTick,
                .OBJC_ASSOCIATION_COPY_NONATOMIC
            )
        };return _jobsStartAnimIfNeeded()
    }
    /// 绑定结束回调（全部结束时触发一次）
    @discardableResult
    public func byEndAnim(_ end: (() -> Void)? = nil) -> Self {
        if let end {
            objc_setAssociatedObject(
                self,
                &_jobsAnimEndKey,
                end,
                .OBJC_ASSOCIATION_COPY_NONATOMIC
            )
        };return self
    }
    // MARK: Manual Stop (可选)
    @discardableResult
    public func byStopAnim() -> Self {
        _jobsStopTitleAnim()
        _jobsStopSubTitleAnim()
        return self
    }
}
// MARK: - Internals
extension UIButton {
    fileprivate func _jobsStartAnimIfNeeded() -> Self {
        // ✅ 倒计时过程中禁止重入
        if let r1 = objc_getAssociatedObject(self, &_jobsAnimTitleRunnerKey) as? JobsButtonNumberAnimRunner,
           r1.isFinished == false {
            return self
        }
        if let r2 = objc_getAssociatedObject(self, &_jobsAnimSubTitleRunnerKey) as? JobsButtonNumberAnimRunner,
           r2.isFinished == false {
            return self
        }
        // 清空上一轮缓存
        objc_setAssociatedObject(
            self,
            &_jobsAnimLatestTitleKey,
            nil,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
        objc_setAssociatedObject(
            self,
            &_jobsAnimLatestSubTitleKey,
            nil,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
        objc_setAssociatedObject(
            self,
            &_jobsAnimLatestSecondsKey,
            NSNumber(value: 0.0),
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
        // 先停掉旧的
        _jobsStopTitleAnim()
        _jobsStopSubTitleAnim()
        // 主标题 runner
        if let cfg = objc_getAssociatedObject(self, &_jobsAnimTitleCfgKey) as? JobsButtonNumberAnimConfig.Snapshot {
            let runner = JobsButtonNumberAnimRunner(
                button: self,
                snapshot: cfg,
                kind: .title,
                onTick: { [weak self] now, elapsed, kind, text in
                    self?._jobsReceiveTickValue(now: now, elapsed: elapsed, kind: kind, text: text)
                },
                onFinish: { [weak self] in
                    self?._jobsTryFireEndIfAllFinished()
                }
            )
            objc_setAssociatedObject(
                self,
                &_jobsAnimTitleRunnerKey,
                runner,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            );runner.start()
        }
        // 副标题 runner
        if let cfg = objc_getAssociatedObject(self, &_jobsAnimSubTitleCfgKey) as? JobsButtonNumberAnimConfig.Snapshot {
            let runner = JobsButtonNumberAnimRunner(
                button: self,
                snapshot: cfg,
                kind: .subTitle,
                onTick: { [weak self] now, elapsed, kind, text in
                    self?._jobsReceiveTickValue(now: now, elapsed: elapsed, kind: kind, text: text)
                },
                onFinish: { [weak self] in
                    self?._jobsTryFireEndIfAllFinished()
                }
            )
            objc_setAssociatedObject(
                self,
                &_jobsAnimSubTitleRunnerKey,
                runner,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            );runner.start()
        };return self
    }

    private func _jobsStopTitleAnim() {
        if let r = objc_getAssociatedObject(self, &_jobsAnimTitleRunnerKey) as? JobsButtonNumberAnimRunner {
            r.stop()
        }
        objc_setAssociatedObject(
            self,
            &_jobsAnimTitleRunnerKey,
            nil,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
    }

    private func _jobsStopSubTitleAnim() {
        if let r = objc_getAssociatedObject(self, &_jobsAnimSubTitleRunnerKey) as? JobsButtonNumberAnimRunner {
            r.stop()
        }
        objc_setAssociatedObject(
            self,
            &_jobsAnimSubTitleRunnerKey,
            nil,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
    }
    /// ✅ 接收 runner “已变化值”，并按帧 gate 回调给业务层
    fileprivate func _jobsReceiveTickValue(now: CFTimeInterval,
                                          elapsed: Double,
                                          kind: JobsButtonNumberAnimRunner.Kind,
                                          text: String) {
        // 缓存最新文本
        switch kind {
        /// 处理 .title 分支
        case .title:
            objc_setAssociatedObject(
                self,
                &_jobsAnimLatestTitleKey,
                text,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
        /// 处理 .subTitle 分支
        case .subTitle:
            objc_setAssociatedObject(
                self,
                &_jobsAnimLatestSubTitleKey,
                text,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
        }
        // 缓存秒数：主副同时跑时，取更大的 elapsed
        let old = (objc_getAssociatedObject(self, &_jobsAnimLatestSecondsKey) as? NSNumber)?.doubleValue ?? 0
        if elapsed >= old {
            objc_setAssociatedObject(
                self,
                &_jobsAnimLatestSecondsKey,
                NSNumber(value: elapsed),
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
        }
        _jobsFireTickOncePerFrame(now: now)
    }
    /// ✅ tick 回调：同一帧最多触发一次（主/副同时跑不重复）
    fileprivate func _jobsFireTickOncePerFrame(now: CFTimeInterval) {
        let gate = (objc_getAssociatedObject(self, &_jobsAnimTickGateKey) as? NSNumber)?.doubleValue ?? 0
        if gate > 0, (now - gate) < (1.0 / 120.0) { return }
        objc_setAssociatedObject(
            self,
            &_jobsAnimTickGateKey,
            NSNumber(value: now),
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
        if let tick0 = objc_getAssociatedObject(self, &_jobsAnimTickVoidKey) as? (() -> Void) {
            tick0()
        }
        let t = objc_getAssociatedObject(self, &_jobsAnimLatestTitleKey) as? String
        let s = objc_getAssociatedObject(self, &_jobsAnimLatestSubTitleKey) as? String
        let sec = (objc_getAssociatedObject(self, &_jobsAnimLatestSecondsKey) as? NSNumber)?.doubleValue ?? 0
        if let tick1 = objc_getAssociatedObject(self, &_jobsAnimTickValueKey) as? ((String?, String?) -> Void) {
            tick1(t, s)
        }
        if let tick2 = objc_getAssociatedObject(self, &_jobsAnimTickModelKey) as? ((JobsButtonNumberAnimTickModel) -> Void) {
            tick2(JobsButtonNumberAnimTickModel(title: t, subTitle: s, seconds: sec))
        }
    }
    /// 主/副都结束后，只触发一次 end
    fileprivate func _jobsTryFireEndIfAllFinished() {
        let titleRunner = objc_getAssociatedObject(self, &_jobsAnimTitleRunnerKey) as? JobsButtonNumberAnimRunner
        let subRunner = objc_getAssociatedObject(self, &_jobsAnimSubTitleRunnerKey) as? JobsButtonNumberAnimRunner
        let titleDone = (titleRunner == nil) || (titleRunner?.isFinished == true)
        let subDone = (subRunner == nil) || (subRunner?.isFinished == true)
        guard titleDone, subDone else { return }
        objc_setAssociatedObject(
            self,
            &_jobsAnimTitleRunnerKey,
            nil,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
        objc_setAssociatedObject(
            self,
            &_jobsAnimSubTitleRunnerKey,
            nil,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
        if let end = objc_getAssociatedObject(self, &_jobsAnimEndKey) as? (() -> Void) {
            end()
        }
    }
}
// MARK: - Config
public enum JobsButtonNumberAnimConfig {
    public enum Grouping: Int { case international3 = 3; case china4 = 4 }
    /// ✅ 整体富文本 Builder
    /// - text: 例如 "1,234.56"
    /// - decimalsRange: 小数部分 range（在 text 内），可能为 nil
    /// - value: 当前数值
    public typealias AttributedBuilder = (_ text: String,
                                          _ decimalsRange: NSRange?,
                                          _ value: Double) -> NSAttributedString
    public final class DecimalsSnapshot: NSObject {
        public var showsDecimals: Bool = false
        public var decimals: Int = 2
        public var separator: String = ","
        public var grouping: Grouping = .international3
        public var decimalsFont: UIFont?
        public var decimalsColor: UIColor?
    }

    public final class Snapshot: NSObject {
        public var duration: TimeInterval = 1.0
        public var fps: Int = 60
        public var startValue: String?
        public var endValue: String?
        public var fallbackEndValue: String?
        public var decimalsCfg: DecimalsSnapshot = .init()
        public var titleFont: UIFont?
        public var titleColorNormal: UIColor?
        public var titleColorDisabled: UIColor?
        public var subTitleFont: UIFont?
        public var subTitleColorNormal: UIColor?
        public var subTitleColorSelected: UIColor?
        /// ✅ 主/副标题整体富文本
        public var titleAttributedBuilder: AttributedBuilder?
        public var subTitleAttributedBuilder: AttributedBuilder?
    }

    public final class Title {
        fileprivate weak var button: UIButton?
        fileprivate let snapshot = Snapshot()
        fileprivate init(button: UIButton) { self.button = button }
        @discardableResult public func byDuration(_ v: TimeInterval) -> Self {
            snapshot.duration = max(0, v)
            return self
        }
        @discardableResult public func byFps(_ v: Int) -> Self {
            snapshot.fps = max(1, v)
            return self
        }
        @discardableResult public func byStartValue(_ v: String?) -> Self {
            snapshot.startValue = v
            return self
        }
        @discardableResult public func byEndValue(_ v: String?) -> Self {
            snapshot.endValue = v
            return self
        }
        @discardableResult public func byFallbackEndValue(_ v: String?) -> Self {
            snapshot.fallbackEndValue = v
            return self
        }
        @discardableResult
        public func byTitleFont(_ font: UIFont?) -> Self {
            snapshot.titleFont = font
            button?.byTitleFont(font)
            return self
        }
        @discardableResult
        public func byTitleColor(_ color: UIColor?, for state: UIControl.State = .normal) -> Self {
            if state == .normal { snapshot.titleColorNormal = color }
            if state == .disabled { snapshot.titleColorDisabled = color }
            button?.byTitleColor(color, for: state)
            return self
        }
        @discardableResult public func byShowsDecimals(_ v: Bool) -> Self {
            snapshot.decimalsCfg.showsDecimals = v
            return self
        }
        @discardableResult public func bySeparate(_ v: String?) -> Self {
            snapshot.decimalsCfg.separator = (v ?? "").isEmpty ? "," : v!
            return self
        }
        @discardableResult public func byGrouping(_ v: Grouping) -> Self {
            snapshot.decimalsCfg.grouping = v
            return self
        }
        @discardableResult public func byDecimals(_ v: Int) -> Self {
            snapshot.decimalsCfg.decimals = max(0, v)
            return self
        }
        @discardableResult public func byTitleDecimalsCor(_ v: UIColor?) -> Self {
            snapshot.decimalsCfg.decimalsColor = v
            return self
        }
        @discardableResult public func byTitleDecimalsFont(_ v: UIFont?) -> Self {
            snapshot.decimalsCfg.decimalsFont = v
            return self
        }
        /// ✅ 主标题整体富文本 Builder
        @discardableResult
        public func byTitleAttributedBuilder(_ builder: AttributedBuilder?) -> Self {
            snapshot.titleAttributedBuilder = builder
            return self
        }
    }

    public final class SubTitle {
        fileprivate weak var button: UIButton?
        fileprivate let snapshot = Snapshot()
        fileprivate init(button: UIButton) { self.button = button }
        @discardableResult public func byDuration(_ v: TimeInterval) -> Self {
            snapshot.duration = max(0, v)
            return self
        }
        @discardableResult public func byFps(_ v: Int) -> Self {
            snapshot.fps = max(1, v)
            return self
        }
        @discardableResult public func byStartValue(_ v: String?) -> Self {
            snapshot.startValue = v
            return self
        }
        @discardableResult public func byEndValue(_ v: String?) -> Self {
            snapshot.endValue = v
            return self
        }
        @discardableResult public func byFallbackEndValue(_ v: String?) -> Self {
            snapshot.fallbackEndValue = v
            return self
        }
        @discardableResult
        public func bySubTitleFont(_ font: UIFont?) -> Self {
            snapshot.subTitleFont = font
            button?.bySubTitleFont(font)
            return self
        }
        @discardableResult
        public func bySubTitleColor(_ color: UIColor?, for state: UIControl.State = .normal) -> Self {
            if state == .normal { snapshot.subTitleColorNormal = color }
            if state == .selected { snapshot.subTitleColorSelected = color }
            button?.bySubTitleColor(color, for: state)
            return self
        }
        @discardableResult
        public func byShowsDecimals(_ v: Bool) -> Self {
            snapshot.decimalsCfg.showsDecimals = v
            return self
        }
        @discardableResult
        public func bySeparate(_ v: String?) -> Self {
            snapshot.decimalsCfg.separator = (v ?? "").isEmpty ? "," : v!
            return self
        }
        @discardableResult
        public func byGrouping(_ v: Grouping) -> Self {
            snapshot.decimalsCfg.grouping = v
            return self
        }
        @discardableResult
        public func byDecimals(_ v: Int) -> Self {
            snapshot.decimalsCfg.decimals = max(0, v)
            return self
        }
        @discardableResult
        public func bySubTitleDecimalsCor(_ v: UIColor?) -> Self {
            snapshot.decimalsCfg.decimalsColor = v
            return self
        }
        @discardableResult
        public func bySubTitleDecimalsFont(_ v: UIFont?) -> Self {
            snapshot.decimalsCfg.decimalsFont = v
            return self
        }
        /// ✅ 副标题整体富文本 Builder
        @discardableResult
        public func bySubTitleAttributedBuilder(_ builder: AttributedBuilder?) -> Self {
            snapshot.subTitleAttributedBuilder = builder
            return self
        }
    }
}
// MARK: - Runner
private final class JobsButtonNumberAnimRunner: NSObject {
    enum Kind { case title, subTitle }

    private weak var button: UIButton?
    private let snapshot: JobsButtonNumberAnimConfig.Snapshot
    private let kind: Kind
    /// now, elapsedSeconds, kind, text
    private let onTick: (CFTimeInterval, Double, Kind, String) -> Void
    private let onFinish: () -> Void

    private var timer: JobsTimer?
    private var lastGateTime: CFTimeInterval = 0
    private var startTime: CFTimeInterval = 0

    private var fromValue: Double = 0
    private var toValue: Double = 0

    private(set) var isFinished: Bool = false

    init(button: UIButton,
         snapshot: JobsButtonNumberAnimConfig.Snapshot,
         kind: Kind,
         onTick: @escaping (CFTimeInterval, Double, Kind, String) -> Void,
         onFinish: @escaping () -> Void) {
        self.button = button
        self.snapshot = snapshot
        self.kind = kind
        self.onTick = onTick
        self.onFinish = onFinish
        super.init()
    }

    func start() {
        guard let button else { finish(); return }
        resolveValuesIfNeeded(button: button)
        let now = CACurrentMediaTime()
        startTime = now
        let text = applyNumber(button: button, value: fromValue)
        onTick(now, 0.0, kind, text)
        guard snapshot.duration > 0 else {
            let endText = applyNumber(button: button, value: toValue)
            onTick(CACurrentMediaTime(), 0.0, kind, endText)
            finish()
            return
        }
        lastGateTime = 0
        timer = JobsTimer(kind: .displayLink,
                          config: JobsSwiftTimerConfig(
                            interval: 1.0 / 60.0,
                            repeats: true,
                            tolerance: 0,
                            queue: .main,
                            runLoop: .main,
                            runLoopMode: .common,
                            pauseInBackground: true,
                            autoManageAppState: true
                          ))
        { [weak self] in
            guard let self else { return }
            self.tick()
        }.start()
    }

    func stop() {
        timer?.stop()
        timer = nil
        isFinished = true
    }

    private func tick() {
        guard let button else { finish(); return }
        if isFinished { return }
        let now = CACurrentMediaTime()
        let gateInterval = 1.0 / Double(max(1, snapshot.fps))
        if lastGateTime == 0 { lastGateTime = now }
        if now - lastGateTime < gateInterval { return }
        lastGateTime = now
        let elapsed = now - startTime
        let p = min(1.0, max(0.0, elapsed / snapshot.duration))
        let v = fromValue + (toValue - fromValue) * p
        let text = applyNumber(button: button, value: v)
        onTick(now, elapsed, kind, text)
        if p >= 1.0 { finish() }
    }

    private func finish() {
        if isFinished { return }
        isFinished = true
        timer?.stop()
        timer = nil
        onFinish()
    }

    private func resolveValuesIfNeeded(button: UIButton) {
        func nonEmpty(_ s: String?) -> String? {
            guard let s else { return nil }
            let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
            return t.isEmpty ? nil : t
        }
        let rawStart: String = nonEmpty(snapshot.startValue)
        ?? nonEmpty(currentText(button: button))
        ?? "0"
        let rawEnd: String = nonEmpty(snapshot.endValue)
        ?? nonEmpty(currentText(button: button))
        ?? nonEmpty(snapshot.fallbackEndValue)
        ?? rawStart
        let sep = snapshot.decimalsCfg.separator.isEmpty ? "," : snapshot.decimalsCfg.separator
        fromValue = Self.parseDouble(rawStart, separator: sep) ?? 0
        toValue   = Self.parseDouble(rawEnd,   separator: sep) ?? fromValue
    }

    private func currentText(button: UIButton) -> String? {
        switch kind {
        /// 处理 .title 分支
        case .title: return button.title
        /// 处理 .subTitle 分支
        case .subTitle: return button.subTitle
        }
    }

    private func titleBaseFont(button: UIButton) -> UIFont {
        snapshot.titleFont ?? (button.titleLabel?.font ?? JobsFont.systemFont(ofSize: 14))
    }

    private func titleBaseColor(button: UIButton) -> UIColor {
        snapshot.titleColorNormal ?? button.titleColor(for: .normal) ?? JobsCor.label
    }

    private func subTitleBaseFont(button: UIButton) -> UIFont {
        snapshot.subTitleFont ?? (Self.findSubTitleLabel(from: button)?.font ?? JobsFont.systemFont(ofSize: 14))
    }

    private func subTitleBaseColor(button: UIButton) -> UIColor {
        if button.isSelected, let c = snapshot.subTitleColorSelected { return c };return snapshot.subTitleColorNormal
        ?? Self.findSubTitleLabel(from: button)?.textColor
        ?? JobsCor.label
    }
    /// ✅ 写入统一走 DSL（plain），富文本：支持 Builder；未配置 Builder 时继续支持“小数 range 样式”
    @discardableResult
    private func applyNumber(button: UIButton, value: Double) -> String {
        let ds = snapshot.decimalsCfg
        let formatted = JobsNumberFormatter.format(
            value: value,
            showsDecimals: ds.showsDecimals,
            decimals: ds.decimals,
            separator: ds.separator,
            groupingSize: ds.grouping.rawValue
        )
        // 1) 先写 plain（保持你原有 DSL 行为）
        switch kind {
        /// 处理 .title 分支
        case .title:
            button
                .byTitle(formatted.text, for: .normal)
                .byTitle(formatted.text, for: .selected)
                .byTitle(formatted.text, for: .highlighted)
                .byTitle(formatted.text, for: .disabled)
        /// 处理 .subTitle 分支
        case .subTitle:
            button
                .bySubTitle(formatted.text, for: .normal)
                .bySubTitle(formatted.text, for: .selected)
                .bySubTitle(formatted.text, for: .highlighted)
                .bySubTitle(formatted.text, for: .disabled)
        }
        // 2) 如果配置了整体富文本 Builder：优先使用（避免和 decimals 样式互相覆盖）
        if let attr = buildAttributedIfNeeded(text: formatted.text,
                                             decimalsRange: formatted.decimalsRange,
                                             value: value) {
            writeAttributed(button: button,
                            attributed: attr,
                            plain: formatted.text)
            return formatted.text
        }
        // 3) 否则：走你原来的“小数 range 上样式”
        if ds.showsDecimals,
           ds.decimals > 0,
           (ds.decimalsFont != nil || ds.decimalsColor != nil),
           let decRange = formatted.decimalsRange {
            let attr = NSMutableAttributedString(string: formatted.text)
            let baseFont: UIFont
            let baseColor: UIColor
            switch kind {
            /// 处理 .title 分支
            case .title:
                baseFont = titleBaseFont(button: button)
                baseColor = titleBaseColor(button: button)
            /// 处理 .subTitle 分支
            case .subTitle:
                baseFont = subTitleBaseFont(button: button)
                baseColor = subTitleBaseColor(button: button)
            }
            // ✅ 必须整段补齐 font/color（你注释里提到的“无标题/无动画”根源之一就是这里没补齐）
            attr.addAttribute(.font,
                              value: baseFont,
                              range: NSRange(location: 0, length: attr.length))
            attr.addAttribute(.foregroundColor,
                              value: baseColor,
                              range: NSRange(location: 0, length: attr.length))
            if let f = ds.decimalsFont { attr.addAttribute(.font,
                                                           value: f,
                                                           range: decRange) }
            if let c = ds.decimalsColor { attr.addAttribute(.foregroundColor,
                                                            value: c,
                                                            range: decRange) }
            writeAttributed(button: button,
                            attributed: attr,
                            plain: formatted.text)
        };return formatted.text
    }

    private func buildAttributedIfNeeded(text: String,
                                         decimalsRange: NSRange?,
                                         value: Double) -> NSAttributedString? {
        switch kind {
        /// 处理 .title 分支
        case .title:
            return snapshot.titleAttributedBuilder?(text, decimalsRange, value)
        /// 处理 .subTitle 分支
        case .subTitle:
            return snapshot.subTitleAttributedBuilder?(text, decimalsRange, value)
        }
    }
    /// 统一写入 attributed：主标题 legacy 多状态 + iOS15 configuration；副标题走 byAttributedSubTitle 多状态
    private func writeAttributed(button: UIButton, attributed: NSAttributedString, plain: String) {
        switch kind {
        /// 处理 .title 分支
        case .title:
            button
                .byAttributedTitle(attributed, for: .normal)
                .byAttributedTitle(attributed, for: .selected)
                .byAttributedTitle(attributed, for: .highlighted)
                .byAttributedTitle(attributed, for: .disabled)
            if #available(iOS 15.0, *) {
                if var cfg = button.configuration {
                    cfg.title = plain
                    cfg.attributedTitle = AttributedString(attributed)
                    button.byConfiguration(cfg)
                }
            }
        /// 处理 .subTitle 分支
        case .subTitle:
            // ✅ 关键：副标题富文本走你 Subtitle 扩展的 byAttributedSubTitle（iOS15+ 会写 attributedSubtitle，iOS15- 会 legacy 合成）
            button
                .byAttributedSubTitle(attributed, for: .normal)
                .byAttributedSubTitle(attributed, for: .selected)
                .byAttributedSubTitle(attributed, for: .highlighted)
                .byAttributedSubTitle(attributed, for: .disabled)
        }
    }

    private static func parseDouble(_ s: String?, separator: String) -> Double? {
        guard let s else { return nil }
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.isEmpty { return nil }
        let sep = separator.isEmpty ? "," : separator
        let cleaned = t.replacingOccurrences(of: sep, with: "")
        return Double(cleaned)
    }

    static func findSubTitleLabel(from button: UIButton) -> UILabel? {
        if let v = button.value(forKey: "subTitleLab") as? UILabel { return v }
        if let v = button.value(forKey: "subTitleLabel") as? UILabel { return v }
        if let v = button.value(forKey: "subtitleLabel") as? UILabel { return v }
        if #available(iOS 15.0, *), let v = button.subtitleLabel { return v };return nil
    }
}
// MARK: - Formatter
private enum JobsNumberFormatter {
    struct Result {
        let text: String
        let decimalsRange: NSRange?
    }

    static func format(value: Double,
                       showsDecimals: Bool,
                       decimals: Int,
                       separator: String,
                       groupingSize: Int) -> Result {
        let sep = separator.isEmpty ? "," : separator
        let g = max(1, groupingSize)
        let fixedDecimals = max(0, decimals)
        let rounded = roundToDecimals(value, fixedDecimals)
        let isNeg = rounded < 0
        let absV = abs(rounded)
        if showsDecimals && fixedDecimals > 0 {
            let base = toFixedString(absV, fixedDecimals)
            let parts = base.split(separator: ".", omittingEmptySubsequences: false)
            let intPart = String(parts.first ?? "0")
            let decPart = String(parts.count > 1 ? parts[1] : "")
            let groupedInt = groupDigits(intPart, groupSize: g, separator: sep)
            let full = (isNeg ? "-" : "") + groupedInt + "." + decPart
            let dotIndex = (isNeg ? 1 : 0) + groupedInt.count
            let start = dotIndex + 1
            let ns = NSRange(location: start, length: decPart.count)
            return Result(text: full, decimalsRange: ns)
        } else {
            let intString = String(Int(absV.rounded(.towardZero)))
            let groupedInt = groupDigits(intString, groupSize: g, separator: sep)
            let full = (isNeg ? "-" : "") + groupedInt
            return Result(text: full, decimalsRange: nil)
        }
    }

    private static func roundToDecimals(_ v: Double, _ decimals: Int) -> Double {
        guard decimals > 0 else { return v.rounded() }
        let p = pow(10.0, Double(decimals))
        return (v * p).rounded() / p
    }

    private static func toFixedString(_ v: Double, _ decimals: Int) -> String {
        String(format: "%.\(decimals)f", v)
    }

    private static func groupDigits(_ digits: String,
                                    groupSize: Int,
                                    separator: String) -> String {
        let chars = Array(digits)
        if chars.count <= groupSize { return digits }
        var out: [Character] = []
        out.reserveCapacity(chars.count + chars.count / groupSize)
        var countFromRight = 0
        for ch in chars.reversed() {
            if countFromRight > 0, countFromRight % groupSize == 0 {
                for s in separator.reversed() { out.append(s) }
            }
            out.append(ch)
            countFromRight += 1
        };return String(out.reversed())
    }
}
