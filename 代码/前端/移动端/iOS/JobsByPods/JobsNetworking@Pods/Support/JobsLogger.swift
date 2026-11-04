//
//  JobsLogger.swift
//  JobsNetworking
//
//  Created by Jobs on 2026年5月13日，星期三.
//

import Foundation

public enum JobsLogLevel: String, Sendable {
    case debug
    case info
    case warn
    case error
}

public struct JobsLogger: Sendable {
    public typealias Handler = @Sendable (_ level: JobsLogLevel, _ message: String, _ meta: [String: String]) -> Void

    public var isEnabled: Bool
    public var handler: Handler

    public init(
        isEnabled: Bool = true,
        handler: @escaping Handler = { level, message, meta in
            #if DEBUG
            let metaString = meta.map { "\($0.key)=\($0.value)" }.sorted().joined(separator: " ")
            print("[JobsNetworking][\(level.rawValue.uppercased())] \(message) \(metaString)")
            #endif
        }
    ) {
        self.isEnabled = isEnabled
        self.handler = handler
    }

    public func log(_ level: JobsLogLevel, _ message: String, meta: [String: String] = [:]) {
        guard isEnabled else { return }
        handler(level, message, meta)
    }
}
