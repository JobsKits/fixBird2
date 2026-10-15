//
//  Dictionary.swift
//  JobsSwiftStandardLibrary
//
//  Created by Jobs on 2026年5月13日，星期三.
//

#if os(OSX)
import AppKit
#elseif os(iOS) || os(tvOS)
import UIKit
#endif

extension Dictionary {
    /// 语义化安全读：其实就是 self[key]
    public subscript(safe key: Key) -> Value? {
        self[key]      // 这里会调用标准库原来的 subscript(key:)
    }
}

extension Dictionary where Key == String {
     public func stringValue(for key: String, default def: String? = nil) -> String? {
        guard let v = self[key] else { return def }
        if let s = v as? String { return s }
        if let n = v as? NSNumber { return n.stringValue }
        if v is NSNull { return def };return String(describing: v)
    }
}
