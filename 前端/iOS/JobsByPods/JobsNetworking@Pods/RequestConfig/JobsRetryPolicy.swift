//
//  JobsRetryPolicy.swift
//  JobsNetworking
//
//  Created by Jobs on 2026年5月13日，星期三.
//

import Foundation

public enum JobsRetryCategory: Sendable {
    case transport
    case serverSide
    case doNotRetry
}

public struct JobsRetryDecision: Sendable {
    public let shouldRetry: Bool
    public let delay: TimeInterval

    public init(shouldRetry: Bool, delay: TimeInterval = 0) {
        self.shouldRetry = shouldRetry
        self.delay = delay
    }
}

public struct JobsRetryContext: Sendable {
    public let request: JobsRequest
    public let attempt: Int
    public let error: JobsError

    public init(request: JobsRequest, attempt: Int, error: JobsError) {
        self.request = request
        self.attempt = attempt
        self.error = error
    }
}

public struct JobsRetryPolicy: Sendable {
    public var maxRetries: Int
    public var initialDelay: TimeInterval
    public var multiplier: Double
    public var jitter: ClosedRange<Double>
    public var retriableMethods: Set<HTTPMethod>
    public var retriableStatusCodes: Set<Int>
    public var customDecider: (@Sendable (JobsRetryContext) -> JobsRetryDecision)?

    public init(
        maxRetries: Int,
        initialDelay: TimeInterval,
        multiplier: Double,
        jitter: ClosedRange<Double> = 0.8...1.2,
        retriableMethods: Set<HTTPMethod> = [.get, .head, .put, .delete],
        retriableStatusCodes: Set<Int> = Set(500...599),
        customDecider: (@Sendable (JobsRetryContext) -> JobsRetryDecision)? = nil
    ) {
        self.maxRetries = maxRetries
        self.initialDelay = initialDelay
        self.multiplier = multiplier
        self.jitter = jitter
        self.retriableMethods = retriableMethods
        self.retriableStatusCodes = retriableStatusCodes
        self.customDecider = customDecider
    }

    public func decision(for context: JobsRetryContext) -> JobsRetryDecision {
        guard !context.error.isCancelled, context.attempt >= 0,
              context.attempt < min(100, max(0, maxRetries)) else {
            return .init(shouldRetry: false)
        }
        if let customDecider {
            let decision = customDecider(context)
            return .init(shouldRetry: decision.shouldRetry,
                         delay: decision.delay.isFinite ? min(86_400, max(0, decision.delay)) : 0)
        }
        guard context.attempt < maxRetries else {
            return .init(shouldRetry: false)
        }
        guard retriableMethods.contains(context.request.method) else {
            return .init(shouldRetry: false)
        }
        switch context.error {
        /// 合并处理 .http、.server 分支
        case let .http(statusCode, _), let .server(statusCode, _):
            guard retriableStatusCodes.contains(statusCode) else {
                return .init(shouldRetry: false)
            }
        /// 处理 .transport 分支
        case .transport:
            break
        /// 未匹配已知分支时执行兜底处理
        default:
            guard context.error.retryCategory != .doNotRetry else {
                return .init(shouldRetry: false)
            }
        }
        let base = initialDelay.isFinite ? max(0, min(initialDelay, 86_400)) : 0.25
        let growth = multiplier.isFinite ? min(100, max(1, multiplier)) : 2
        let lower = jitter.lowerBound.isFinite ? max(0, min(100, jitter.lowerBound)) : 0.8
        let upper = jitter.upperBound.isFinite ? max(lower, min(100, jitter.upperBound)) : max(lower, 1.2)
        let factor = pow(growth, Double(context.attempt))
        let jitterValue = Double.random(in: lower...upper)
        return .init(shouldRetry: true, delay: min(86_400, base * factor * jitterValue))
    }

    public static let `default` = JobsRetryPolicy(maxRetries: 2, initialDelay: 0.25, multiplier: 2.0)
}
