//
//  UITextField+Placeholder.swift
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
import JobsSwiftDSL
/// Apple 官方没有主动暴露Api去修改UITextField.placeholder的字体、颜色
/// 可以通过富文本的方式修改
/// 为了更加的贴合语义，这里使用OC的runtime机制去拿到内部私有的内部类来进行修改

extension UITextField {
    @discardableResult
    public func byPlaceholderColor(_ color: UIColor) -> Self {
        if let label = jobs_placeholderLabel_byRuntime() {
            label.byTextColor(color)
        } else {
            jobs_applyAttributedPlaceholder(color: color, font: nil) // 兜底
        };return self
    }

    @discardableResult
    public func byPlaceholderFont(_ font: UIFont) -> Self {
        if let label = jobs_placeholderLabel_byRuntime() {
            label.byFont(font)
        } else {
            jobs_applyAttributedPlaceholder(color: nil, font: font) // 兜底
        };return self
    }
    /// 更接近 OC 的方式：通过 runtime 取 ivar，再 object_getIvar
    fileprivate func jobs_placeholderLabel_byRuntime() -> UILabel? {
        // 有的系统叫 _placeholderLabel，有的可能叫 placeholderLabel（通常是前者）
        for name in ["_placeholderLabel", "placeholderLabel"] {
            if let ivar = class_getInstanceVariable(UITextField.self, name) {
                return object_getIvar(self, ivar) as? UILabel
            }
        };return nil
    }
    fileprivate func jobs_applyAttributedPlaceholder(color: UIColor?, font: UIFont?) {
        let text = placeholder ?? (attributedPlaceholder?.string ?? "")
        var attrs: [NSAttributedString.Key: Any] =
            attributedPlaceholder?.attributes(at: 0, effectiveRange: nil) ?? [:]
        if let color { attrs[.foregroundColor] = color }
        if let font { attrs[.font] = font }
        attributedPlaceholder = NSAttributedString(string: text, attributes: attrs)
    }
}
