//
//  JobsCacheStore.swift
//  JobsNetworking
//
//  Created by Jobs on 2026年5月13日，星期三.
//

import Foundation

public protocol JobsCacheStore: Sendable {
    func get(key: JobsCacheKey) -> JobsCachedValue?
    func get(key: JobsCacheKey, allowExpired: Bool) -> JobsCachedValue?
    func set(key: JobsCacheKey, value: JobsCachedValue)
    func remove(key: JobsCacheKey)
    func removeAll()
}

public extension JobsCacheStore {
    /// 第三方 store 维持旧合同；内建 store 支持有限宽限期内的 stale 读取。
    func get(key: JobsCacheKey, allowExpired: Bool) -> JobsCachedValue? {
        get(key: key)
    }
}

public struct JobsCachedValue: Codable, Sendable {
    public let data: Data
    public let expiry: Date
    public let responseHeaders: [String: String]

    public init(data: Data, expiry: Date, responseHeaders: [String: String] = [:]) {
        self.data = data
        self.expiry = expiry
        self.responseHeaders = responseHeaders
    }

    public var isExpired: Bool {
        Date() >= expiry
    }
}

public final class JobsMemoryCache: JobsCacheStore, @unchecked Sendable {
    private let lock = NSLock()
    private var store: [String: JobsCachedValue] = [:]
    private var access: [String: Date] = [:]
    private let maximumEntryCount: Int
    private let maximumByteCount: Int
    private let staleGrace: TimeInterval

    public init(
        maximumEntryCount: Int = 256, maximumByteCount: Int = 10 * 1_024 * 1_024, staleGrace: TimeInterval = 300
    ) {
        self.maximumEntryCount = max(1, maximumEntryCount)
        self.maximumByteCount = max(1, maximumByteCount)
        self.staleGrace = staleGrace.isFinite ? max(0, min(staleGrace, 86_400)) : 300
    }

    public func get(key: JobsCacheKey) -> JobsCachedValue? {
        get(key: key, allowExpired: false)
    }

    public func get(key: JobsCacheKey, allowExpired: Bool) -> JobsCachedValue? {
        var retired: JobsCachedValue?
        lock.lock()
        defer {
            lock.unlock()
            withExtendedLifetime(retired) {}
        }
        guard let value = store[key.raw] else {
            return nil
        }
        let now = Date()
        if now >= value.expiry.addingTimeInterval(staleGrace) {
            retired = store.removeValue(forKey: key.raw)
            access[key.raw] = nil
            return nil
        }
        guard allowExpired || now < value.expiry else {
            return nil
        }
        access[key.raw] = now
        return value
    }

    public func set(key: JobsCacheKey, value: JobsCachedValue) {
        var retired: [JobsCachedValue] = []
        lock.lock()
        defer {
            lock.unlock()
            withExtendedLifetime(retired) {}
        }
        guard value.data.count <= maximumByteCount else {
            return
        }
        if let previous = store.updateValue(value, forKey: key.raw) {
            retired.append(previous)
        }
        access[key.raw] = Date()
        while store.count > maximumEntryCount
            || store.values.reduce(
                0,
                {
                    $0 + $1.data.count
                }) > maximumByteCount
        {
            guard
                let oldest = access.min(by: {
                    $0.value < $1.value
                })?.key
            else {
                break
            }
            if let previous = store.removeValue(forKey: oldest) {
                retired.append(previous)
            }
            access[oldest] = nil
        }
    }

    public func remove(key: JobsCacheKey) {
        var retired: JobsCachedValue?
        lock.lock()
        defer {
            lock.unlock()
            withExtendedLifetime(retired) {}
        }
        retired = store.removeValue(forKey: key.raw)
        access[key.raw] = nil
    }

    public func removeAll() {
        lock.lock()
        let retired = store
        store = [:]
        access.removeAll()
        lock.unlock()
        // Data 自定义 deallocator 也属于用户代码，不能在锁内析构。
        withExtendedLifetime(retired) {}
    }
}

public final class JobsDiskCache: JobsCacheStore, @unchecked Sendable {
    private enum ReadError: LocalizedError {
        case invalidFile
        case budgetExceeded

        var errorDescription: String? {
            switch self {
            case .invalidFile:
                return "缓存项不是普通文件"
            case .budgetExceeded:
                return "缓存项超过当前磁盘预算"
            }
        }
    }

    private let dir: URL
    private let lock = NSLock()
    private let maximumEntryCount: Int
    private let maximumByteCount: Int
    private let staleGrace: TimeInterval
    private let onError: (@Sendable (Error) -> Void)?

