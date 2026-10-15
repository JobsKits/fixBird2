//
//  NSObject+万物回调.swift
//  JobsByUIKit
//
//  Created by Jobs on 2026年5月13日，星期三.
//

#if os(OSX)
import AppKit
#elseif os(iOS) || os(tvOS)
import UIKit
#endif

import ObjectiveC
import JobsSwiftBlock
/// 以 JobsSwiftBlock 为基础参考，此文件只封装最具备代表性的基座Block

// MARK: () -> Void
/**
 
     用法：
 
     1）设置
     obj.jobsByVoidCallback {
         print("点击了")
     }

     2）执行
     obj.jobsValueVoidCallback()

     3）移除
     obj.jobsRemoveVoidCallback()
 */
private var JobsVoidCallbackKey: UInt8 = 0
extension NSObject {
    /// 设置统一 Void 回调
    @discardableResult
    public func jobsByVoidCallback(_ block: @escaping jobsByVoidBlock) -> Self {
        objc_setAssociatedObject(
            self,
            &JobsVoidCallbackKey,
            block,
            .OBJC_ASSOCIATION_COPY_NONATOMIC
        );return self
    }
    /// 执行统一 Void 回调
    public func jobsValueVoidCallback() {
        jobsVoidCallback?()
    }
    /// 清空统一 Void 回调
    @discardableResult
    public func jobsRemoveVoidCallback() -> Self {
        objc_setAssociatedObject(
            self,
            &JobsVoidCallbackKey,
            nil,
            .OBJC_ASSOCIATION_COPY_NONATOMIC
        );return self
    }
    /// 读取统一 Void 回调
    public var jobsVoidCallback: jobsByVoidBlock? {
        objc_getAssociatedObject(self, &JobsVoidCallbackKey) as? jobsByVoidBlock
    }
}
// MARK: (Any) -> Void
/**
 
     用法：

     1）设置
     obj.jobsByAnyVoidCallback { value in
         print("收到参数：\(value)")
     }

     2）执行
     obj.jobsValueAnyVoidCallback("hello")
     obj.jobsValueAnyVoidCallback(123)
     obj.jobsValueAnyVoidCallback(["name": "Jobs"])

     3）移除
     obj.jobsRemoveAnyVoidCallback()
 */
private var JobsAnyVoidCallbackKey: UInt8 = 0
extension NSObject {
    /// 设置统一单入参回调（入参1个，不规定类型）
    @discardableResult
    public func jobsByAnyVoidCallback(_ block: @escaping jobsByAnyVoidBlock) -> Self {
        objc_setAssociatedObject(
            self,
            &JobsAnyVoidCallbackKey,
            block,
            .OBJC_ASSOCIATION_COPY_NONATOMIC
        );return self
    }
    /// 执行统一单入参回调（入参1个，不规定类型）
    public func jobsValueAnyVoidCallback(_ value: Any) {
        jobsAnyVoidCallback?(value)
    }
    /// 清空统一单入参回调
    @discardableResult
    public func jobsRemoveAnyVoidCallback() -> Self {
        objc_setAssociatedObject(
            self,
            &JobsAnyVoidCallbackKey,
            nil,
            .OBJC_ASSOCIATION_COPY_NONATOMIC
        );return self
    }
    /// 读取统一单入参回调
    public var jobsAnyVoidCallback: jobsByAnyVoidBlock? {
        objc_getAssociatedObject(self, &JobsAnyVoidCallbackKey) as? jobsByAnyVoidBlock
    }
}
// MARK: ([Any]) -> Void
/**
 
     用法：

     1）设置
     obj.jobsByAnyArgsVoidCallback { values in
         print("收到多个参数：\(values)")
     }

     2）执行（可变参数版）
     obj.jobsValueAnyArgsVoidCallback("A", 1, true)

     3）执行（数组版）
     obj.jobsValueAnyArgsVoidCallback(["A", 1, true])

     4）移除
     obj.jobsRemoveAnyArgsVoidCallback()
 */
private var JobsAnyArgsVoidCallbackKey: UInt8 = 0
extension NSObject {
    /// 设置统一多入参回调（入参任意，不定参数）
    @discardableResult
    public func jobsByAnyArgsVoidCallback(_ block: @escaping jobsByAnyArgsVoidBlock) -> Self {
        objc_setAssociatedObject(
            self,
            &JobsAnyArgsVoidCallbackKey,
            block,
            .OBJC_ASSOCIATION_COPY_NONATOMIC
        );return self
    }
    /// 执行统一多入参回调（可变参数版）
    public func jobsValueAnyArgsVoidCallback(_ values: Any...) {
        jobsAnyArgsVoidCallback?(values)
    }
    /// 执行统一多入参回调（数组版）
    public func jobsValueAnyArgsVoidCallback(_ values: [Any]) {
        jobsAnyArgsVoidCallback?(values)
    }
    /// 清空统一多入参回调
    @discardableResult
    public func jobsRemoveAnyArgsVoidCallback() -> Self {
        objc_setAssociatedObject(
            self,
            &JobsAnyArgsVoidCallbackKey,
            nil,
            .OBJC_ASSOCIATION_COPY_NONATOMIC
        );return self
    }
    /// 读取统一多入参回调
    public var jobsAnyArgsVoidCallback: jobsByAnyArgsVoidBlock? {
        objc_getAssociatedObject(self, &JobsAnyArgsVoidCallbackKey) as? jobsByAnyArgsVoidBlock
    }
}
// MARK: - (Any) -> Any
/**
 
     用法：

     1）设置 Int -> Int
     obj.jobsByTransformCallback { (value: Int) in
         value + 1
     }

     let newValue: Int = obj.jobsValueTransformCallback(10)
     print(newValue) // 11

     2）设置 String -> String
     obj.jobsByTransformCallback { (text: String) in
         text.trimmingCharacters(in: .whitespacesAndNewlines)
     }

     let newText: String = obj.jobsValueTransformCallback(" hello ")
     print(newText) // "hello"

     3）移除
     obj.jobsRemoveTransformCallback()

     注意：
     - 同一个对象，这类回调同一时刻只存一份
     - 后设置的会覆盖前设置的
     - 若类型不匹配，直接返回原值
 */
private var JobsTransformCallbackKey: UInt8 = 0
extension NSObject {
    /// 设置统一泛型转换回调（入参1个，类型T；出参1个，类型T）
    @discardableResult
    public func jobsByTransformCallback<T>(_ block: @escaping (T) -> T) -> Self {
        let wrapped: jobsByAnyTransformBlock = { value in
            guard let typedValue = value as? T else { return value };return block(typedValue)
        }
        objc_setAssociatedObject(
            self,
            &JobsTransformCallbackKey,
            wrapped,
            .OBJC_ASSOCIATION_COPY_NONATOMIC
        );return self
    }
    /// 执行统一泛型转换回调（入参1个，类型T；出参1个，类型T）
    public func jobsValueTransformCallback<T>(_ value: T) -> T {
        guard let block = jobsTransformCallback else { return value }
        guard let result = block(value) as? T else { return value };return result
    }
    /// 清空统一泛型转换回调
    @discardableResult
    public func jobsRemoveTransformCallback() -> Self {
        objc_setAssociatedObject(
            self,
            &JobsTransformCallbackKey,
            nil,
            .OBJC_ASSOCIATION_COPY_NONATOMIC
        );return self
    }
    /// 读取统一泛型转换回调（类型擦除后）
    public var jobsTransformCallback: jobsByAnyTransformBlock? {
        objc_getAssociatedObject(self, &JobsTransformCallbackKey) as? jobsByAnyTransformBlock
    }
}
