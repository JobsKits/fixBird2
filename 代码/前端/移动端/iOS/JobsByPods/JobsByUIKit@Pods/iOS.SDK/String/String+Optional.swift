//
//  String+Optional.swift
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

// MARK: String? 扩展：nil 安全
extension Optional where Wrapped == String {
    @inlinable public var byTrimmedOrNil: String? {
        self?.byTrimmedOrNil
    }
    @inlinable public var isNonEmptyHttpURL: Bool {
        self?.isNonEmptyHttpURL ?? false
    }
    @inlinable public var asHttpURLOrNil: String? {
        self?.asHttpURLOrNil
    }
}
/**
 
     let a: String? = nil
     let b: String? = ""

     a.isNilOrEmpty  // true
     b.isNilOrEmpty  // true
 */
extension Optional where Wrapped == String {
    public var isNilOrEmpty: Bool {
        self?.isEmpty ?? true
    }

    public var hasValue: Bool {
        !(self?.isEmpty ?? true)
    }
    /// 更真实的业务场景（空白也算空）
    public var isBlank: Bool {
        self?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true
    }
}
