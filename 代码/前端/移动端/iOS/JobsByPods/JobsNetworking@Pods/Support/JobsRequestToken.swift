//
//  JobsRequestToken.swift
//  JobsNetworking
//
//  Created by Jobs on 2026年5月13日，星期三.
//

import Foundation

public final class JobsRequestToken: @unchecked Sendable {
    private let lock = NSLock()
    private var cancelHandler: (() -> Void)?
    private var cancelled = false
    private var finished = false
    private var retryItem: DispatchWorkItem?
    private var retryGeneration = UUID()
    let operationID = UUID().uuidString

    public var isCancelled: Bool {
        locked {
            cancelled
        }
    }
    var isFinished: Bool {
        locked {
            finished
        }
    }

    public init() {}

    public func setCancel(_ block: @escaping () -> Void) {
        var retiredHandler: (() -> Void)?
        let invoke = locked { () -> Bool in
            guard !finished else {
                return false
            }
            if cancelled {
                return true
            }
            retiredHandler = cancelHandler
            cancelHandler = block
            return false
        }
        // capture 的析构可能重入 token，必须在解锁后释放旧 handler。
        withExtendedLifetime(retiredHandler) {}
        if invoke {
            block()
        }
    }

    public func cancel() {
        var retiredRetry: DispatchWorkItem?
        let handler = locked { () -> (() -> Void)? in
            guard !cancelled, !finished else {
                return nil
            }
            cancelled = true
            retryGeneration = UUID()
            retiredRetry = retryItem
            retryItem = nil
            let handler = cancelHandler
            cancelHandler = nil
            return handler
        }
        retiredRetry?.cancel()
        handler?()
        withExtendedLifetime(retiredRetry) {}
    }

    /// 在锁内只争抢终态，在锁外执行用户代码。成功提交后取消为无操作。
    @discardableResult
    func finish(_ action: () -> Void) -> Bool {
        var retiredHandler: (() -> Void)?
        var retiredRetry: DispatchWorkItem?
        let accepted = locked { () -> Bool in
            guard !finished else {
                return false
            }
            finished = true
            retiredHandler = cancelHandler
            cancelHandler = nil
            retryGeneration = UUID()
            retiredRetry = retryItem
            retryItem = nil
            return true
        }
        retiredRetry?.cancel()
        withExtendedLifetime(retiredHandler) {}
        withExtendedLifetime(retiredRetry) {}
        if accepted {
            action()
        }
        return accepted
    }

    func scheduleRetry(after delay: TimeInterval, _ action: @escaping () -> Void) {
        let currentGeneration = UUID()
        let item = DispatchWorkItem { [weak self] in
            guard let self else {
                return
            }
            var consumedRetry: DispatchWorkItem?
            let active = self.locked { () -> Bool in
                guard self.retryGeneration == currentGeneration else {
                    return false
                }
                consumedRetry = self.retryItem
                self.retryItem = nil
                self.retryGeneration = UUID()
                return !self.cancelled && !self.finished
            }
            withExtendedLifetime(consumedRetry) {}
            if active {
                action()
            }
        }
        var retiredRetry: DispatchWorkItem?
        let accepted = locked { () -> Bool in
            guard !cancelled, !finished else {
                return false
            }
            retiredRetry = retryItem
            retryGeneration = currentGeneration
            retryItem = item
            return true
        }
        retiredRetry?.cancel()
        withExtendedLifetime(retiredRetry) {}
        guard accepted else {
            return
        }
        let safeDelay = delay.isFinite ? min(86_400, max(0, delay)) : 0
        DispatchQueue.global().asyncAfter(deadline: .now() + safeDelay, execute: item)
    }

    private func locked<T>(_ action: () -> T) -> T {
        lock.lock()
        defer {
            lock.unlock()
        }
        return action()
    }
}
