//
//  JobsSwiftTimerConfig.swift
//  JobsSwiftTimer
//
//  Created by Jobs on 2026年5月13日，星期三.
//

#if os(OSX)
import AppKit
#elseif os(iOS) || os(tvOS)
import UIKit
#endif

import ObjectiveC
// MARK: - 配置
public struct JobsSwiftTimerConfig {
    public var interval: TimeInterval    // 时间间隔（最小会被 clamp 到 0.000001）
    public var repeats: Bool             // 是否重复；false 就是 one-shot
    public var tolerance: TimeInterval   // 容忍误差（会被 clamp 到 0...interval；GCD 用 leeway）

    public var queue: DispatchQueue      // 回调实际执行的队列
    public var callbackDeliveryPolicy: JobsTimerCallbackDeliveryPolicy // 重复回调背压策略
    public var runLoop: RunLoop          // 非 GCD 内核用（且必须 `.main`）
    public var runLoopMode: RunLoop.Mode // 非 GCD 内核用；runLoop 必须为 `.main`

    public var pauseInBackground: Bool   // 失去活跃态时是否 pause（UIKit 下有效，沿用兼容命名）
    public var autoManageAppState: Bool  // 是否自动监听前后台（UIKit 下有效）

    public init(
        interval: TimeInterval = 1.0,
        repeats: Bool = true,
        tolerance: TimeInterval = 0,
        queue: DispatchQueue = .main,
        callbackDeliveryPolicy: JobsTimerCallbackDeliveryPolicy = .enqueue,
        runLoop: RunLoop = .main,
        runLoopMode: RunLoop.Mode = .common,
        pauseInBackground: Bool = true,
        autoManageAppState: Bool = true
    ) {
        let normalizedInterval = Self.normalizedInterval(interval)
        self.interval = normalizedInterval
        self.repeats = repeats
        self.tolerance = tolerance.isFinite ? min(max(0, tolerance), normalizedInterval) : 0
        self.queue = queue
        self.callbackDeliveryPolicy = callbackDeliveryPolicy
        self.runLoop = runLoop
        self.runLoopMode = runLoopMode
        self.pauseInBackground = pauseInBackground
        self.autoManageAppState = autoManageAppState
    }
    /// 内核消费前再次规范化，兼容初始化后修改配置的旧调用。
    public var normalized: JobsSwiftTimerConfig {
        JobsSwiftTimerConfig(
            interval: interval,
            repeats: repeats,
            tolerance: tolerance,
            queue: queue,
            callbackDeliveryPolicy: callbackDeliveryPolicy,
            runLoop: runLoop,
            runLoopMode: runLoopMode,
            pauseInBackground: pauseInBackground,
            autoManageAppState: autoManageAppState
        )
    }

    private static func normalizedInterval(_ value: TimeInterval) -> TimeInterval {
        guard value.isFinite else {
            return 1
        }
        // 保证 DispatchTime 的纳秒换算与 now + interval 均处于可表示区间。
        return min(max(0.000_001, value), 1_000_000_000)
    }

}
