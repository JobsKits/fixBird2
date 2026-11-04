//
//  JobsCacheKey.swift
//  JobsNetworking
//
//  Created by Jobs on 2026年5月13日，星期三.
//

import Foundation
import CommonCrypto

public struct JobsCacheKey: Hashable, Sendable {
    public let raw: String

    public init(raw: String) { self.raw = raw }

    public static func make(
        method: HTTPMethod,
        url: URL,
        query: [String: JobsValue]?,
        body: [String: JobsValue]?,
        version: String,
        userScope: String,
        rawBody: Data? = nil,
        encoding: String = "default",
        headers: [String: String] = [:]
    ) -> JobsCacheKey {
        let object: [String: Any] = [
            "format": 3,
            "method": method.rawValue,
            "url": url.absoluteString,
            "query": query?.normalizedJSONObject() as Any? ?? NSNull(),
            "body": body?.normalizedJSONObject() as Any? ?? NSNull(),
            "rawBody": rawBody?.base64EncodedString() as Any? ?? NSNull(),
            "encoding": encoding,
            "headers": headers,
            "version": version,
            "userScope": userScope
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]) else {
            // 不支持的参数不会复用同一个键；请求层会提前返回参数错误。
            return .init(raw: UUID().uuidString)
        }
        return .init(raw: digest(data))
    }

    static func digest(_ data: Data) -> String {
        var context = CC_SHA256_CTX()
        CC_SHA256_Init(&context)
        data.withUnsafeBytes { buffer in
            var offset = 0
            while offset < data.count {
                let count = min(1_024 * 1_024, data.count - offset)
                _ = CC_SHA256_Update(&context, buffer.baseAddress?.advanced(by: offset), CC_LONG(count))
                offset += count
            }
        }
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        CC_SHA256_Final(&hash, &context)
        return hash.map { String(format: "%02x", $0) }.joined()
    }
}
