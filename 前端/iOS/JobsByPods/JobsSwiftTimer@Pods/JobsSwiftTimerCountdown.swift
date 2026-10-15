//
//  JobsSwiftTimerCountdown.swift
//  JobsSwiftTimer
//
//  Created by Jobs on 2026年5月13日，星期三.
//

import Foundation
/// JobsTimer@系统倒计时进度条
public final class JobsSwiftTimerCountdown: @unchecked Sendable {
    deinit {
        cancel()
    }
    public typealias ProgressHandler = @Sendable (Snapshot) -> Void
    public typealias TimeProvider = @Sendable () -> TimeInterval
    /// 进度模式：0 → 100（正向）或 100 → 0（反向）
    ///
    /// - `countUp`   : 0% 慢慢涨到 100%，适合“进度条”语义
    /// - `countDown` : 100% 慢慢掉到 0%，适合“剩余进度”语义
    public typealias ProgressMode = Snapshot.Mode
    /// 进度快照
    public struct Snapshot: Sendable, Equatable {
        /// 进度模式
        public enum Mode: Sendable, Equatable {
            /// 从 0% 到 100%（elapsed / total）
            case countUp
            /// 从 100% 到 0%（remaining / total）
            case countDown
        }
        /// 总倒计时（秒）
        public let total: TimeInterval
        /// 已经过去的时间（秒）
        public let elapsed: TimeInterval
        /// 剩余时间（秒）
        public var remaining: TimeInterval {
            max(0, total - elapsed)
        }
        /// 0.0 ~ 1.0：已经过去的比例（从 0% → 100%）
        public var elapsedRatio: Double {
            guard total > 0 else { return 1 }
            let ratio = elapsed / total
            return min(1, max(0, ratio))
        }
        /// 0.0 ~ 1.0：剩余比例（从 100% → 0%）
        public var remainingRatio: Double {
            1 - elapsedRatio
        }
        /// 兼容旧 API：等价于 `elapsedRatio`（0 → 1）
        public var progress: Double {
            elapsedRatio
        }
        /// 按给定模式返回进度值
        ///
        /// - `.countUp`   返回 0 → 1（已完成比例）
        /// - `.countDown` 返回 1 → 0（剩余比例）
        public func progress(for mode: Mode) -> Double {
            switch mode {
            /// 处理 .countUp 分支
            case .countUp:
                return elapsedRatio
            /// 处理 .countDown 分支
            case .countDown:
                return remainingRatio
            }
        }
    }
    /// 状态
    public enum State: Sendable, Equatable {
        case idle       // 初始
        case running    // 进行中
        case finished   // 正常完成
        case cancelled  // 手动取消
    }
    // MARK: - Public
    /// 当前状态
    public var state: State {
        withLock { storedState }
    }
    /// 当前快照
    public var snapshot: Snapshot {
        withLock { storedSnapshot }
    }
    /// 进度回调（每次 tick）
    public var onProgress: ProgressHandler? {
        get { withLock { progressHandler } }
        set { withLock { progressHandler = newValue } }
    }
    /// 完成回调（走到 100%）
    public var onFinished: ProgressHandler? {
        get { withLock { finishedHandler } }
        set { withLock { finishedHandler = newValue } }
    }
    /// 所使用的 JobsTimer 内核
    public let kind: JobsTimerKind
    /// tick 间隔（秒），默认 1/60，适合做顺滑动画
    public let tickInterval: TimeInterval
    /// 容差
    public let tolerance: TimeInterval
    /// 回调所在队列（更新 UI 就 .main）
    public let queue: DispatchQueue
    // MARK: - Private
    private let lock = NSRecursiveLock()
    private let total: TimeInterval
    private let timeProvider: TimeProvider
    private var storedState: State = .idle
    private var storedSnapshot: Snapshot
    private var progressHandler: ProgressHandler?
    private var finishedHandler: ProgressHandler?
    private var timer: JobsSwiftTimerProtocol?
    private var startTimestamp: TimeInterval?
    private var generation: UInt64 = 0
    // MARK: - Init
    /// - Parameters:
    ///   - duration: 倒计时总时长（秒）
    ///   - kind: 使用哪种 JobsTimer 内核，默认 DisplayLink
    ///   - tickInterval: tick 间隔，默认 1/60 秒
    ///   - tolerance: 时间容差，默认 0
    ///   - queue: 回调队列，默认 .main
    public init(
        duration: TimeInterval,
        kind: JobsTimerKind = .displayLink,
        tickInterval: TimeInterval = 1.0 / 60.0,
        tolerance: TimeInterval = 0,
        queue: DispatchQueue = .main,
        timeProvider: @escaping TimeProvider = { ProcessInfo.processInfo.systemUptime }
    ) {
        let normalizedTotal = duration.isFinite ? max(0, duration) : 0
        let normalizedTickInterval = tickInterval.isFinite ? max(0.000_001, tickInterval) : 1.0 / 60.0
        let normalizedTolerance = tolerance.isFinite
            ? min(max(0, tolerance), normalizedTickInterval)
            : 0
        self.total = normalizedTotal
        self.storedSnapshot = Snapshot(total: normalizedTotal, elapsed: 0)
        self.kind = kind
        self.tickInterval = normalizedTickInterval
        self.tolerance = normalizedTolerance
        self.queue = queue
        self.timeProvider = timeProvider
    }
    // MARK: - 控制
    /// 开始倒计时（从 0 开始走一次）
    @discardableResult
    public func start() -> JobsSwiftTimerCountdown {
        if kind != .gcd {
            precondition(Thread.isMainThread, "JobsSwiftTimerCountdown: non-GCD start must be called on main thread.")
        }
        var oldTimer: JobsSwiftTimerProtocol?
        var token: UInt64 = 0
        var initialSnapshot = Snapshot(total: total, elapsed: 0)
        var initialProgress: ProgressHandler?
        var immediateFinish: ProgressHandler?
        let shouldCreateTimer = withLock { () -> Bool in
            if storedState == .running { return false }
            oldTimer = timer
            timer = nil
            generation &+= 1
            token = generation
            storedSnapshot = Snapshot(total: total, elapsed: 0)
            initialSnapshot = storedSnapshot
            initialProgress = progressHandler
            startTimestamp = nil
            if total <= 0 {
                storedState = .finished
                immediateFinish = finishedHandler
                return false
            }
            startTimestamp = timeProvider()
            storedState = .running
            return true
        }
        stopTimerSafely(oldTimer)
        guard shouldCreateTimer else {
            initialProgress?(initialSnapshot)
            immediateFinish?(initialSnapshot)
            return self
        }
        let config = JobsSwiftTimerConfig(
            interval: tickInterval,
            repeats: true,
            tolerance: tolerance,
            queue: queue,
            callbackDeliveryPolicy: .coalesceLatest
        )
        let t = JobsTimer(kind: kind, config: config) { [weak self] in
            self?.handleTick(token: token)
        }
        let shouldStartTimer = withLock { () -> Bool in
            guard generation == token, storedState == .running else { return false }
            timer = t
            return true
        }
        guard shouldStartTimer else {
            stopTimerSafely(t)
            return self
        }
        t.start()
        initialProgress?(initialSnapshot)
        return self
    }
    /// 手动取消倒计时（不触发 onFinished）
    public func cancel() {
        let timerToStop = withLock { () -> JobsSwiftTimerProtocol? in
            generation &+= 1
            let timerToStop = timer
            timer = nil
            startTimestamp = nil
            if storedState == .running {
                storedState = .cancelled
            };return timerToStop
        }
        stopTimerSafely(timerToStop)
    }
    /// 重置为初始状态（不自动 start）
    public func reset() {
        cancel()
        withLock {
            storedSnapshot = Snapshot(total: total, elapsed: 0)
            startTimestamp = nil
            storedState = .idle
        }
    }
    // MARK: - Private
    private func handleTick(token: UInt64) {
        var currentSnapshot: Snapshot?
        var progress: ProgressHandler?
        var finished: ProgressHandler?
        var timerToStop: JobsSwiftTimerProtocol?
        withLock {
            guard generation == token,
                  storedState == .running,
                  let startTimestamp else { return }
            let elapsed = max(0, timeProvider() - startTimestamp)
            let clampedElapsed = min(elapsed, total)
            storedSnapshot = Snapshot(total: total, elapsed: clampedElapsed)
            currentSnapshot = storedSnapshot
            progress = progressHandler
            if clampedElapsed >= total {
                generation &+= 1
                storedState = .finished
                self.startTimestamp = nil
                timerToStop = timer
                timer = nil
                finished = finishedHandler
            }
        }
        guard let currentSnapshot else { return }
        progress?(currentSnapshot)
        if let timerToStop {
            stopTimerSafely(timerToStop)
            finished?(currentSnapshot)
        }
    }

