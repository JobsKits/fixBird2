//
//  JobsSwiftTimer.swift
//  JobsSwiftTimer
//
//  Created by Jobs on 2026年5月13日，星期三.
//

#if os(OSX)
import AppKit
#elseif os(iOS) || os(tvOS)
import UIKit
#endif

import QuartzCore // CADisplayLink
import os.lock
// MARK: - JobsUnfairLock
final class JobsUnfairLock {
    private var lock = os_unfair_lock_s()

    @inline(__always)
    func jobs_withLock<T>(_ block: () throws -> T) rethrows -> T {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) };return try block()
    }
}
// MARK: - JobsSwiftTimer
///
/// ✅ 更“狠”的规则（最终版）
/// - 非 GCD 内核（foundation/runLoop/displayLink）强制：只能主线程 + RunLoop.main
/// - RunLoop/DisplayLink 生命周期操作必须主线程
/// - 回调类型统一为 @Sendable
/// - stop 后 late event：generation token 防穿透
/// - ✅ 修复：GCD suspend/cancel 平衡（不会炸）
/// - ✅ 修复：one-shot 在非 main queue 上 stop 的主线程路由（不会炸）
public final class JobsTimer: JobsSwiftTimerProtocol, @unchecked Sendable {
    // MARK: - State
    private enum State: Equatable {
        case idle
        case running
        case paused
        case stopped
    }
    // MARK: - Public
    public var isRunning: Bool {
        stateLock.jobs_withLock { state == .running }
    }
    /// 非 GCD 内核依赖主线程 RunLoop，Manager 据此路由生命周期操作。
    public var requiresMainThreadLifecycle: Bool {
        kind != .gcd
    }
    // MARK: - Private
    private let kind: JobsTimerKind
    private let config: JobsSwiftTimerConfig

    private let stateLock = JobsUnfairLock()
    /// 串行化 start/pause/resume/stop 与底层引擎切换，避免 GCD 生命周期竞态。
    private let lifecycleLock = NSRecursiveLock()
    private var state: State = .idle
    /// generation token：状态变更递增，用于防止残留回调穿透
    private var generation: UInt64 = 0
    /// 只允许前台通知恢复由应用状态自动暂停的 timer。
    private var autoPausedByAppState = false
    /// 非 enqueue 策略下，保证同一时间最多执行一个回调。
    private var callbackInFlight = false
    /// coalesceLatest 只保留最新一代的待执行 tick。
    private var pendingCallbackToken: UInt64?

    private var tickBlock: JobsTimerCallback
    private var finishBlock: JobsTimerCallback?
    // Underlying engines
    private var gcdTimer: DispatchSourceTimer?
    private var gcdIsSuspended: Bool = false

    private var foundationTimer: Timer?
    private var displayLink: CADisplayLink?
    private var rlTimer: CFRunLoopTimer?

    #if canImport(UIKit)
    private var appState: JobsAppStateManager?
    #endif
    // MARK: - Thread constraints
    @inline(__always)
    private func requireMainThreadForRunLoopAPI(_ reason: String) {
        precondition(
            Thread.isMainThread,
            "JobsTimer: \(reason) must be called on main thread (RunLoop/DisplayLink are thread-affine)."
        )
    }

    @inline(__always)
    private func requireMainRunLoopForNonGCD() {
        precondition(
            config.runLoop == .main,
            "JobsTimer: kind=\(kind) currently only supports RunLoop.main (RunLoop APIs are thread-affine)."
        )
    }
    // MARK: - Init
    public init(
        kind: JobsTimerKind,
        config: JobsSwiftTimerConfig,
        handler: @escaping JobsTimerCallback
    ) {
        self.kind = kind
        self.config = config.normalized
        self.tickBlock = handler
        if kind != .gcd {
            requireMainRunLoopForNonGCD()
            precondition(Thread.isMainThread, "JobsTimer: init(kind=\(kind)) must be called on main thread.")
        }
        setupAppStateIfNeeded()
    }

