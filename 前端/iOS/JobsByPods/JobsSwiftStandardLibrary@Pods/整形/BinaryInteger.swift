//
//  BinaryInteger.swift
//  JobsSwiftStandardLibrary
//
//  Created by Jobs on 2026年5月13日，星期三.
//

import Foundation

// MARK: - BinaryInteger 是所有整数类型的“父协议”
extension BinaryInteger {
    /// 纯“分秒版”（不显示小时，超过 3600 秒会折算成分钟）
    /// - 规则：
    ///   - < 60s：仅显示秒（避免 "00分59秒"）
    ///   - >= 60s：显示 "M分SS秒"（分钟不补 0，秒补 2 位）
    ///
    /// 例：
    /// 59  ➤ "59秒"
    /// 60  ➤ "1分00秒"
    /// 62  ➤ "1分02秒"
    /// 300 ➤ "5分00秒"
    /// 3900 ➤ "65分00秒" ✅（不会变成 "1时05分00秒"）
    public var byMinuteSecondCNNoHour: String {
        let total = UInt64(clamping: self)
        let m = total / 60
        let s = total % 60
        if m > 0 { return "\(m)分\((s < 10 ? "0\(s)" : "\(s)"))秒" }
        return "\(s)秒"
    }
    /// 分/秒（需要时显示小时）；分钟“不补 0”，秒补 2 位
    /// - 与 jobsMinuteSecondCN2 的区别：
    ///   - 本方法：分钟不补 0 -> "1分02秒" / "5分00秒"
    ///   - CN2：分钟补 2 位 -> "01分02秒" / "05分00秒"
    ///
    /// 例：
    /// 59   ➤ "59秒"
    /// 62   ➤ "1分02秒"   ✅（分钟不补 0）
    /// 300  ➤ "5分00秒"   ✅（分钟不补 0）
    /// 900  ➤ "15分00秒"
    /// 3900 ➤ "1时05分00秒"
    public var byMinuteSecondCN: String {
        let total = UInt64(clamping: self)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 { return "\(h)时\((m < 10 ? "0\(m)" : "\(m)"))分\((s < 10 ? "0\(s)" : "\(s)"))秒" }
        if m > 0 { return "\(m)分\((s < 10 ? "0\(s)" : "\(s)"))秒" }
        return "\(s)秒"
    }
    /// 分/秒（需要时显示小时）；分钟“补 2 位”，秒补 2 位
    /// - 与 jobsMinuteSecondCN 的区别：
    ///   - CN：分钟不补 0 -> "1分02秒" / "5分00秒"
    ///   - 本方法：分钟补 2 位 -> "01分02秒" / "05分00秒"
    ///
    /// 例：
    /// 59   ➤ "59秒"
    /// 62   ➤ "01分02秒" ✅（分钟补 2 位）
    /// 300  ➤ "05分00秒" ✅（分钟补 2 位）
    /// 900  ➤ "15分00秒"
    /// 3900 ➤ "1时05分00秒"
    public var byMinuteSecondCN2: String {
        let total = UInt64(clamping: self)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 { return "\(h)时\((m < 10 ? "0\(m)" : "\(m)"))分\((s < 10 ? "0\(s)" : "\(s)"))秒" }
        if m > 0 { return "\((m < 10 ? "0\(m)" : "\(m)"))分\((s < 10 ? "0\(s)" : "\(s)"))秒" }
        return "\(s)秒"
    }
}

