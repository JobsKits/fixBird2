//
//  Collection.swift
//  JobsSwiftStandardLibrary
//
//  Created by Jobs on 2026年5月13日，星期三.
//

#if os(OSX)
import AppKit
#elseif os(iOS) || os(tvOS)
import UIKit
#endif

extension Collection {
    /// 安全读：越界返回 nil，不 crash
     public subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
