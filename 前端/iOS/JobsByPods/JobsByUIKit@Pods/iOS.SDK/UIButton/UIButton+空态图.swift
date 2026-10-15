//
//  UIButton+空态图.swift
//  JobsByUIKit
//
//  Created by Jobs on 2026年5月13日，星期三.
//

#if os(OSX)
import AppKit
#elseif os(iOS) || os(tvOS)
import UIKit
#endif

#if canImport(SnapKit)
// MARK: 为空态按钮附加自定义布局闭包
import SnapKit
public var _jobsEmptyLayoutKey: UInt8 = 0
extension UIButton {
    public typealias JobsEmptyLayout = (_ btn: UIButton,
                                        _ make: ConstraintMaker,
                                        _ host: UIScrollView) -> Void
    /// 内部读取：UIScrollView._jobs_attachEmptyButton 会使用
    public var _jobsEmptyLayout: JobsEmptyLayout? {
        get { objc_getAssociatedObject(self, &_jobsEmptyLayoutKey) as? JobsEmptyLayout }
        set {
            objc_setAssociatedObject(
                self,
                &_jobsEmptyLayoutKey,
                newValue,
                .OBJC_ASSOCIATION_COPY_NONATOMIC)
        }
    }
    /// 链式：设置空态按钮的自定义布局
    @discardableResult
    public func byEmptyLayout(_ layout: @escaping JobsEmptyLayout) -> Self {
        self._jobsEmptyLayout = layout
        return self
    }
}
#endif
