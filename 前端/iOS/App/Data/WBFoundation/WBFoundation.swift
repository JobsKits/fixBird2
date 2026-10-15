//
//  WBFoundation.swift
//  RepairWorkbench
//
//  Created by Jobs on 2026年10月15日，星期四.
//

import Foundation

#if canImport(JobsSwiftDSL)
    import JobsSwiftDSL
#endif
#if canImport(JobsSwiftBlock)
    import JobsSwiftBlock
#endif

/// 独立 Foundation 合同测试仅替代 SDK 工厂底层，不替代业务或网络行为。
#if !canImport(JobsSwiftDSL)
    extension JSONDecoder {
        fileprivate static func make(_ configure: (JSONDecoder) -> Void) -> JSONDecoder {
            let decoder = JSONDecoder()
            configure(decoder)
            return decoder
        }
    }
#endif

#if !canImport(JobsSwiftBlock)
    extension ISO8601DateFormatter {
        static func jobsMake(_ configure: (ISO8601DateFormatter) -> Void) -> ISO8601DateFormatter {
            let formatter = ISO8601DateFormatter()
            configure(formatter)
            return formatter
        }
    }

    extension NSNull {
        static func jobsMake(_ configure: (NSNull) -> Void) -> NSNull {
            let value = NSNull()
            configure(value)
            return value
        }
    }
#endif

enum WBFoundation {
    static func decode(_ data: Data) throws -> WBJSON {
        try JSONDecoder.make {
            _ in
        }.decode(WBJSON.self, from: data)
    }

    static func json(_ object: [String: Any]) throws -> WBJSON {
        try decode(JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]))
    }

    static func data(_ object: [String: Any]) throws -> Data {
        try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    }

    static func now() -> String {
        ISO8601DateFormatter.jobsMake {
            _ in
        }.string(from: Date())
    }

    static func validDate(_ value: String) -> Bool {
        value.isEmpty
            || ISO8601DateFormatter.jobsMake {
                _ in
            }.date(from: value) != nil
    }

    static func amount(_ cents: Int64) -> String {
        let magnitude = cents.magnitude
        let fraction = magnitude % 100
        let sign = cents < 0 ? "−" : ""
        let padding = fraction < 10 ? "0" : ""
        return "¥" + sign + String(magnitude / 100) + "." + padding + String(fraction)
    }
}
