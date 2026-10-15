//
//  JSONDecoder.swift
//  JobsSwiftFoundation
//
//  Created by Jobs on 2026年5月13日，星期三.
//

import Foundation

public extension JSONDecoder {
    // MARK: - DateDecodingStrategy
    /// 统一入口：直接设置日期解码策略
    @discardableResult
    func byDateDecodingStrategy(_ strategy: DateDecodingStrategy) -> Self {
        dateDecodingStrategy = strategy
        return self
    }
    /// 使用 `Date` 自己的解码（默认）
    @discardableResult
    func byDateDeferredToDate() -> Self {
        dateDecodingStrategy = .deferredToDate
        return self
    }
    /// 使用秒级时间戳
    @discardableResult
    func byDateSecondsSince1970() -> Self {
        dateDecodingStrategy = .secondsSince1970
        return self
    }
    /// 使用毫秒级时间戳
    @discardableResult
    func byDateMillisecondsSince1970() -> Self {
        dateDecodingStrategy = .millisecondsSince1970
        return self
    }
    /// 使用 ISO8601（RFC 3339）
    @available(macOS 10.12, iOS 10.0, watchOS 3.0, tvOS 10.0, *)
    @discardableResult
    func byDateISO8601() -> Self {
        dateDecodingStrategy = .iso8601
        return self
    }
    /// 使用自定义 DateFormatter
    @discardableResult
    func byDateFormatted(_ formatter: DateFormatter) -> Self {
        dateDecodingStrategy = .formatted(formatter)
        return self
    }
    /// 使用自定义解码闭包
    @discardableResult
    func byDateCustom(_ closure: @escaping @Sendable (_ decoder: any Decoder) throws -> Date) -> Self {
        dateDecodingStrategy = .custom(closure)
        return self
    }
    // MARK: - DataDecodingStrategy
    /// 统一入口：直接设置 Data 解码策略
    @discardableResult
    func byDataStrategy(_ strategy: DataDecodingStrategy) -> Self {
        dataDecodingStrategy = strategy
        return self
    }
    /// 使用 `Data` 自己的解码
    @discardableResult
    func byDataDeferredToData() -> Self {
        dataDecodingStrategy = .deferredToData
        return self
    }
    /// 使用 Base64 字符串（默认）
    @discardableResult
    func byDataBase64() -> Self {
        dataDecodingStrategy = .base64
        return self
    }
    /// 使用自定义 Data 解码
    @discardableResult
    func byDataCustom(_ closure: @escaping @Sendable (_ decoder: any Decoder) throws -> Data) -> Self {
        dataDecodingStrategy = .custom(closure)
        return self
    }
    // MARK: - NonConformingFloatDecodingStrategy
    /// 统一入口：设置非规范浮点数解码策略
    @discardableResult
    func byNonConformingFloatStrategy(_ strategy: NonConformingFloatDecodingStrategy) -> Self {
        nonConformingFloatDecodingStrategy = strategy
        return self
    }
    /// 非规范值一律抛错（默认）
    @discardableResult
    func byNonConformingFloatThrow() -> Self {
        nonConformingFloatDecodingStrategy = .throw
        return self
    }
    /// 用字符串表示来解非规范浮点数
    @discardableResult
    func byNonConformingFloatFromString(
        positiveInfinity: String = "Infinity",
        negativeInfinity: String = "-Infinity",
        nan: String = "NaN"
    ) -> Self {
        nonConformingFloatDecodingStrategy = .convertFromString(
            positiveInfinity: positiveInfinity,
            negativeInfinity: negativeInfinity,
            nan: nan
        );return self
    }
    // MARK: - KeyDecodingStrategy
    /// 统一入口：设置 key 解码策略
    @discardableResult
    func bykeyDecodingStrategy(_ strategy: KeyDecodingStrategy) -> Self {
        keyDecodingStrategy = strategy
        return self
    }
    /// 使用类型里声明的 CodingKeys（默认）
    @discardableResult
    func byKeyUseDefault() -> Self {
        keyDecodingStrategy = .useDefaultKeys
        return self
    }
    /// 从 `snake_case` 转成 `camelCase`
    @discardableResult
    func byKeyConvertFromSnakeCase() -> Self {
        keyDecodingStrategy = .convertFromSnakeCase
        return self
    }
    /// 自定义 key 转换
    @discardableResult
    func byKeyCustom(_ closure: @escaping @Sendable (_ codingPath: [any CodingKey]) -> any CodingKey) -> Self {
        keyDecodingStrategy = .custom(closure)
        return self
    }
    // MARK: - userInfo
    /// 一次性设置一批 userInfo
    @discardableResult
    func byUserInfo(_ dict: [CodingUserInfoKey: any Sendable]) -> Self {
        dict.forEach { key, value in
            userInfo[key] = value
        };return self
    }
    /// 设置单个 userInfo
    @discardableResult
    func byUserInfo(_ key: CodingUserInfoKey, _ value: any Sendable) -> Self {
        userInfo[key] = value
        return self
    }
    // MARK: - JSON5 / Top-level dictionary
    @available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
    @discardableResult
    func byAllowsJSON5(_ enabled: Bool = true) -> Self {
        allowsJSON5 = enabled
        return self
    }

    @available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
    @discardableResult
    func byAssumesTopLevelDictionary(_ enabled: Bool = true) -> Self {
        assumesTopLevelDictionary = enabled
        return self
    }
    // MARK: - 预设组合（可按自己口味改名）
    /// 典型 REST JSON 预设：snake_case + ISO8601 日期
    @available(macOS 10.12, iOS 10.0, watchOS 3.0, tvOS 10.0, *)
    static func jobsRESTDecoder() -> JSONDecoder {
        JSONDecoder()
            .byKeyConvertFromSnakeCase()
            .byDateISO8601()
    }
    /// JSON5 + 顶层字典（比如有些配置文件）
    @available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
    static func jobsJSON5ConfigDecoder() -> JSONDecoder {
        JSONDecoder()
            .byAllowsJSON5(true)
            .byAssumesTopLevelDictionary(true)
    }
}