    deinit {
        stateLock.jobs_withLock {
            state = .stopped
            generation &+= 1
            autoPausedByAppState = false
            pendingCallbackToken = nil
        }
        teardownUnderlyingEnginesFromDeinit()
        teardownAppState()
    }
    // MARK: - JobsSwiftTimerProtocol
    /// 启动计时器
    @discardableResult
    public func start() -> Self {
        if kind != .gcd { requireMainThreadForRunLoopAPI("start") }
        let shouldStartPaused = shouldPauseForCurrentAppState()
        lifecycleLock.lock()
        defer { lifecycleLock.unlock() }
        let token = stateLock.jobs_withLock { () -> UInt64? in
            switch state {
            /// 处理 .running 分支
            case .running:
                return nil
            /// 合并处理 .paused、.idle 分支
            case .paused, .idle:
                generation &+= 1
                pendingCallbackToken = nil
                if shouldStartPaused {
                    state = .paused
                    autoPausedByAppState = true
                    return nil
                }
                state = .running
                autoPausedByAppState = false
                return generation
            /// 处理 .stopped 分支
            case .stopped:
                return nil
            }
        }
        guard let token else { return self }
        switch kind {
        /// 处理 .gcd 分支
        case .gcd:
            startGCD(token: token)
        /// 处理 .foundation 分支
        case .foundation:
            startFoundationTimer(token: token)
        /// 处理 .displayLink 分支
        case .displayLink:
            startDisplayLink(token: token)
        /// 处理 .runLoop 分支
        case .runLoop:
            startRunLoopTimer(token: token)
        };return self
    }
    /// 暂停计时器
    @discardableResult
    public func pause() -> Self{
        pause(markedAsAutoPause: false)
    }

    @discardableResult
    private func pause(markedAsAutoPause: Bool) -> Self {
        lifecycleLock.lock()
        defer { lifecycleLock.unlock() }
        if kind != .gcd { requireMainThreadForRunLoopAPI("pause") }
        let shouldPause = stateLock.jobs_withLock { () -> Bool in
            if state == .paused {
                if !markedAsAutoPause {
                    autoPausedByAppState = false
                    pendingCallbackToken = nil
                }
                return false
            }
            guard state == .running else { return false }
            state = .paused
            generation &+= 1
            autoPausedByAppState = markedAsAutoPause
            pendingCallbackToken = nil
            return true
        }
        guard shouldPause else { return self}
        switch kind {
        /// 处理 .gcd 分支
        case .gcd:
            pauseGCD()
        /// 处理 .foundation 分支
        case .foundation:
            foundationTimer?.invalidate()
            foundationTimer = nil
        /// 处理 .displayLink 分支
        case .displayLink:
            displayLink?.invalidate()
            displayLink = nil
        /// 处理 .runLoop 分支
        case .runLoop:
            if let t = rlTimer {
                CFRunLoopTimerInvalidate(t)
                rlTimer = nil
            }
        };return self
    }
    /// 恢复计时器
    @discardableResult
    public func resume() -> Self{
        resume(onlyIfAutoPaused: false)
    }