    public init(
        namespace: String = "JobsNetworkingCache", maximumEntryCount: Int = 500,
        maximumByteCount: Int = 100 * 1_024 * 1_024, staleGrace: TimeInterval = 300,
        onError: (@Sendable (Error) -> Void)? = nil
    ) {
        self.maximumEntryCount = max(1, maximumEntryCount)
        self.maximumByteCount = max(1, maximumByteCount)
        self.staleGrace = staleGrace.isFinite ? max(0, min(staleGrace, 86_400)) : 300
        self.onError = onError
        let base =
            FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let safe = namespace.unicodeScalars.map {
            CharacterSet.alphanumerics.contains($0) || "._-".unicodeScalars.contains($0) ? String($0) : "_"
        }.joined()
        let namespaceComponent = safe.utf8.count > 100 ? JobsCacheKey.digest(Data(safe.utf8)) : safe
        dir = base.appendingPathComponent(
            namespaceComponent.isEmpty || namespaceComponent == "." || namespaceComponent == ".."
                ? "JobsNetworkingCache" : namespaceComponent, isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        } catch {
            onError?(error)
        }
    }

    public func get(key: JobsCacheKey) -> JobsCachedValue? {
        get(key: key, allowExpired: false)
    }

    public func get(key: JobsCacheKey, allowExpired: Bool) -> JobsCachedValue? {
        var failure: Error?
        lock.lock()
        let url = fileURL(for: key)
        var result: JobsCachedValue?
        if FileManager.default.fileExists(atPath: url.path) {
            do {
                let info = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
                guard info.isRegularFile == true, info.isSymbolicLink != true else {
                    throw ReadError.invalidFile
                }
                guard let size = info.fileSize, size >= 0, size <= maximumByteCount else {
                    throw ReadError.budgetExceeded
                }
                let data = try Data(contentsOf: url)
                guard data.count <= maximumByteCount else {
                    throw ReadError.budgetExceeded
                }
                let value = try JSONDecoder().decode(JobsCachedValue.self, from: data)
                let now = Date()
                if now >= value.expiry.addingTimeInterval(staleGrace) {
                    try FileManager.default.removeItem(at: url)
                } else if allowExpired || now < value.expiry {
                    result = value
                    try FileManager.default.setAttributes([.modificationDate: now], ofItemAtPath: url.path)
                }
            } catch {
                result = nil
                failure = error
                // 超预算或损坏项只按 miss 处理，避免下一次重复读入和解码。
                try? FileManager.default.removeItem(at: url)
            }
        }
        lock.unlock()
        if let failure {
            onError?(failure)
        }
        return result
    }

    public func set(key: JobsCacheKey, value: JobsCachedValue) {
        var failure: Error?
        lock.lock()
        do {
            guard value.data.count <= maximumByteCount else {
                throw ReadError.budgetExceeded
            }
            let encoded = try JSONEncoder().encode(value)
            guard encoded.count <= maximumByteCount else {
                throw ReadError.budgetExceeded
            }
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            try encoded.write(to: fileURL(for: key), options: .atomic)
            try trim()
        } catch {
            failure = error
        }
        lock.unlock()
        if let failure {
            onError?(failure)
        }
    }

    public func remove(key: JobsCacheKey) {
        var failure: Error?
        lock.lock()
        do {
            let url = fileURL(for: key)
            if FileManager.default.fileExists(atPath: url.path) {
                try FileManager.default.removeItem(at: url)
            }
        } catch {
            failure = error
        }
        lock.unlock()
        if let failure {
            onError?(failure)
        }
    }

    public func removeAll() {
        var failure: Error?
        lock.lock()
        do {
            if FileManager.default.fileExists(atPath: dir.path) {
                try FileManager.default.removeItem(at: dir)
            }
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        } catch {
            failure = error
        }
        lock.unlock()
        if let failure {
            onError?(failure)
        }
    }

    private func fileURL(for key: JobsCacheKey) -> URL {
        dir.appendingPathComponent(JobsCacheKey.digest(Data(key.raw.utf8))).appendingPathExtension("cache")
    }

    private func trim() throws {
        let files = try FileManager.default.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey]
        )
        .filter {
            $0.pathExtension == "cache"
        }
        let entries = try files.map { url -> (URL, Date, Int) in
            let info = try url.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey])
            return (url, info.contentModificationDate ?? .distantPast, info.fileSize ?? 0)
        }.sorted {
            $0.1 < $1.1
        }
        var bytes = entries.reduce(0) {
            $0 + $1.2
        }
        var count = entries.count
        for entry in entries where count > maximumEntryCount || bytes > maximumByteCount {
            try FileManager.default.removeItem(at: entry.0)
            bytes -= entry.2
            count -= 1
        }
    }
}
