//
//  String+裁剪.swift
//  JobsByUIKit
//
//  Created by Jobs on 2026年5月13日，星期三.
//

#if os(OSX)
import AppKit
#elseif os(iOS) || os(tvOS)
import UIKit
#endif

// MARK: String 扩展：点语法裁剪 / 校验
extension String {
    /// 去掉首尾空白+换行
    @inlinable
    public var byTrimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
    /// 裁剪后非空则返回自身，否则 nil
    @inlinable
    public var byTrimmedOrNil: String? {
        let s = byTrimmed
        return s.isEmpty ? nil : s
    }
    /// 裁剪后为非空且 scheme 是 http/https
    @inlinable
    public var isNonEmptyHttpURL: Bool {
        let p = byTrimmed.lowercased()
        return !p.isEmpty && (p.hasPrefix("http://") || p.hasPrefix("https://"))
    }
    /// 裁剪后若是 http(s) 则返回字符串，否则 nil
    @inlinable
    public var asHttpURLOrNil: String? {
        isNonEmptyHttpURL ? byTrimmed : nil
    }
}
