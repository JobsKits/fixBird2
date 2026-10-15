//
//  UIBarButtonItemAppearance.swift
//  JobsByUIKit
//
//  Created by Jobs on 2026年5月13日，星期三.
//

#if os(OSX)
import AppKit
#elseif os(iOS) || os(tvOS)
import UIKit
#endif

@available(iOS 13.0, *)
extension UIBarButtonItemAppearance {
    /// 快速配置不同状态的文本与颜色
    @discardableResult
    public func byTitleColor(_ color: UIColor, for state: UIControl.State = .normal) -> Self {
        switch state {
        /// 处理 .normal 分支
        case .normal:
            self.normal.titleTextAttributes[.foregroundColor] = color
        /// 处理 .highlighted 分支
        case .highlighted:
            self.highlighted.titleTextAttributes[.foregroundColor] = color
        /// 处理 .disabled 分支
        case .disabled:
            self.disabled.titleTextAttributes[.foregroundColor] = color
        /// 处理 .focused 分支
        case .focused:
            self.focused.titleTextAttributes[.foregroundColor] = color
        /// 未匹配已知分支时执行兜底处理
        default:
            self.normal.titleTextAttributes[.foregroundColor] = color
        };return self
    }

    @discardableResult
    public func byFont(_ font: UIFont, for state: UIControl.State = .normal) -> Self {
        switch state {
        /// 处理 .normal 分支
        case .normal:
            self.normal.titleTextAttributes[.font] = font
        /// 处理 .highlighted 分支
        case .highlighted:
            self.highlighted.titleTextAttributes[.font] = font
        /// 处理 .disabled 分支
        case .disabled:
            self.disabled.titleTextAttributes[.font] = font
        /// 处理 .focused 分支
        case .focused:
            self.focused.titleTextAttributes[.font] = font
        /// 未匹配已知分支时执行兜底处理
        default:
            self.normal.titleTextAttributes[.font] = font
        };return self
    }
}
