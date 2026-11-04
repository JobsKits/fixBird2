//
//  JobsCallbackable.swift
//  JobsSwiftBlock
//
//  Created by Jobs on 2026年5月13日，星期三.
//

import Foundation
import ObjectiveC

public protocol JobsCallbackable: AnyObject {}
private var storeKey: UInt8 = 0
private final class JobsCallbackStore {
    private let lock = NSLock()
    private var callbacks: [String: Any] = [:]

    func set<T>(_ value: T?, for key: String) {
        let previous: Any?
        lock.lock()
        if let value {
            previous = callbacks.updateValue(value, forKey: key)
        } else {
            previous = callbacks.removeValue(forKey: key)
        }
        lock.unlock()
        // 被替换捕获的 deinit 可能重入注册，延迟其释放到锁外。
        withExtendedLifetime(previous) {}
    }

    func value<T>(for key: String) -> T? {
        lock.lock()
        defer {
            lock.unlock()
        }
        return callbacks[key] as? T
    }
}
private let jobsCallbackStoreCreationLock = NSLock()

extension JobsCallbackable {
    private var jobs_callbackStore: JobsCallbackStore {
        jobsCallbackStoreCreationLock.lock()
        defer {
            jobsCallbackStoreCreationLock.unlock()
        }
        if let store = objc_getAssociatedObject(self, &storeKey) as? JobsCallbackStore {
            return store
        }
        let store = JobsCallbackStore()
        objc_setAssociatedObject(self, &storeKey, store, .OBJC_ASSOCIATION_RETAIN)
        return store
    }

    /// 存取同步，业务 closure 在锁外调用；closure 自身跨线程安全由注册方负责。
    @discardableResult
    public func jobsBy<T>(_ key: String, _ block: T?) -> Self {
        jobs_callbackStore.set(block, for: key)
        return self
    }

    public func jobs_callback<T>(_ key: String) -> T? {
        jobs_callbackStore.value(for: key)
    }
    // MARK: byXXX 省 key：默认用 #function 作为 key
    // 用法：func byTap(_ b: jobsByVoidBlock?) -> Self { jobsBySelfKey(b) }
    @discardableResult
    public func jobsBySelfKey<T>(_ block: T?, _ key: String = #function) -> Self {
        // #function 在这里是调用者的方法名，例如 "byTap(_:)"
        // 我们把 "(_:)" 去掉，让 key 稳定好看
        let stableKey = key.replacingOccurrences(of: "(_:)",
                                                 with: "")
                           .replacingOccurrences(of: "(_:)",
                                                 with: "")
        return jobsBy(stableKey, block)
    }
    // MARK: 调用 Void
    public func jobsCall(_ key: String) {
        let block: (() -> Void)? = jobs_callback(key)
        block?()
    }

    public func jobsCall<A>(_ key: String, _ a: A) {
        let block: ((A) -> Void)? = jobs_callback(key)
        block?(a)
    }

    public func jobsCall<A, B>(_ key: String, _ a: A, _ b: B) {
        let block: ((A, B) -> Void)? = jobs_callback(key)
        block?(a, b)
    }

    public func jobsCall<A, B, C>(_ key: String, _ a: A, _ b: B, _ c: C) {
        let block: ((A, B, C) -> Void)? = jobs_callback(key)
        block?(a, b, c)
    }
    // MARK: 调用 Return
    public func jobsCall<R>(_ key: String) -> R? {
        let block: (() -> R)? = jobs_callback(key)
        return block?()
    }

    public func jobsCall<A, R>(_ key: String, _ a: A) -> R? {
        let block: ((A) -> R)? = jobs_callback(key)
        return block?(a)
    }

    public func jobsCall<A, B, R>(_ key: String, _ a: A, _ b: B) -> R? {
        let block: ((A, B) -> R)? = jobs_callback(key)
        return block?(a, b)
    }
    // MARK: 调用 Optional Return
    public func jobsCallOptional<R>(_ key: String) -> R? {
        let block: (() -> R?)? = jobs_callback(key)
        return block?() ?? nil
    }

    public func jobsCallOptional<A, R>(_ key: String, _ a: A) -> R? {
        let block: ((A) -> R?)? = jobs_callback(key)
        return block?(a) ?? nil
    }
    // MARK:  把 #function 规范化成稳定 key（去掉参数列表）
    @inline(__always)
    private func jobs_normalizeFunctionKey(_ f: String) -> String {
        f.replacingOccurrences(of: "\\(.*\\)", with: "", options: .regularExpression)
    }
    // 触发：不写 key，只传参数
    public func jobsCallSelfKey<A>(_ a: A, _ key: String = #function) {
        jobsCall(jobs_normalizeFunctionKey(key), a)
    }

    public func jobsCallSelfKey<A, B>(_ a: A, _ b: B, _ key: String = #function) {
        jobsCall(jobs_normalizeFunctionKey(key), a, b)
    }

    public func jobsCallSelfKey(_ key: String = #function) {
        jobsCall(jobs_normalizeFunctionKey(key))
    }
}
