//
//  BaseWebView+Utils.swift
//  JobsInheritance
//
//  Created by Jobs on 2026年5月13日，星期三.
//

#if os(OSX)
import AppKit
#elseif os(iOS) || os(tvOS)
import UIKit
#endif

import WebKit

extension BaseWebView {
    public static func quote(_ s: String) -> String {
        let escaped = s
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
        return "\"\(escaped)\""
    }

    public static func toJSONLiteral(_ value: Any?) -> String {
        guard let value else { return "null" }
        switch value {
        /// 处理 NSNull 类型分支
        case is NSNull: return "null"
        /// 处理 String 类型分支
        case let s as String: return quote(s)
        /// 处理 Bool 类型分支
        case let b as Bool: return b ? "true" : "false"
        /// 处理 Int 类型分支
        case let i as Int: return "\(i)"
        /// 处理 Int64 类型分支
        case let i64 as Int64: return "\(i64)"
        /// 处理 UInt64 类型分支
        case let u64 as UInt64: return "\(u64)"
        /// 处理 Double 类型分支
        case let d as Double: return d.isFinite ? "\(d)" : "null"
        /// 处理 Float 类型分支
        case let f as Float: return f.isFinite ? "\(f)" : "null"
        /// 处理 Decimal 类型分支
        case let dec as Decimal: return NSDecimalNumber(decimal: dec).stringValue
        /// 处理 Date 类型分支
        case let date as Date:
            let iso = ISO8601DateFormatter()
            return quote(iso.string(from: date))
        /// 处理 [Any] 类型分支
        case let arr as [Any]:
            return "[\(arr.map { toJSONLiteral($0) }.joined(separator: ","))]"
        /// 处理 [String: Any] 类型分支
        case let dict as [String: Any]:
            let body = dict.map { key, val in "\(quote(key)):\(toJSONLiteral(val))" }.joined(separator: ",")
            return "{\(body)}"
        /// 未匹配已知分支时执行兜底处理
        default:
            if JSONSerialization.isValidJSONObject(value),
               let data = try? JSONSerialization.data(withJSONObject: value, options: []),
               let s = String(data: data, encoding: .utf8) {
                return s
            };return quote("\(value)")
        }
    }

    public static func decodeJSResult<T: Decodable>(_ value: Any?,
                                                    as type: T.Type,
                                                    decoder: JSONDecoder) throws -> T {
        if T.self == String.self, let v = value as? String { return v as! T }
        if T.self == Bool.self, let v = value as? Bool { return v as! T }
        if T.self == Int.self, let v = value as? Int { return v as! T }
        if T.self == Double.self, let v = value as? Double { return v as! T }
        if T.self == Float.self, let v = value as? Float { return v as! T }
        if value == nil || value is NSNull {
            throw NSError(domain: "BaseWebView", code: -2, userInfo: [NSLocalizedDescriptionKey: "JS returned null"])
        }
        if JSONSerialization.isValidJSONObject(value ?? NSNull()) {
            let data = try JSONSerialization.data(withJSONObject: value!, options: [])
            return try decoder.decode(T.self, from: data)
        }
        if let s = value as? String, let data = s.data(using: .utf8) {
            let first = s.trimmingCharacters(in: .whitespacesAndNewlines).first
            if let f = first, ["{", "["].contains(f) {
                return try decoder.decode(T.self, from: data)
            }
        }
        let fallback = "\(value!)"
        if let data = fallback.data(using: .utf8) {
            let first = fallback.trimmingCharacters(in: .whitespacesAndNewlines).first
            if let f = first,
               ["{", "[", "\"", "0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "t", "f", "n"].contains(f),
               let decoded = try? decoder.decode(T.self, from: data) {
                return decoded
            }
        }
        throw NSError(domain: "BaseWebView",
                      code: -3,
                      userInfo: [NSLocalizedDescriptionKey: "Cannot decode JS result to \(T.self) – raw: \(String(describing: value))"])
    }
}
// MARK: - Private helpers
extension BaseWebView {
    func normalizeSuffix(_ s: String?) -> String? {
        guard let t = s?.trimmingCharacters(in: .whitespacesAndNewlines), !t.isEmpty else { return nil };return t
    }

    func nearestViewController() -> UIViewController? {
        var r: UIResponder? = self
        while let n = r?.next {
            if let vc = n as? UIViewController { return vc }
            r = n
        };return nil
    }
    // 统一构造“无缓存”请求
    func makeNoCache(_ original: URLRequest) -> URLRequest {
        var req = original
        req.cachePolicy = .reloadIgnoringLocalCacheData
        var headers = req.allHTTPHeaderFields ?? [:]
        headers[Self.noCacheHeader] = "1" // 打标，防止在 decidePolicyFor 被我们再次拦截造成死循环
        if headers["Cache-Control"] == nil {
            headers["Cache-Control"] = "no-cache, no-store, max-age=0, must-revalidate"
        }
        if headers["Pragma"] == nil {
            headers["Pragma"] = "no-cache"
        }
        if headers["Expires"] == nil {
            headers["Expires"] = "0"
        }
        req.allHTTPHeaderFields = headers
        return req
    }
}
