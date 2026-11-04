//
//  JobsSwiftTimerDefs.swift
//  JobsSwiftTimer
//
//  Created by Jobs on 2026年5月13日，星期三.
//

#if canImport(UIKit)
import UIKit
#endif

public enum JobsOpenResult {
    case opened                 // 成功触发了系统打开
    case cannotOpen             // 系统认为不能打开（未安装/被限制）
    case invalidInput           // 入参不是一个有效的 URL/电话
}

public enum TimerState: Int, Sendable {
    case idle
    case running
    case paused
    case stopped
}

public enum _TimerMode: Sendable {
    case countUp(elapsed: Int)
    case countdown(remain: Int, total: Int)

    public var isCountdown: Bool {
        if case .countdown = self { return true };return false
    }
}
// MARK: - Timer Kind
public enum JobsTimerKind: Sendable {
    case gcd          // 不依赖 RunLoop，不强制主线程、回调在 `config.queue` 上执行、适合后台任务、非 UI、精准调度
    case foundation
    case displayLink
    case runLoop
}
// MARK: - Callback Delivery
/// 重复计时器的回调投递策略。
public enum JobsTimerCallbackDeliveryPolicy: Sendable, Equatable {
    /// 保留每一次有效 tick；兼容既有行为。
    case enqueue
    /// 上一次回调尚未结束时丢弃新 tick，适合只关心实时状态的场景。
    case dropIfBusy
    /// 上一次回调尚未结束时只保留最新 tick，避免回调队列持续堆积。
    case coalesceLatest
}
/// JobsTimer 专用回调类型：可跨并发域安全传递
public typealias JobsTimerCallback = @Sendable () -> Void
public typealias jobsByOpenResultBlock = (JobsOpenResult) -> Void
#if canImport(UIKit)
public typealias TimerStateChangeHandler = (_ button: UIButton,
                                            _ old: TimerState,
                                            _ new: TimerState) -> Void
#endif

public extension JobsTimerKind {
    var displayName: String {
        switch self {
        /// 处理 .gcd 分支
        case .gcd:          return "GCD"
        /// 处理 .foundation 分支
        case .foundation:   return "NSTimer"
        /// 处理 .displayLink 分支
        case .displayLink:  return "DisplayLink"
        /// 处理 .runLoop 分支
        case .runLoop:      return "RunLoop"
        /// 处理系统后续新增的未知枚举值
        @unknown default:   return "Unknown"
        }
    }
}
