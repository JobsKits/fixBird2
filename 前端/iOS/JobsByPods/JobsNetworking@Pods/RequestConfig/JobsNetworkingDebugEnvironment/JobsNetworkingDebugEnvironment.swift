//
//  JobsNetworkingDebugEnvironment.swift
//  JobsNetworking
//
//  Created by Jobs on 2026年10月5日，星期一.
//

#if DEBUG
import Foundation
import JobsSwiftDSL

/// 只改变后续相对路径请求；已经发出的请求与绝对 URL 保留原目标。
public final class JobsNetworkingDebugEnvironment: @unchecked Sendable {
    public static let shared = JobsNetworkingDebugEnvironment()
    private let lock = NSLock.jobsMake { _ in }
    private var baseURL: URL?

    private init() {}

    @discardableResult
    public func byBaseURL(_ url: URL?) -> Self {
        lock.lock()
        baseURL = url
        lock.unlock()
        return self
    }

    func resolvedBaseURL(fallback: URL) -> URL {
        lock.lock()
        defer { lock.unlock() }
        return baseURL ?? fallback
    }
}
#endif
