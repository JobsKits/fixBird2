//
//  JobsHooks.swift
//  JobsNetworking
//
//  Created by Jobs on 2026年5月13日，星期三.
//

import Foundation

public protocol JobsHeaderHook: Sendable {
    func headers(for request: JobsRequest) -> [String: String]
}

public struct EmptyHeaderHook: JobsHeaderHook {
    public init() {}
    public func headers(for request: JobsRequest) -> [String: String] { [:] }
}

public protocol JobsEventObserver: Sendable {
    func willSend(_ request: JobsRequest)
    func didReceive(_ event: JobsResponseEvent)
    func didFail(request: JobsRequest, error: JobsError)
}

public struct EmptyEventObserver: JobsEventObserver {
    public init() {}
    public func willSend(_ request: JobsRequest) {}
    public func didReceive(_ event: JobsResponseEvent) {}
    public func didFail(request: JobsRequest, error: JobsError) {}
}