    @discardableResult
    private func resume(onlyIfAutoPaused: Bool) -> Self {
        if kind != .gcd { requireMainThreadForRunLoopAPI("resume") }
        let shouldRemainPaused = shouldPauseForCurrentAppState()
        lifecycleLock.lock()
        defer { lifecycleLock.unlock() }
        let token = stateLock.jobs_withLock { () -> UInt64? in
            guard state == .paused else { return nil }
            guard !onlyIfAutoPaused || autoPausedByAppState else { return nil }
            generation &+= 1
            pendingCallbackToken = nil
            if shouldRemainPaused {
                state = .paused
                autoPausedByAppState = true
                return nil
            }
            state = .running
            autoPausedByAppState = false
            return generation
        }
        guard let token else { return self}
        switch kind {
        /// 处理 .gcd 分支
        case .gcd:
            resumeGCD(token: token)
        /// 处理 .foundation 分支
        case .foundation:
            startFoundationTimer(token: token)
        /// 处理 .displayLink 分支
        case .displayLink:
            startDisplayLink(token: token)
        /// 处理 .runLoop 分支
        case .runLoop:
            startRunLoopTimer(token: token)
        };return self
    }
    /// 停止计时器并提交一次 tick，随后执行 finish。
    @discardableResult
    public func fireOnce() -> Self {
        lifecycleLock.lock()
        defer { lifecycleLock.unlock() }
        // 非 GCD：RunLoop/DisplayLink/Foundation 的 invalidate 必须主线程做
        if kind != .gcd, !Thread.isMainThread {
            DispatchQueue.main.async { [self] in
                _ = fireOnce()
            };return self
        }
        let callbacks = stateLock.jobs_withLock { () -> (tick: JobsTimerCallback, finish: JobsTimerCallback?)? in
            guard state != .stopped else { return nil }
            state = .stopped
            generation &+= 1
            autoPausedByAppState = false
            pendingCallbackToken = nil
            return (tickBlock, finishBlock)
        }
        guard let callbacks else { return self }
        // 真正销毁底层 timer
        stopInternal()
        // 终态投递持有回调快照，不依赖 Manager 登记或 timer 后续生命周期。
        config.queue.async {
            callbacks.tick()
            callbacks.finish?()
        }
        return self
    }
    /// 停止计时器（销毁@无回调）
    @discardableResult
    public func stop() -> Self{
        lifecycleLock.lock()
        defer { lifecycleLock.unlock() }
        if kind != .gcd {
            // 外部 stop 强制主线程；one-shot 由对应 RunLoop 回调在主线程收口。
            requireMainThreadForRunLoopAPI("stop")
        }
        let shouldStop = stateLock.jobs_withLock { () -> Bool in
            guard state != .stopped else { return false }
            state = .stopped
            generation &+= 1
            autoPausedByAppState = false
            pendingCallbackToken = nil
            return true
        }
        guard shouldStop else { return self}
        stopInternal()
        return self
    }
    /// 注册回调（每 tick 执行一次）
    @discardableResult
    public func onTick(_ block: @escaping JobsTimerCallback) -> Self {
        stateLock.jobs_withLock { tickBlock = block };return self
    }
    /// 注册完成回调（用于一次性定时器或倒计时）
    @discardableResult
    public func onFinish(_ block: @escaping JobsTimerCallback) -> Self {
        stateLock.jobs_withLock { finishBlock = block };return self
    }
    // MARK: - Stop internals
    private func stopInternal() {
        switch kind {
        /// 处理 .gcd 分支
        case .gcd:
            stopGCDSafely()
        /// 处理 .foundation 分支
        case .foundation:
            foundationTimer?.invalidate()
            foundationTimer = nil
        /// 处理 .displayLink 分支
        case .displayLink:
            displayLink?.invalidate()
            displayLink = nil
        /// 处理 .runLoop 分支
        case .runLoop:
            if let t = rlTimer {
                CFRunLoopTimerInvalidate(t)
                rlTimer = nil
            }
        }
    }

    private func teardownUnderlyingEnginesFromDeinit() {
        if kind == .gcd {
            stopGCDSafely()
            return
        }
        let foundation = foundationTimer
        let link = displayLink
        let runLoopTimer = rlTimer
        foundationTimer = nil
        displayLink = nil
        rlTimer = nil
        let invalidate = {
            foundation?.invalidate()
            link?.invalidate()
            if let runLoopTimer {
                CFRunLoopTimerInvalidate(runLoopTimer)
            }
        }
        if Thread.isMainThread {
            invalidate()
        } else {
            DispatchQueue.main.async(execute: invalidate)
        }
    }
    // MARK: - Dispatch
    private func fireTickIfValid(token: UInt64) {
        lifecycleLock.lock()
        defer { lifecycleLock.unlock() }
        let snapshot = stateLock.jobs_withLock { () -> (shouldFire: Bool,
                                                        tick: JobsTimerCallback,
                                                        finish: JobsTimerCallback?,
                                                        repeats: Bool) in
            guard state == .running, token == generation else {
                return (false, {}, nil, config.repeats)
            }
            let repeats = config.repeats
            if !repeats {
                state = .stopped
                generation &+= 1
                autoPausedByAppState = false
                pendingCallbackToken = nil
            };return (true, tickBlock, finishBlock, repeats)
        }
        guard snapshot.shouldFire else { return }
        if !snapshot.repeats {
            stopInternal()
            config.queue.async {
                snapshot.tick()
                snapshot.finish?()
            }
            return
        }
        deliverRepeatingTick(token: token, snapshotTick: snapshot.tick)
    }

