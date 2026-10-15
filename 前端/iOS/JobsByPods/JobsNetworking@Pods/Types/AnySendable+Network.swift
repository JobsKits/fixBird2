//
//  AnySendable+Network.swift
//  JobsNetworking
//
//  Created by Jobs on 2026年5月13日，星期三.
//

import Foundation

public extension JobsValue {
    func stringValueForNetwork() -> String {
        Self.stringify(raw)
    }

    private static func stringify(_ value: Any?) -> String {
        guard let value else { return "nil" }
        switch value {
        /// 处理 String 类型分支
        case let value as String:
            return value
        /// 处理 NSNumber 类型分支
        case let value as NSNumber:
            return value.stringValue
        /// 处理 URL 类型分支
        case let value as URL:
            return value.absoluteString
        /// 处理 Date 类型分支
        case let value as Date:
            return ISO8601DateFormatter().string(from: value)
        /// 处理 Data 类型分支
        case let value as Data:
            return value.base64EncodedString()
        /// 处理 [String: JobsValue] 类型分支
        case let value as [String: JobsValue]:
            return value
                .sorted { $0.key < $1.key }
                .map { "\($0.key):\(stringify($0.value.raw))" }
                .joined(separator: ",")
        /// 处理 [String: Any] 类型分支
        case let value as [String: Any]:
            return value
                .sorted { $0.key < $1.key }
                .map { "\($0.key):\(stringify($0.value))" }
                .joined(separator: ",")
        /// 处理 [JobsValue] 类型分支
        case let value as [JobsValue]:
            return value.map { stringify($0.raw) }.joined(separator: ",")
        /// 处理 [Any] 类型分支
        case let value as [Any]:
            return value.map { stringify($0) }.joined(separator: ",")
        /// 未匹配已知分支时执行兜底处理
        default:
            return String(describing: value)
        }
    }
}
