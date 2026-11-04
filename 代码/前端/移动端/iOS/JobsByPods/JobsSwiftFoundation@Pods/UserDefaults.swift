//
//  UserDefaults.swift
//  JobsSwiftFoundation
//
//  Created by Jobs on 2026年5月13日，星期三.
//

#if os(OSX)
import AppKit
#elseif os(iOS) || os(tvOS)
import UIKit
#endif

// MARK: 基础类型
extension UserDefaults {
    // MARK: Bool
    public func setBool(_ value: Bool, forKey key: String) {
        set(value, forKey: key)
    }
    public func bool(forKey key: String, default def: Bool = false) -> Bool {
        if object(forKey: key) == nil { return def };return bool(forKey: key)
    }
    // MARK: Int
    public func setInt(_ value: Int, forKey key: String) {
        set(value, forKey: key)
    }
    public func int(forKey key: String, default def: Int = 0) -> Int {
        if object(forKey: key) == nil { return def };return integer(forKey: key)
    }
    // MARK: Double
    public func setDouble(_ value: Double, forKey key: String) {
        set(value, forKey: key)
    }
    public func double(forKey key: String, default def: Double = 0.0) -> Double {
        if object(forKey: key) == nil { return def };return double(forKey: key)
    }
    // MARK: Float
    public func setFloat(_ value: Float, forKey key: String) {
        set(value, forKey: key)
    }
    public func float(forKey key: String, default def: Float = 0.0) -> Float {
        if object(forKey: key) == nil { return def };return float(forKey: key)
    }
    // MARK: String
    public func setString(_ value: String, forKey key: String) {
        set(value, forKey: key)
    }
    public func string(forKey key: String, default def: String = "") -> String {
        return string(forKey: key) ?? def
    }
    // MARK: 无符号整型
    public func setUInt8(_ value: UInt8, forKey key: String) {
        set(Int(value), forKey: key)
    }
    public func uint8(forKey key: String) -> UInt8? {
        guard let i = object(forKey: key) as? Int, (0...255).contains(i) else { return nil };return UInt8(i)
    }
    public func setUInt16(_ value: UInt16, forKey key: String) {
        set(Int(value), forKey: key)
    }
    public func uint16(forKey key: String) -> UInt16? {
        guard let i = object(forKey: key) as? Int, (0...65535).contains(i) else { return nil };return UInt16(i)
    }
    public func setUInt32(_ value: UInt32, forKey key: String) {
        set(Int(value), forKey: key)
    }
    public func uint32(forKey key: String) -> UInt32? {
        guard let i = object(forKey: key) as? Int else {
            return nil
        }
        return UInt32(exactly: i)
    }

    public func setUInt64(_ value: UInt64, forKey key: String) {
        set(value.description, forKey: key) // 64 位太大，用字符串安全存
    }
    public func uint64(forKey key: String) -> UInt64? {
        guard let s = string(forKey: key), let v = UInt64(s) else { return nil };return v
    }
    // MARK: 日期 / 数据
    public func setDate(_ date: Date, forKey key: String) {
        set(date.timeIntervalSince1970, forKey: key)
    }
    public func date(forKey key: String) -> Date? {
        let t = double(forKey: key)
        return t > 0 ? Date(timeIntervalSince1970: t) : nil
    }
    public func setData(_ data: Data, forKey key: String) {
        set(data, forKey: key)
    }
    public func getData(forKey key: String) -> Data? {
        return self.data(forKey: key)
    }
    // MARK: Codable 类型
    public func setCodable<T: Codable>(_ value: T, forKey key: String) {
        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(value) {
            set(encoded, forKey: key)
        }
    }
    public func codable<T: Codable>(_ type: T.Type, forKey key: String) -> T? {
        guard let data = data(forKey: key) else { return nil };return try? JSONDecoder().decode(T.self, from: data)
    }
    // MARK: 数组 / 字典
    public func setArray<T: Codable>(_ array: [T], forKey key: String) {
        setCodable(array, forKey: key)
    }
    public func array<T: Codable>(of type: T.Type, forKey key: String) -> [T]? {
        return codable([T].self, forKey: key)
    }

    public func setDictionary<K: Codable, V: Codable>(_ dict: [K: V], forKey key: String) {
        setCodable(dict, forKey: key)
    }
    public func dictionary<K: Codable, V: Codable>(ofKey k: K.Type, value v: V.Type, forKey key: String) -> [K: V]? {
        return codable([K: V].self, forKey: key)
    }
}
// MARK: 通用工具
extension UserDefaults {
    /// 读取：从 模型 解一个 Codable 类型
    public func load<T: Decodable>(_ type: T.Type, forKey key: String) -> T? {
        guard let data = data(forKey: key) else { return nil }
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            print("读取失败：\(error)")
            return nil
        }
    }
    /// 写入：把 Codable 编码存进去
    public func save<T: Encodable>(_ value: T, forKey key: String) {
        do {
            let data = try JSONEncoder().encode(value)
            set(data, forKey: key)
            synchronize()
        } catch {
            print("保存失败：\(error)")
        }
    }

    public func exists(_ key: String) -> Bool {
        return object(forKey: key) != nil
    }

    @discardableResult
    public func removeBy(_ key: String) -> UserDefaults{
        removeObject(forKey: key)
        synchronize()
        return self
    }

    @discardableResult
    public func clean(_ key: String) -> UserDefaults {
        removeObject(forKey: key)
        synchronize()
        return self
    }

    @discardableResult
    public func clearAll() -> UserDefaults {
        for (k, _) in dictionaryRepresentation() {
            removeObject(forKey: k)
        };synchronize()
        return self
    }
}
