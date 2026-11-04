//
//  WBJSON.swift
//  RepairWorkbench
//
//  Created by Jobs on 2026年10月15日，星期四.
//

import Foundation

#if canImport(JobsSwiftBlock)
    import JobsSwiftBlock
#endif

indirect enum WBJSON: Codable, Equatable, Sendable {
    case object([String: WBJSON])
    case array([WBJSON])
    case string(String)
    case integer(Int64)
    case number(Double)
    case boolean(Bool)
    case null

    init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer()
        if value.decodeNil() {
            self = .null
        } else if let result = try? value.decode(Bool.self) {
            self = .boolean(result)
        } else if let result = try? value.decode(Int64.self) {
            self = .integer(result)
        } else if let result = try? value.decode(Double.self), result.isFinite {
            self = .number(result)
        } else if let result = try? value.decode(String.self) {
            self = .string(result)
        } else if let result = try? value.decode([WBJSON].self) {
            self = .array(result)
        } else {
            self = .object(try value.decode([String: WBJSON].self))
        }
    }

    func encode(to encoder: Encoder) throws {
        var value = encoder.singleValueContainer()
        switch self {
        /// 保留 JSON 对象和数组结构。
        case .object(let object):
            try value.encode(object)
        /// 按当前枚举分支转换已验证的数据。
        case .array(let array):
            try value.encode(array)
        /// 整数金额不经浮点转换。
        case .integer(let integer):
            try value.encode(integer)
        /// 按当前枚举分支转换已验证的数据。
        case .number(let number):
            try value.encode(number)
        /// 按当前枚举分支转换已验证的数据。
        case .string(let string):
            try value.encode(string)
        /// 按当前枚举分支转换已验证的数据。
        case .boolean(let boolean):
            try value.encode(boolean)
        /// 按当前枚举分支转换已验证的数据。
        case .null:
            try value.encodeNil()
        }
    }

    var object: [String: WBJSON]? {
        if case .object(let value) = self {
            return value
        }
        return nil
    }

    var array: [WBJSON]? {
        if case .array(let value) = self {
            return value
        }
        return nil
    }

    var string: String? {
        if case .string(let value) = self {
            return value
        }
        return nil
    }

    var integer: Int64? {
        if case .integer(let value) = self {
            return value
        }
        return nil
    }

    var boolean: Bool? {
        if case .boolean(let value) = self {
            return value
        }
        return nil
    }

    var any: Any {
        switch self {
        /// 只向网络封装交付不可变 JSON 值。
        case .object(let value):
            return value.mapValues {
                $0.any
            }
        /// 按当前枚举分支转换已验证的数据。
        case .array(let value):
            return value.map {
                $0.any
            }
        /// 按当前枚举分支转换已验证的数据。
        case .string(let value):
            return value
        /// 按当前枚举分支转换已验证的数据。
        case .integer(let value):
            return value
        /// 按当前枚举分支转换已验证的数据。
        case .number(let value):
            return value
        /// 按当前枚举分支转换已验证的数据。
        case .boolean(let value):
            return value
        /// 按当前枚举分支转换已验证的数据。
        case .null:
            return NSNull.jobsMake {
                _ in
            }
        }
    }
}
