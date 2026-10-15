//
//  JobsResponseEvent.swift
//  JobsNetworking
//
//  Created by Jobs on 2026年5月13日，星期三.
//

import Foundation

public enum JobsResponseSource: String, Sendable {
    case cache
    case network
}

public struct JobsResponseEvent: Sendable {
    public let source: JobsResponseSource
    public let request: JobsRequest
    public let response: HTTPURLResponse?
    public let data: Data

    public init(source: JobsResponseSource, request: JobsRequest, response: HTTPURLResponse?, data: Data) {
        self.source = source
        self.request = request
        self.response = response
        self.data = data
    }
}
