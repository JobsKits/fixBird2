//
//  JobsRequestConfig.swift
//  JobsNetworking
//
//  Created by Jobs on 2026年5月13日，星期三.
//

import Foundation

import JobsSwiftDSL

public enum JobsEnvelopeStrategy: Sendable {
    case none
    case standard(successCodes: Set<Int>)
}

public struct JobsRequestConfig: Sendable {
    public var baseURL: URL
    public var timeout: TimeInterval
    public var version: String
    public var userScope: String
    public var defaultRetryPolicy: JobsRetryPolicy
    public var decoder: JSONDecoder
    public var logger: JobsLogger
    public var sslPinning: JobsSSLPinning?
    public var traceHeaderKeys: (requestId: String, traceId: String, spanId: String)
    public var envelopeStrategy: JobsEnvelopeStrategy
    public var observer: JobsEventObserver

    public init(
        baseURL: URL,
        timeout: TimeInterval = 30,
        version: String = "v2",
        userScope: String = "default",
        defaultRetryPolicy: JobsRetryPolicy = .default,
        decoder: JSONDecoder = .jobsDefault,
        logger: JobsLogger = JobsLogger(),
        sslPinning: JobsSSLPinning? = nil,
        traceHeaderKeys: (requestId: String, traceId: String, spanId: String) = ("X-Request-ID", "X-Trace-ID", "X-Span-ID"),
        envelopeStrategy: JobsEnvelopeStrategy = .none,
        observer: JobsEventObserver = EmptyEventObserver()
    ) {
        self.baseURL = baseURL
        self.timeout = timeout
        self.version = version
        self.userScope = userScope
        self.defaultRetryPolicy = defaultRetryPolicy
        self.decoder = decoder
        self.logger = logger
        self.sslPinning = sslPinning
        self.traceHeaderKeys = traceHeaderKeys
        self.envelopeStrategy = envelopeStrategy
        self.observer = observer
    }
}

public extension JSONDecoder {
    static var jobsDefault: JSONDecoder {
        let decoder = JSONDecoder.make { _ in }
        decoder.keyDecodingStrategy = .useDefaultKeys
        decoder.byDateDecodingStrategy(.deferredToDate)
        return decoder
    }
}
