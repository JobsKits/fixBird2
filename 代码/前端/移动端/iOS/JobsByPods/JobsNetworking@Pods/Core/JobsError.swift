//
//  JobsError.swift
//  JobsNetworking
//
//  Created by Jobs on 2026年5月13日，星期三.
//

import Foundation

public enum JobsError: Error, Sendable {
    case http(statusCode: Int, data: Data?)
    case transport(underlying: String)
    case server(statusCode: Int, data: Data?)
    case decode(underlying: String, data: Data?)
    case business(code: Int, message: String, data: Data?)
    case cacheMiss
    case cancelled
    case invalidRequest(reason: String)
    case emptyResponse
    case unknown(underlying: String)
}

public extension JobsError {
    var isCancelled: Bool {
        if case .cancelled = self { return true }
        return false
    }

    var isBusiness: Bool {
        if case .business = self { return true }
        return false
    }

    var retryCategory: JobsRetryCategory {
        switch self {
        /// 处理 .cancelled 分支
        case .cancelled:
            return .doNotRetry
        /// 合并处理 .http、.server 分支
        case let .http(statusCode, _), let .server(statusCode, _):
            return (500...599).contains(statusCode) ? .serverSide : .doNotRetry
        /// 处理 .transport 分支
        case .transport:
            return .transport
        /// 合并处理 .decode、.business、.invalidRequest、.emptyResponse、.cacheMiss、.unknown 分支
        case .decode, .business, .invalidRequest, .emptyResponse, .cacheMiss, .unknown:
            return .doNotRetry
        }
    }
}

extension JobsError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        /// 处理 .http 分支
        case let .http(statusCode, data):
            return "HTTP \(statusCode) \(Self.describe(data))"
        /// 处理 .transport 分支
        case let .transport(underlying):
            return underlying
        /// 处理 .server 分支
        case let .server(statusCode, data):
            return "Server \(statusCode) \(Self.describe(data))"
        /// 处理 .decode 分支
        case let .decode(underlying, data):
            return "Decode failed: \(underlying) \(Self.describe(data))"
        /// 处理 .business 分支
        case let .business(code, message, data):
            return "Business(\(code)): \(message) \(Self.describe(data))"
        /// 处理 .cacheMiss 分支
        case .cacheMiss:
            return "Cache miss"
        /// 处理 .cancelled 分支
        case .cancelled:
            return "Request cancelled"
        /// 处理 .invalidRequest 分支
        case let .invalidRequest(reason):
            return reason
        /// 处理 .emptyResponse 分支
        case .emptyResponse:
            return "Empty response"
        /// 处理 .unknown 分支
        case let .unknown(underlying):
            return underlying
        }
    }

    private static func describe(_ data: Data?) -> String {
        guard let data, !data.isEmpty else { return "<empty>" }
        return "<response \(data.count) bytes>"
    }
}
