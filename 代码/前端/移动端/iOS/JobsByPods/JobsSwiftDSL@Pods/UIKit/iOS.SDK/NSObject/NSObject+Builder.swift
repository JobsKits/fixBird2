//
//  NSObject+Builder.swift
//  JobsByUIKit
//
//  Created by Jobs on 2026年5月13日，星期三.
//

import Foundation

extension NSObject {
    /// 可选值构建：builder 返回 nil 时跳过设置
    @discardableResult
    func _byApplyOptional<Value>(
        _ builder: () -> Value?,
        setter: (Value) -> Void
    ) -> Self {
        if let value = builder() {
            setter(value)
        };return self
    }
    /// 非可选值构建：一定会执行设置
    @discardableResult
    func _byApplyValue<Value>(
        _ builder: () -> Value,
        setter: (Value) -> Void
    ) -> Self {
        setter(builder())
        return self
    }
}
