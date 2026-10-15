//
//  UIView+传值回调.swift
//  JobsByUIKit
//
//  Created by Jobs on 2026年5月13日，星期三.
//

#if os(OSX)
import AppKit
#elseif os(iOS) || os(tvOS)
import UIKit
#endif

import ObjectiveC.runtime
import JobsSwiftDSL
import JobsSwiftBaseDefines
import JobsSwiftBlock

private var JobsViewCallbackResultKey: UInt8 = 0
/// ✅ 覆盖所有 View（UIView 及其子类）
extension UIView: @retroactive ViewDataProtocol {}
@MainActor
public extension ViewDataProtocol where Self: UIView {
    // ================================== 正向：传值即渲染（默认 no-op） ==================================
    /// 默认实现：什么都不做，留给自定义 View/Cell 在自己的类里实现 `byData(_:)`
    @discardableResult
    func byData(_ any: Any?) -> Self { self }
    // ================================== 逆向：回传 ==================================
    @discardableResult
    func onResult(_ callback: @escaping jobsByAnyBlock) -> Self {
        objc_setAssociatedObject(
            self,
            &JobsViewCallbackResultKey,
            callback,
            .OBJC_ASSOCIATION_COPY_NONATOMIC
        );return self
    }

    func sendResult(_ any: Any?) {
        (objc_getAssociatedObject(self, &JobsViewCallbackResultKey) as? jobsByAnyBlock)?(any)
    }
}
