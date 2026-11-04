//
//  UIView+回调@确认和取消.swift
//  JobsByUIKit
//
//  Created by Jobs on 2026年5月13日，星期三.
//

#if os(OSX)
import AppKit
#elseif os(iOS) || os(tvOS)
import UIKit
#endif

import JobsSwiftBlock

private struct JobsConfirmKeys {
    static var confirm: UInt8 = 0
    static var cancel:  UInt8 = 0
}

extension UIView {
    public var confirmHandler: jobsByVoidBlock? {
        get {
            objc_getAssociatedObject(self, &JobsConfirmKeys.confirm) as? jobsByVoidBlock
        }
        set {
            objc_setAssociatedObject(self,
                                     &JobsConfirmKeys.confirm,
                                     newValue,
                                     .OBJC_ASSOCIATION_COPY_NONATOMIC)
        }
    }

    public var cancelHandler: jobsByVoidBlock? {
        get {
            objc_getAssociatedObject(self, &JobsConfirmKeys.cancel) as? jobsByVoidBlock
        }
        set {
            objc_setAssociatedObject(self,
                                     &JobsConfirmKeys.cancel,
                                     newValue,
                                     .OBJC_ASSOCIATION_COPY_NONATOMIC)
        }
    }
    /// 确认回调
    @discardableResult
    public func onConfirm(_ handler: @escaping jobsByVoidBlock) -> Self {
        confirmHandler = handler
        return self
    }
    /// 取消回调
    @discardableResult
    public func onCancel(_ handler: @escaping jobsByVoidBlock) -> Self {
        cancelHandler = handler
        return self
    }

    public func jobs_fireConfirm() {
        confirmHandler?()
    }

    public func jobs_fireCancel() {
        cancelHandler?()
    }
}
