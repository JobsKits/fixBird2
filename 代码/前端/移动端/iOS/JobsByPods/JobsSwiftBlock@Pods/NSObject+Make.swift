//
//  NSObject+Make.swift
//  JobsSwiftBlock
//
//  Created by Jobs on 2026年8月7日，星期五.
//

import Foundation

/// 使用协议的泛型 Self，避免旧编译器在协议调用方生成动态 Self 元数据时崩溃。
public protocol JobsNSObjectMaking: AnyObject {}

extension NSObject: JobsNSObjectMaking {}

public extension JobsNSObjectMaking where Self: NSObject {

    static func jobsMake(_ configure: (Self) -> Void) -> Self {
        let object = self.init()
        configure(object)
        return object
    }
}
