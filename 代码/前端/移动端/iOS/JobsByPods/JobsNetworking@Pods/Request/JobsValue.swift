//
//  JobsValue.swift
//  JobsNetworking
//
//  Created by Jobs on 2026年5月13日，星期三.
//

import Foundation
import CoreFoundation

/// 创建时快照为不可变 JSON 树；不会跨执行上下文保留任意 Any 引用。
public struct JobsValue: Sendable {
    private let value: JSONValue
    public var raw: Any? {
        if case .null = value { return nil }
        return value.object
    }
    public var validationError: String? { value.validationError }

    public init(_ raw: Any?) {
        value = JSONValue.snapshot(raw, depth: 0)
    }

    private indirect enum JSONValue: Sendable {
        case null
        case boolean(Bool)
        case number(String, floating: Bool)
        case string(String)
        case array([JSONValue])
        case object([String: JSONValue])
        case invalid(String)

        static func snapshot(_ raw: Any?, depth: Int) -> Self {
            guard depth <= 64 else { return .invalid("JSON nesting exceeds 64 levels") }
            guard let raw else { return .null }
            switch raw {
            case let value as JobsValue:
                return value.value
            case is NSNull:
                return .null
            case let value as String:
                return .string(value)
            case let value as NSNumber:
                if CFGetTypeID(value) == CFBooleanGetTypeID() { return .boolean(value.boolValue) }
                guard value.doubleValue.isFinite else { return .invalid("JSON number must be finite") }
                return .number(value.stringValue, floating: !(value is NSDecimalNumber) && ["f", "d"].contains(String(cString: value.objCType)))
            case let value as [String: JobsValue]:
                return .object(value.mapValues { $0.value })
            case let value as [String: Any]:
                return .object(value.mapValues { snapshot($0, depth: depth + 1) })
            case let value as [JobsValue]:
                return .array(value.map { $0.value })
            case let value as [Any]:
                return .array(value.map { snapshot($0, depth: depth + 1) })
            case let value as URL:
                return .string(value.absoluteString)
            case let value as Date:
                guard value.timeIntervalSince1970.isFinite else { return .invalid("JSON date must be finite") }
                return .string(ISO8601DateFormatter().string(from: value))
            case let value as Data:
                return .string(value.base64EncodedString())
            default:
                return .invalid("Unsupported JSON value type: \(type(of: raw))")
            }
        }

        var object: Any {
            switch self {
            case .null, .invalid:
                return NSNull()
            case .boolean(let value):
                return value
            case .number(let value, let floating):
                if floating, let number = Double(value) { return NSNumber(value: number) }
                return NSDecimalNumber(string: value, locale: Locale(identifier: "en_US_POSIX"))
            case .string(let value):
                return value
            case .array(let values):
                return values.map { $0.object }
            case .object(let values):
                return values.mapValues { $0.object }
            }
        }

        var validationError: String? {
            switch self {
            case .invalid(let reason):
                return reason
            case .array(let values):
                return values.compactMap { $0.validationError }.first
            case .object(let values):
                return values.keys.sorted().compactMap { values[$0]?.validationError }.first
            default:
                return nil
            }
        }
    }
}

@available(*, deprecated, renamed: "JobsValue")
public typealias AnySendable = JobsValue

public extension Dictionary where Key == String, Value == JobsValue {
    func normalizedJSONObject() -> [String: Any] {
        mapValues { JobsValueNormalizer.normalize($0.raw) }
    }
}

enum JobsValueNormalizer {
    static func normalize(_ value: Any?) -> Any {
        JobsValue(value).raw ?? NSNull()
    }
}
