//
//  JobsRequest.swift
//  JobsNetworking
//
//  Created by Jobs on 2026年5月13日，星期三.
//

import Foundation

public struct JobsRequest: Sendable {
    public var path: String
    public var method: HTTPMethod
    public var query: [String: JobsValue]?
    public var body: [String: JobsValue]?
    public var headers: [String: String]
    public var timeout: TimeInterval?
    public var encoding: JobsParameterEncoding?
    public var cachePolicy: JobsCachePolicy
    public var retryPolicy: JobsRetryPolicy?
    public var trace: JobsTrace
    public var allowsEmptyResponse: Bool

    public init(
        path: String,
        method: HTTPMethod,
        query: [String: JobsValue]? = nil,
        body: [String: JobsValue]? = nil,
        headers: [String: String] = [:],
        timeout: TimeInterval? = nil,
        encoding: JobsParameterEncoding? = nil,
        cachePolicy: JobsCachePolicy = .networkOnly,
        retryPolicy: JobsRetryPolicy? = nil,
        trace: JobsTrace = JobsTrace(),
        allowsEmptyResponse: Bool = false
    ) {
        self.path = path
        self.method = method
        self.query = query
        self.body = body
        self.headers = headers
        self.timeout = timeout
        self.encoding = encoding
        self.cachePolicy = cachePolicy
        self.retryPolicy = retryPolicy
        self.trace = trace
        self.allowsEmptyResponse = allowsEmptyResponse
    }
}
