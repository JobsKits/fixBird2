//
//  UITextView+DSL.swift
//  JobsByUIKit
//
//  Created by Jobs on 2026年5月13日，星期三.
//

#if os(OSX)
import AppKit
#elseif os(iOS) || os(tvOS)
import UIKit
#endif

import JobsSwiftBaseDefines

// MARK: - 直接赋值@单参数
extension UITextView {
    // MARK: 文本基础属性
    @discardableResult
    public func byText(_ string: String?) -> Self {
        self.text = string
        return self
    }

    @discardableResult
    public func byTextColor(_ color: UIColor) -> Self {
        let slot = "UITextView.textColor"
        if let key = color.jobsThemeColorKey {
            JobsThemeCenter.shared.bind(self, slot: slot) { object, center in
                (object as? UITextView)?.textColor = center.resolvedColor(key)
            }
        } else {
            JobsThemeCenter.shared.unbind(self, slot: slot)
            textColor = color
        }
        return self
    }

    @discardableResult
    public func byFont(_ f: UIFont) -> Self {
        self.font = f
        return self
    }

    @discardableResult
    public func byTextAlignment(_ alignment: NSTextAlignment) -> Self {
        self.textAlignment = alignment
        return self
    }

    @discardableResult
    public func byAttributedText(_ attrText: NSAttributedString?) -> Self {
        self.attributedText = attrText
        return self
    }

    @discardableResult
    public func byTypingAttributes(_ attrs: [NSAttributedString.Key: Any]) -> Self {
        self.typingAttributes = attrs
        return self
    }
    // MARK: 可编辑与交互
    @discardableResult
    public func byEditable(_ editable: Bool) -> Self {
        self.isEditable = editable
        return self
    }

    @discardableResult
    public func bySelectable(_ selectable: Bool) -> Self {
        self.isSelectable = selectable
        return self
    }

    @discardableResult
    public func byDataDetectorTypes(_ types: UIDataDetectorTypes) -> Self {
        self.dataDetectorTypes = types
        return self
    }

    @discardableResult
    public func byAllowsEditingTextAttributes(_ allow: Bool) -> Self {
        self.allowsEditingTextAttributes = allow
        return self
    }
    // MARK: 输入相关
    @discardableResult
    public func byKeyboardType(_ type: UIKeyboardType) -> Self {
        self.keyboardType = type
        return self
    }

    @discardableResult
    public func byInputView(_ view: UIView?) -> Self {
        self.inputView = view
        return self
    }

    @discardableResult
    public func byInputAccessoryView(_ view: UIView?) -> Self {
        self.inputAccessoryView = view
        return self
    }

    @discardableResult
    public func byClearsOnInsertion(_ clear: Bool) -> Self {
        self.clearsOnInsertion = clear
        return self
    }
    // MARK: 富文本与链接样式
    @discardableResult
    public func byLinkTextAttributes(_ attrs: [NSAttributedString.Key: Any]) -> Self {
        self.linkTextAttributes = attrs
        return self
    }
    @discardableResult
    @available(iOS 13.0, *)
    public func byUsesStandardTextScaling(_ enable: Bool) -> Self {
        self.usesStandardTextScaling = enable
        return self
    }
    // MARK: 布局与内边距
    @discardableResult
    public func byTextContainerInset(_ inset: UIEdgeInsets) -> Self {
        self.textContainerInset = inset
        return self
    }
    // MARK: 查找功能 (iOS 16+)
    @available(iOS 16.0, *)
    @discardableResult
    public func byFindInteractionEnabled(_ enable: Bool) -> Self {
        self.isFindInteractionEnabled = enable
        return self
    }
    // MARK: 边框样式 (iOS 17+)
    @available(iOS 17.0, *)
    @discardableResult
    public func byBorderStyle(_ style: UITextView.BorderStyle) -> Self {
        self.borderStyle = style
        return self
    }
    // MARK: 高亮显示 (iOS 18+)
    @available(iOS 18.0, *)
    @discardableResult
    public func byTextHighlightAttributes(_ attrs: [NSAttributedString.Key: Any]) -> Self {
        self.textHighlightAttributes = attrs
        return self
    }
    // MARK: Writing Tools (iOS 18+)
    @available(iOS 18.0, *)
    @discardableResult
    public func byWritingToolsBehavior(_ behavior: UIWritingToolsBehavior) -> Self {
        self.writingToolsBehavior = behavior
        return self
    }