    private func stopTimerSafely(_ timer: JobsSwiftTimerProtocol?) {
        guard let timer else { return }
        let stop = { _ = timer.stop() }
        if timer.requiresMainThreadLifecycle, !Thread.isMainThread {
            DispatchQueue.main.sync(execute: stop)
        } else {
            stop()
        }
    }

    @discardableResult
    private func withLock<T>(_ body: () throws -> T) rethrows -> T {
        lock.lock()
        defer { lock.unlock() };return try body()
    }
}
// MARK: - DSL
public extension JobsSwiftTimerCountdown {
    /// 链式设置进度回调
    @discardableResult
    func byProgress(_ handler: @escaping ProgressHandler) -> Self {
        self.onProgress = handler
        return self
    }
    /// 链式设置完成回调
    @discardableResult
    func byFinished(_ handler: @escaping ProgressHandler) -> Self {
        self.onFinished = handler
        return self
    }
    /// 链式启动：start() 并返回自身
    @discardableResult
    func byStartRunning() -> Self {
        start()
        return self
    }
    /// 工厂 + 自动 start 的快捷 DSL
    ///
    /// 用法：
    /// let process = JobsCountdownProcess.byStart(
    ///     duration: 10,
    ///     onProgress: { snap in ... },
    ///     onFinished: { snap in ... }
    /// )
    @discardableResult
    static func byStart(duration: TimeInterval,
                        kind: JobsTimerKind = .displayLink,
                        tickInterval: TimeInterval = 1.0 / 60.0,
                        tolerance: TimeInterval = 0,
                        queue: DispatchQueue = .main,
                        onProgress: ProgressHandler? = nil,
                        onFinished: ProgressHandler? = nil,
                        timeProvider: @escaping TimeProvider = { ProcessInfo.processInfo.systemUptime }) -> JobsSwiftTimerCountdown {
        let process = JobsSwiftTimerCountdown(
            duration: duration,
            kind: kind,
            tickInterval: tickInterval,
            tolerance: tolerance,
            queue: queue,
            timeProvider: timeProvider
        )
        process.onProgress = onProgress
        process.onFinished = onFinished
        process.start()
        return process
    }
}
