//
//  String+格式转换.swift
//  JobsByUIKit
//
//  Created by Jobs on 2026年5月13日，星期三.
//

#if os(OSX)
import AppKit
#elseif os(iOS) || os(tvOS)
import UIKit
#endif

import JobsSwiftDSL

// MARK: 字符串相关格式的（通用）转换
extension String {
    /// String 转 Int
    public func intValue() -> Int? {
        guard let num = NumberFormatter().number(from: self) else {
            return nil
        };return num.intValue
    }

    public func toInt() -> Int {
        return Int(self) ?? 0
    }
    /// String 转 Int64
    public func toInt64() -> Int64? {
        guard let num = NumberFormatter().number(from: self) else {
            return nil
        };return num.int64Value
    }
    /// String 转 Double
    public func toDouble() -> Double? {
        let formatter = NumberFormatter()
            .byLocale(Locale(identifier: "en_US_POSIX")) // 固定使用 . 作为小数点
            .byNumberStyle(.decimal)
            .byGroupingSeparator(",")                   // 千分位逗号
            .byDecimalSeparator(".")                    // 小数点 .
        return formatter.number(from: self.trimmingCharacters(in: .whitespacesAndNewlines))?.doubleValue
    }
    /// String 转 Double
    public func toDouble(_ max: Int, _ min: Int) -> Double? {
        let format = NumberFormatter()
            .byMaximumFractionDigits(max)
            .byMinimumFractionDigits(min)
        guard let num = format.number(from: self) else {
            return nil
        };return num.doubleValue
    }
    /// String 转 Float
    public func toFloat() -> Float? {
        guard let num = NumberFormatter().number(from: self) else {
            return nil
        };return num.floatValue
    }
    /// String 转 Bool
    public func toBool() -> Bool? {
        let trimmedString = self
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        switch trimmedString {
        /// 合并处理 "true"、"yes"、"1" 分支
        case "true", "yes", "1":
            return true
        /// 合并处理 "false"、"no"、"0" 分支
        case "false", "no", "0":
            return false
        /// 未匹配已知分支时执行兜底处理
        default:
            return nil
        }
    }
    /// String 转 NSString
    public var toNSString: NSString {
        return self as NSString
    }
    /// String 转 NSAttributedString
    /// 转富文本（默认空属性）
    public var rich: NSAttributedString {
        NSAttributedString(string: self)
    }
    /// 转富文本并附加属性
    public func rich(_ attrs: [NSAttributedString.Key: Any]) -> NSAttributedString {
        NSAttributedString(string: self, attributes: attrs)
    }
}
