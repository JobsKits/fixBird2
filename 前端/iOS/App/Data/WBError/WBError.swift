//
//  WBError.swift
//  RepairWorkbench
//
//  Created by Jobs on 2026年10月15日，星期四.
//

import Foundation

enum WBError: Error, LocalizedError, Equatable {
    case transport(String)
    case server(Int, String, String)
    case invalidResponse(String)
    case unknownWrite(String)
    case stale
    case unavailable(String)

    var errorDescription: String? {
        switch self {
        /// 网络不可达与业务拒绝分开呈现。
        case .transport(let message), .unavailable(let message):
            return message
        /// 按当前枚举分支转换已验证的数据。
        case .server(_, _, let message):
            return message
        /// 按当前枚举分支转换已验证的数据。
        case .invalidResponse(let message):
            return "响应未通过校验：" + message
        /// 按当前枚举分支转换已验证的数据。
        case .unknownWrite(let message):
            return "提交结果未知，请核对后按原意图重试。" + message
        /// 按当前枚举分支转换已验证的数据。
        case .stale:
            return "身份或数据来源已改变，请重新打开当前单据。"
        }
    }

    var isUnauthorized: Bool {
        if case .server(401, _, _) = self {
            return true
        }
        return false
    }

    var isBusinessRejection: Bool {
        if case .server(let status, _, _) = self {
            return [400, 403, 404, 409, 422, 429].contains(status)
        }
        return false
    }
}
