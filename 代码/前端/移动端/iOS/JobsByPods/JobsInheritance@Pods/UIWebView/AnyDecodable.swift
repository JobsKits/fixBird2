//
//  AnyDecodable.swift
//  JobsInheritance
//
//  Created by Jobs on 2026年5月13日，星期三.
//

import Foundation
/// 任意 JSON 解码容器（备用）

public struct AnyDecodable: Decodable {
    public let value: Any

    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() {
            value = NSNull()
        } else if let v = try? c.decode(Bool.self) {
            value = v
        } else if let v = try? c.decode(Int.self) {
            value = v
        } else if let v = try? c.decode(Double.self) {
            value = v
        } else if let v = try? c.decode(String.self) {
            value = v
        } else if let v = try? c.decode([AnyDecodable].self) {
            value = v.map { $0.value }
        } else if let v = try? c.decode([String: AnyDecodable].self) {
            value = v.mapValues { $0.value }
        } else {
            throw DecodingError.dataCorruptedError(in: c, debugDescription: "Unsupported JSON")
        }
    }
}