    @available(iOS 18.0, *)
    @discardableResult
    public func byAllowedWritingToolsResultOptions(_ options: UIWritingToolsResultOptions) -> Self {
        var safe = options
        safe.remove(.table)
        self.allowedWritingToolsResultOptions = safe
        return self
    }
    // MARK: 富文本格式配置 (iOS 18+)
    @available(iOS 18.0, *)
    @discardableResult
    public func byTextFormattingConfiguration(_ config: UITextFormattingViewController.Configuration) -> Self {
        self.textFormattingConfiguration = config
        return self
    }
    // MARK: 代理设置
    @discardableResult
    public func byDelegate(_ textViewDelegate: UITextViewDelegate?) -> Self {
        self.delegate = textViewDelegate
        return self
    }
    @available(iOS 10.0, *)
    @discardableResult
    public func byDynamicTextStyle(_ style: UIFont.TextStyle) -> Self {
        self.font = JobsFont.preferredFont(forTextStyle: style)
        self.adjustsFontForContentSizeCategory = true
        return self
    }
    /// DSL：专门给 lineFragmentPadding 赋值（更短）
    @discardableResult
    public func byLineFragmentPadding(_ padding: CGFloat) -> Self {
        return byTextContainer { $0.lineFragmentPadding = padding }
    }
}

// MARK: - 闭包重载@单参数
extension UITextView {
    @discardableResult
    public func byText(_ builder: () -> String?) -> Self {
        self.text = builder()
        return self
    }

    @discardableResult
    public func byTextColor(_ builder: () -> UIColor) -> Self {
        byTextColor(builder())
    }

    @discardableResult
    public func byFont(_ builder: () -> UIFont) -> Self {
        self.font = builder()
        return self
    }

    @discardableResult
    public func byTextAlignment(_ builder: () -> NSTextAlignment) -> Self {
        self.textAlignment = builder()
        return self
    }

    @discardableResult
    public func byAttributedText(_ builder: () -> NSAttributedString?) -> Self {
        self.attributedText = builder()
        return self
    }

    @discardableResult
    public func byTypingAttributes(_ builder: () -> [NSAttributedString.Key: Any]) -> Self {
        self.typingAttributes = builder()
        return self
    }

    @discardableResult
    public func byEditable(_ builder: () -> Bool) -> Self {
        self.isEditable = builder()
        return self
    }

    @discardableResult
    public func bySelectable(_ builder: () -> Bool) -> Self {
        self.isSelectable = builder()
        return self
    }

    @discardableResult
    public func byDataDetectorTypes(_ builder: () -> UIDataDetectorTypes) -> Self {
        self.dataDetectorTypes = builder()
        return self
    }

    @discardableResult
    public func byAllowsEditingTextAttributes(_ builder: () -> Bool) -> Self {
        self.allowsEditingTextAttributes = builder()
        return self
    }

    @discardableResult
    public func byKeyboardType(_ builder: () -> UIKeyboardType) -> Self {
        self.keyboardType = builder()
        return self
    }

    @discardableResult
    public func byInputView(_ builder: () -> UIView?) -> Self {
        self.inputView = builder()
        return self
    }

    @discardableResult
    public func byInputAccessoryView(_ builder: () -> UIView?) -> Self {
        self.inputAccessoryView = builder()
        return self
    }

    @discardableResult
    public func byClearsOnInsertion(_ builder: () -> Bool) -> Self {
        self.clearsOnInsertion = builder()
        return self
    }

