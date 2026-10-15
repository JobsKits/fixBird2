//
//  UIAlertAction.swift
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

extension UIAlertAction {
    // ========= 链式：启用/禁用 =========
    @discardableResult
    public func byEnabled(_ enabled: Bool) -> Self {
        self.isEnabled = enabled
        return self
    }
    // ========= 链式：独立设置 handler =========
    private enum _JobsAssocKey { static var onTap: UInt8 = 0 }

    private var jobs_onTap: ((UIAlertAction) -> Void)? {
        get { objc_getAssociatedObject(self, &_JobsAssocKey.onTap) as? (UIAlertAction) -> Void }
        set { objc_setAssociatedObject(self, &_JobsAssocKey.onTap, newValue, .OBJC_ASSOCIATION_COPY_NONATOMIC) }
    }
    /// 链式设置/覆盖点击回调
    @discardableResult
    public func onTap(_ handler: @escaping (UIAlertAction) -> Void) -> Self {
        self.jobs_onTap = handler
        return self
    }
    /// 内部转发器：点击时调用当前的 jobs_onTap
    public static func _trampoline(_ action: UIAlertAction) {
        action.jobs_onTap?(action)
    }
    // ========= 静态工厂（你要的 .ok() / .cancel() / .destructive()） =========
    /// `.default`：默认标题“确定”
    public static func ok(_ title: String = "确定") -> UIAlertAction {
        UIAlertAction(title: title, style: .default, handler: _trampoline)
    }
    /// `.cancel`：默认标题“取消”
    public static func cancel(_ title: String = "取消") -> UIAlertAction {
        UIAlertAction(title: title, style: .cancel, handler: _trampoline)
    }
    /// `.destructive`：默认标题“删除”（如需强制显式传，可去掉默认值）
    public static func destructive(_ title: String = "删除") -> UIAlertAction {
        UIAlertAction(title: title, style: .destructive, handler: _trampoline)
    }
}