    private func deliverRepeatingTick(
        token: UInt64,
        snapshotTick: @escaping JobsTimerCallback
    ) {
        switch config.callbackDeliveryPolicy {
        /// 处理 .enqueue 分支
        case .enqueue:
            config.queue.async { [weak self] in
                let isStillValid = self?.stateLock.jobs_withLock {
                    self?.state == .running && self?.generation == token
                } ?? false
                guard isStillValid else { return }
                snapshotTick()
            }
        /// 合并处理 .dropIfBusy、.coalesceLatest 分支
        case .dropIfBusy, .coalesceLatest:
            let shouldSchedule = stateLock.jobs_withLock { () -> Bool in
                guard state == .running, generation == token else { return false }
                if callbackInFlight {
                    if config.callbackDeliveryPolicy == .coalesceLatest {
                        pendingCallbackToken = token
                    }
                    return false
                }
                callbackInFlight = true
                return true
            }
            guard shouldSchedule else { return }
            scheduleManagedRepeatingCallback(token: token)
        }
    }

    private func scheduleManagedRepeatingCallback(token: UInt64) {
        config.queue.async { [weak self] in
            guard let self else { return }
            let tick = self.stateLock.jobs_withLock { () -> JobsTimerCallback? in
                guard self.state == .running, self.generation == token else { return nil }
                return self.tickBlock
            }
            tick?()
            self.completeManagedRepeatingCallback()
        }
    }

    private func completeManagedRepeatingCallback() {
        let nextToken = stateLock.jobs_withLock { () -> UInt64? in
            if config.callbackDeliveryPolicy == .coalesceLatest,
               let pendingCallbackToken,
               state == .running,
               generation == pendingCallbackToken {
                self.pendingCallbackToken = nil
                return pendingCallbackToken
            }
            callbackInFlight = false
            pendingCallbackToken = nil
            return nil
        }
        if let nextToken {
            scheduleManagedRepeatingCallback(token: nextToken)
        }
    }
    // MARK: - GCD Timer
    private func startGCD(token: UInt64) {
        // 重建更干净：避免 resume/suspend 计数错乱
        stopGCDSafely()
        let t = DispatchSource.makeTimerSource(queue: config.queue)
        t.schedule(
            deadline: .now() + config.interval,
            repeating: config.interval,
            leeway: .milliseconds(Int(config.tolerance * 1000.0))
        )
        t.setEventHandler { [weak self] in
            self?.fireTickIfValid(token: token)
        }
        gcdTimer = t
        gcdIsSuspended = false
        t.resume()
    }

    private func pauseGCD() {
        guard let t = gcdTimer else { return }
        // 防重复 suspend
        if !gcdIsSuspended {
            gcdIsSuspended = true
            t.suspend()
        }
    }

    private func resumeGCD(token: UInt64) {
        guard let t = gcdTimer else {
            startGCD(token: token)
            return
        }
        if gcdIsSuspended {
            t.setEventHandler { [weak self] in
                self?.fireTickIfValid(token: token)
            }
            gcdIsSuspended = false
            t.resume()
        }
    }

