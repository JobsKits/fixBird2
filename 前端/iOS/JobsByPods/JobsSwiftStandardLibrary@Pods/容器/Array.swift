//
//  Array.swift
//  JobsSwiftStandardLibrary
//
//  Created by Jobs on 2026年5月13日，星期三.
//

#if os(OSX)
import AppKit
#elseif os(iOS) || os(tvOS)
import UIKit
#endif

import ObjectiveC

extension Array {
    /// 不改原数组，返回一个新数组
    @discardableResult
    public func add(_ element: Element) -> [Element] {
        var copy = self
        copy.append(element)
        return copy
    }
    /// 改原数组
    public mutating func addBy(_ element: Element) {
        append(element)
    }
}
/**
 
     lazy var titles: [String] = .build { arr in
         arr.addBy("1".tr)
         .addBy("2".tr)
         .addBy("3".tr)
         .addBy("4".tr)
         .addBy("5".tr)
     }
 */
public extension Array {
    /// 链式构建器：在闭包里支持 .addBy(...).addBy(...)
    struct Builder {
        fileprivate final class Storage {
            var elements: [Element] = []
        }
        fileprivate let storage: Storage
        @discardableResult
        public func addBy(_ element: Element) -> Builder {
            storage.elements.append(element)
            return self
        }
    }
    /// 使用方式：lazy var titles: [String] = .build { $0.addBy(...).addBy(...) }
    static func build(_ block: (Builder) -> Void) -> [Element] {
        let storage = Builder.Storage()
        block(Builder(storage: storage))
        return storage.elements
    }
}
