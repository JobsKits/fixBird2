//
//  NSObject+Rx.swift
//  JobsByUIKit
//
//  Created by Jobs on 2026年5月13日，星期三.
//

#if os(OSX)
import AppKit
#elseif os(iOS) || os(tvOS)
import UIKit
#endif

#if canImport(NSObject_Rx) && canImport(RxSwift)
import RxSwift
import NSObject_Rx
extension NSObject {
    /// 语法糖：tf.disposeBag 实际转发到 rx.disposeBag
    public var disposeBag: DisposeBag {
        get { rx.disposeBag }
        set {
            var r = rx            // ✅ 拷贝到可变局部
            r.disposeBag = newValue
        }
    }
}
#else
import ObjectiveC
extension NSObject {
    /// 用 UInt8 静态变量做关联对象 key（地址稳定）
    private static var _disposeBagKey: UInt8 = 0

    public var disposeBag: DisposeBag {
        get {
            if let bag = objc_getAssociatedObject(self, &Self._disposeBagKey) as? DisposeBag {
                return bag
            }
            let bag = DisposeBag()
            objc_setAssociatedObject(self, &Self._disposeBagKey, bag, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            return bag
        }
        set {
            objc_setAssociatedObject(self, &Self._disposeBagKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
}
#endif