    private func stopGCDSafely() {
        guard let t = gcdTimer else { return }
        // ✅ 关键：cancel 前必须平衡 suspend
        if gcdIsSuspended {
            gcdIsSuspended = false
            t.resume()
        }
        t.setEventHandler {}
        t.cancel()
        gcdTimer = nil
    }
    // MARK: - Foundation Timer（依赖 RunLoop）
    private func startFoundationTimer(token: UInt64) {
        requireMainThreadForRunLoopAPI("startFoundationTimer")
        requireMainRunLoopForNonGCD()
        let t = Timer(timeInterval: config.interval, repeats: config.repeats) { [weak self] _ in
            self?.fireTickIfValid(token: token)
        }
        t.tolerance = config.tolerance
        config.runLoop.add(t, forMode: config.runLoopMode)
        foundationTimer = t
    }
    // MARK: - CADisplayLink（主线程）
    private func startDisplayLink(token: UInt64) {
        requireMainThreadForRunLoopAPI("startDisplayLink")
        requireMainRunLoopForNonGCD()
        let proxy = DisplayLinkProxy(interval: config.interval) { [weak self] in
            self?.fireTickIfValid(token: token)
        }
        let link = CADisplayLink(target: proxy, selector: #selector(DisplayLinkProxy.tick(_:)))
        link.add(to: config.runLoop, forMode: config.runLoopMode)
        displayLink = link
    }

    private final class DisplayLinkProxy: NSObject {
        private let interval: TimeInterval
        private let onTick: JobsTimerCallback
        private var nextFireTimestamp: CFTimeInterval

        init(interval: TimeInterval, onTick: @escaping JobsTimerCallback) {
            self.interval = interval
            self.onTick = onTick
            self.nextFireTimestamp = CACurrentMediaTime() + interval
        }

        @objc func tick(_ link: CADisplayLink) {
            let timestamp = link.targetTimestamp
            guard timestamp + 0.000_001 >= nextFireTimestamp else { return }
            let elapsed = max(0, timestamp - nextFireTimestamp)
            let skippedIntervals = floor(elapsed / interval) + 1
            nextFireTimestamp += skippedIntervals * interval
            onTick()
        }
    }
    // MARK: - CFRunLoopTimer（依赖 RunLoop）
    private func startRunLoopTimer(token: UInt64) {
        requireMainThreadForRunLoopAPI("startRunLoopTimer")
        requireMainRunLoopForNonGCD()
        let nextFire = CFAbsoluteTimeGetCurrent() + config.interval
        let interval = config.repeats ? config.interval : 0
        let timer = CFRunLoopTimerCreateWithHandler(
            kCFAllocatorDefault,
            nextFire,
            interval,
            0,
            0
        ) { [weak self] _ in
            self?.fireTickIfValid(token: token)
        }
        let cfRunLoop = config.runLoop.getCFRunLoop()
        let cfMode: CFRunLoopMode = (config.runLoopMode == .common)
            ? .commonModes
            : CFRunLoopMode(config.runLoopMode.rawValue as CFString)
        CFRunLoopAddTimer(cfRunLoop, timer, cfMode)
        stateLock.jobs_withLock { rlTimer = timer }
    }
    // MARK: - App State (UIKit)
    private func setupAppStateIfNeeded() {
        #if canImport(UIKit)
        guard config.autoManageAppState else { return }
        appState = JobsAppStateManager(
            pauseInBackground: config.pauseInBackground,
            action: { [weak self] action in
                guard let self else { return }
                switch action {
                /// 处理 .pauseForAppState 分支
                case .pauseForAppState: self.pause(markedAsAutoPause: true)
                /// 处理 .resumeFromAppState 分支
                case .resumeFromAppState: self.resume(onlyIfAutoPaused: true)
                }
            }
        )
        #endif
    }

    private func teardownAppState() {
        #if canImport(UIKit)
        appState = nil
        #endif
    }

    private func shouldPauseForCurrentAppState() -> Bool {
        #if canImport(UIKit)
        return appState?.shouldPauseForCurrentAppState() ?? false
        #else
        return false
        #endif
    }
}

private enum JobsAppStateAction {
    case pauseForAppState
    case resumeFromAppState
}

private final class JobsAppStateManager: @unchecked Sendable {
    private let pauseInBackground: Bool
    private let action: @Sendable (JobsAppStateAction) -> Void

    init(
        pauseInBackground: Bool,
        action: @escaping @Sendable (JobsAppStateAction) -> Void
    ) {
        self.pauseInBackground = pauseInBackground
        self.action = action
        register()
    }

    deinit { unregister() }

    func shouldPauseForCurrentAppState() -> Bool {
        #if canImport(UIKit)
        guard pauseInBackground else { return false }
        if Thread.isMainThread {
            let state = UIApplication.shared.applicationState
            return state == .background || state == .inactive
        }
        return DispatchQueue.main.sync {
            let state = UIApplication.shared.applicationState
            return state == .background || state == .inactive
        }
        #else
        return false
        #endif
    }

    private func register() {
        #if canImport(UIKit)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(onWillResignActive),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(onDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
        #endif
    }

    private func unregister() {
        #if canImport(UIKit)
        NotificationCenter.default.removeObserver(self)
        #endif
    }

    @objc private func onWillResignActive() {
        if pauseInBackground { action(.pauseForAppState) }
    }

    @objc private func onDidBecomeActive() {
        if pauseInBackground { action(.resumeFromAppState) }
    }
}
