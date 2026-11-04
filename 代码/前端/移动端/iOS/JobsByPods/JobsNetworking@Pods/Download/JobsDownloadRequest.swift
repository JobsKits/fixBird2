//
//  JobsDownloadRequest.swift
//  JobsNetworking
//
//  Created by Jobs on 2026年5月13日，星期三.
//

import Foundation

public struct JobsDownloadRequest: Sendable {
    public var absoluteURL: URL
    public var destinationURL: URL
    public var headers: [String: String]
    public var timeout: TimeInterval?
    public var trace: JobsTrace
    public var expectedByteCount: Int64?
    public var expectedSHA256: String?

    public init(
        absoluteURL: URL,
        destinationURL: URL,
        headers: [String: String] = [:],
        timeout: TimeInterval? = nil,
        trace: JobsTrace = JobsTrace(),
        expectedByteCount: Int64? = nil,
        expectedSHA256: String? = nil
    ) {
        self.absoluteURL = absoluteURL
        self.destinationURL = destinationURL
        self.headers = headers
        self.timeout = timeout
        self.trace = trace
        self.expectedByteCount = expectedByteCount
        self.expectedSHA256 = expectedSHA256
    }
}
