//
//  JobsCachePolicy.swift
//  JobsNetworking
//
//  Created by Jobs on 2026年5月13日，星期三.
//

import Foundation

public enum JobsCachePolicy: Sendable {
    case disabled
    case networkOnly
    case cacheOnly(ttl: TimeInterval)
    case cacheElseLoad(ttl: TimeInterval)
    case staleWhileRevalidate(ttl: TimeInterval)

    @available(*, deprecated, renamed: "disabled")
    public static var none: JobsCachePolicy { .disabled }

    @available(*, deprecated, renamed: "cacheElseLoad(ttl:)")
    public static func cacheThenNetwork(ttl: TimeInterval) -> JobsCachePolicy { .cacheElseLoad(ttl: ttl) }

    @available(*, deprecated, renamed: "staleWhileRevalidate(ttl:)")
    public static func memoryThenNetwork(ttl: TimeInterval) -> JobsCachePolicy { .staleWhileRevalidate(ttl: ttl) }
}