    @discardableResult
    public func byLinkTextAttributes(_ builder: () -> [NSAttributedString.Key: Any]) -> Self {
        self.linkTextAttributes = builder()
        return self
    }

    @discardableResult
    @available(iOS 13.0, *)
    public func byUsesStandardTextScaling(_ builder: () -> Bool) -> Self {
        self.usesStandardTextScaling = builder()
        return self
    }

    @discardableResult
    public func byTextContainerInset(_ builder: () -> UIEdgeInsets) -> Self {
        self.textContainerInset = builder()
        return self
    }

    @available(iOS 16.0, *)
    @discardableResult
    public func byFindInteractionEnabled(_ builder: () -> Bool) -> Self {
        self.isFindInteractionEnabled = builder()
        return self
    }

    @available(iOS 17.0, *)
    @discardableResult
    public func byBorderStyle(_ builder: () -> UITextView.BorderStyle) -> Self {
        self.borderStyle = builder()
        return self
    }

    @available(iOS 18.0, *)
    @discardableResult
    public func byTextHighlightAttributes(_ builder: () -> [NSAttributedString.Key: Any]) -> Self {
        self.textHighlightAttributes = builder()
        return self
    }

    @available(iOS 18.0, *)
    @discardableResult
    public func byWritingToolsBehavior(_ builder: () -> UIWritingToolsBehavior) -> Self {
        self.writingToolsBehavior = builder()
        return self
    }

    @available(iOS 18.0, *)
    @discardableResult
    public func byAllowedWritingToolsResultOptions(_ builder: () -> UIWritingToolsResultOptions) -> Self {
        var safe = builder()
        safe.remove(.table)
        self.allowedWritingToolsResultOptions = safe
        return self
    }

    @available(iOS 18.0, *)
    @discardableResult
    public func byTextFormattingConfiguration(_ builder: () -> UITextFormattingViewController.Configuration) -> Self {
        self.textFormattingConfiguration = builder()
        return self
    }

    @discardableResult
    public func byDelegate(_ builder: () -> UITextViewDelegate?) -> Self {
        self.delegate = builder()
        return self
    }

    @available(iOS 10.0, *)
    @discardableResult
    public func byDynamicTextStyle(_ builder: () -> UIFont.TextStyle) -> Self {
        self.font = JobsFont.preferredFont(forTextStyle: builder())
        self.adjustsFontForContentSizeCategory = true
        return self
    }

    @discardableResult
    public func byLineFragmentPadding(_ builder: () -> CGFloat) -> Self {
        return byTextContainer { $0.lineFragmentPadding = builder() }
    }
}

extension UITextView {
    // MARK: 滚动与范围
    @discardableResult
    public func byScrollToVisible(range: NSRange) -> Self {
        scrollRangeToVisible(range)
        return self
    }
    /// DSL：用回调配置 textContainer（iOS: 一定存在；macOS: 可能为 nil）
    @discardableResult
    public func byTextContainer(_ block: (NSTextContainer) -> Void) -> Self {
        #if os(OSX)
        guard let tc = self.textContainer else { return self }
        block(tc)
        #else
        block(self.textContainer)
        #endif
        return self
    }
    // MARK: 统一的圆角边框样式（跨 iOS 版本）
    @discardableResult
    public func byRoundedBorder(
        color: UIColor = JobsCor.systemGray4,
        width: CGFloat = 1,
        radius: CGFloat = 8,
        background: UIColor? = nil
    ) -> Self {
        layer.byBorderColor(color)
            .byBorderWidth(width)
            .byCornerRadius(radius)
            .byMasksToBounds(true)
        if let bg = background { backgroundColor = bg };return self
    }
    // MARK: 类似“bezel”的外观（简易版）
    @discardableResult
    public func byBezelLike(
        radius: CGFloat = 8
    ) -> Self {
        layer.byBorderColor(JobsCor.separator)
            .byBorderWidth(1)
            .byCornerRadius(radius)
            .byMasksToBounds(true)
        byBackgroundColor(JobsCor.secondarySystemBackground)
        return self
    }
}
