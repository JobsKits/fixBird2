//
//  UITextField+DSL.swift
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
import JobsSwiftBaseDefines
import JobsSwiftBlock

// MARK: - 直接赋值@单参数
extension UITextField {
    @discardableResult
    public func byPlaceholder(_ placeholder: String?) -> Self {
        self.placeholder = placeholder
        return self
    }
    // MARK: 🌸 基础文本属性
    @discardableResult
    public func byLeftViewMode(_ mode: UITextField.ViewMode) -> Self {
        self.leftViewMode = mode
        return self
    }

    @discardableResult
    public func byRightViewMode(_ mode: UITextField.ViewMode) -> Self {
        self.rightViewMode = mode
        return self
    }

    @discardableResult
    public func byText(_ text: String?) -> Self {
        self.text = text
        return self
    }

    @discardableResult
    public func byTextColor(_ color: UIColor?) -> Self {
        let slot = "UITextField.textColor"
        if let key = color?.jobsThemeColorKey {
            JobsThemeCenter.shared.bind(self, slot: slot) { object, center in
                (object as? UITextField)?.textColor = center.resolvedColor(key)
            }
        } else {
            JobsThemeCenter.shared.unbind(self, slot: slot)
            textColor = color
        }
        return self
    }

    @discardableResult
    public func byFont(_ font: UIFont?) -> Self {
        self.font = font
        return self
    }

    @discardableResult
    public func byTextAlignment(_ alignment: NSTextAlignment) -> Self {
        self.textAlignment = alignment
        return self
    }

    @discardableResult
    public func byBorderStyle(_ style: UITextField.BorderStyle) -> Self {
        self.borderStyle = style
        return self
    }
    // MARK: 🧱 占位/背景样式
    @available(iOS 6.0, *)
    @discardableResult
    public func byAttributedText(_ attributedText: NSAttributedString?) -> Self {
        self.attributedText = attributedText
        return self
    }
    @available(iOS 6.0, *)
    @discardableResult
    public func byAttributedPlaceholder(_ attributedPlaceholder: NSAttributedString?) -> Self {
        self.attributedPlaceholder = attributedPlaceholder
        return self
    }

    @discardableResult
    public func byBackground(_ image: UIImage?) -> Self {
        self.background = image
        return self
    }

    @discardableResult
    public func byDisabledBackground(_ image: UIImage?) -> Self {
        self.disabledBackground = image
        return self
    }
    // MARK: 🧠 输入控制行为
    @discardableResult
    public func byClearsOnBeginEditing(_ clears: Bool) -> Self {
        self.clearsOnBeginEditing = clears
        return self
    }

    @discardableResult
    public func byClearsOnInsertion(_ clears: Bool) -> Self {
        self.clearsOnInsertion = clears
        return self
    }

    @discardableResult
    public func byAdjustsFontSizeToFitWidth(_ adjusts: Bool) -> Self {
        self.adjustsFontSizeToFitWidth = adjusts
        return self
    }

    @discardableResult
    public func byMinimumFontSize(_ size: CGFloat) -> Self {
        self.minimumFontSize = size
        return self
    }

    @discardableResult
    public func bySecureTextEntry(_ secure: Bool) -> Self {
        self.isSecureTextEntry = secure
        return self
    }

    @discardableResult
    public func byToggleSecureTextEntry() -> Self {
        self.isSecureTextEntry.toggle()
        return self
    }
    // MARK: ⌨️ 键盘行为
    @discardableResult
    public func byKeyboardType(_ type: UIKeyboardType) -> Self {
        self.keyboardType = type
        return self
    }

    @discardableResult
    public func byKeyboardAppearance(_ appearance: UIKeyboardAppearance) -> Self {
        self.keyboardAppearance = appearance
        return self
    }

    @discardableResult
    public func byReturnKeyType(_ type: UIReturnKeyType) -> Self {
        self.returnKeyType = type
        return self
    }

    @discardableResult
    public func byEnablesReturnKeyAutomatically(_ enabled: Bool) -> Self {
        self.enablesReturnKeyAutomatically = enabled
        return self
    }
    // MARK: 🧠 智能输入特性
    @discardableResult
    public func byAutocapitalizationType(_ type: UITextAutocapitalizationType) -> Self {
        self.autocapitalizationType = type
        return self
    }

    @discardableResult
    public func byAutocorrectionType(_ type: UITextAutocorrectionType) -> Self {
        self.autocorrectionType = type
        return self
    }

    @discardableResult
    public func bySpellCheckingType(_ type: UITextSpellCheckingType) -> Self {
        self.spellCheckingType = type
        return self
    }
    @available(iOS 11.0, *)
    @discardableResult
    public func bySmartQuotesType(_ type: UITextSmartQuotesType) -> Self {
        self.smartQuotesType = type
        return self
    }
    @available(iOS 11.0, *)
    @discardableResult
    public func bySmartDashesType(_ type: UITextSmartDashesType) -> Self {
        self.smartDashesType = type
        return self
    }
    @available(iOS 11.0, *)
    @discardableResult
    public func bySmartInsertDeleteType(_ type: UITextSmartInsertDeleteType) -> Self {
        self.smartInsertDeleteType = type
        return self
    }
    @available(iOS 17.0, *)
    @discardableResult
    public func byInlinePredictionType(_ type: UITextInlinePredictionType) -> Self {
        self.inlinePredictionType = type
        return self
    }
    // MARK: 🧠 iOS 18+ 新特性
    @available(iOS 18.0, *)
    @discardableResult
    public func byMathExpressionCompletionType(_ type: UITextMathExpressionCompletionType) -> Self {
        self.mathExpressionCompletionType = type
        return self
    }
    @available(iOS 18.0, *)
    @discardableResult
    public func byWritingToolsBehavior(_ behavior: UIWritingToolsBehavior) -> Self {
        self.writingToolsBehavior = behavior
        return self
    }
    @available(iOS 18.0, *)
    @discardableResult
    public func byAllowedWritingToolsResultOptions(_ options: UIWritingToolsResultOptions) -> Self {
        self.allowedWritingToolsResultOptions = options
        return self
    }
    // MARK: 🔠 内容类型 / 密码规则
    @discardableResult
    public func byTextContentType(_ type: UITextContentType?) -> Self {
        self.textContentType = type
        return self
    }
    @available(iOS 12.0, *)
    @discardableResult
    public func byPasswordRules(_ rules: UITextInputPasswordRules?) -> Self {
        self.passwordRules = rules
        return self
    }
    // MARK: 🎨 左右视图 / 清除按钮
    @discardableResult
    public func byClearButtonMode(_ mode: UITextField.ViewMode) -> Self {
        self.clearButtonMode = mode
        return self
    }
    @available(iOS 7.0, *)
    @discardableResult
    public func byDefaultTextAttributes(_ attrs: [NSAttributedString.Key : Any]) -> Self {
        self.defaultTextAttributes = attrs
        return self
    }
    @available(iOS 6.0, *)
    @discardableResult
    public func byAllowsEditingTextAttributes(_ allows: Bool) -> Self {
        self.allowsEditingTextAttributes = allows
        return self
    }
    @available(iOS 6.0, *)
    @discardableResult
    public func byTypingAttributes(_ attrs: [NSAttributedString.Key : Any]?) -> Self {
        self.typingAttributes = attrs
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
    /// ⚠️ delegate 弱引用属性：仅便捷设置，别强持有
    @discardableResult
    public func byDelegate(_ delegate: UITextFieldDelegate?) -> Self {
        self.delegate = delegate
        return self
    }
    @available(iOS 10.0, *)
    @discardableResult
    public func byDynamicTextStyle(_ style: UIFont.TextStyle) -> Self {
        self.font = JobsFont.preferredFont(forTextStyle: style)
        self.adjustsFontForContentSizeCategory = true
        return self
    }
}
// MARK: - 闭包重载@单参数
extension UITextField {
    @discardableResult
    public func byPlaceholder(_ builder: () -> String?) -> Self {
        self.placeholder = builder()
        return self
    }

    @discardableResult
    public func byLeftViewMode(_ builder: () -> UITextField.ViewMode) -> Self {
        self.leftViewMode = builder()
        return self
    }

    @discardableResult
    public func byRightViewMode(_ builder: () -> UITextField.ViewMode) -> Self {
        self.rightViewMode = builder()
        return self
    }

    @discardableResult
    public func byText(_ builder: () -> String?) -> Self {
        self.text = builder()
        return self
    }

    @discardableResult
    public func byTextColor(_ builder: () -> UIColor?) -> Self {
        byTextColor(builder())
    }

    @discardableResult
    public func byFont(_ builder: () -> UIFont?) -> Self {
        self.font = builder()
        return self
    }

    @discardableResult
    public func byTextAlignment(_ builder: () -> NSTextAlignment) -> Self {
        self.textAlignment = builder()
        return self
    }

    @discardableResult
    public func byBorderStyle(_ builder: () -> UITextField.BorderStyle) -> Self {
        self.borderStyle = builder()
        return self
    }
    @available(iOS 6.0, *)
    @discardableResult
    public func byAttributedText(_ builder: () -> NSAttributedString?) -> Self {
        self.attributedText = builder()
        return self
    }
    @available(iOS 6.0, *)
    @discardableResult
    public func byAttributedPlaceholder(_ builder: () -> NSAttributedString?) -> Self {
        self.attributedPlaceholder = builder()
        return self
    }

    @discardableResult
    public func byBackground(_ builder: () -> UIImage?) -> Self {
        self.background = builder()
        return self
    }

    @discardableResult
    public func byDisabledBackground(_ builder: () -> UIImage?) -> Self {
        self.disabledBackground = builder()
        return self
    }
    @discardableResult
    public func byClearsOnBeginEditing(_ builder: () -> Bool) -> Self {
        self.clearsOnBeginEditing = builder()
        return self
    }

    @discardableResult
    public func byClearsOnInsertion(_ builder: () -> Bool) -> Self {
        self.clearsOnInsertion = builder()
        return self
    }

    @discardableResult
    public func byAdjustsFontSizeToFitWidth(_ builder: () -> Bool) -> Self {
        self.adjustsFontSizeToFitWidth = builder()
        return self
    }

    @discardableResult
    public func byMinimumFontSize(_ builder: () -> CGFloat) -> Self {
        self.minimumFontSize = builder()
        return self
    }

    @discardableResult
    public func bySecureTextEntry(_ builder: () -> Bool) -> Self {
        self.isSecureTextEntry = builder()
        return self
    }
    @discardableResult
    public func byKeyboardType(_ builder: () -> UIKeyboardType) -> Self {
        self.keyboardType = builder()
        return self
    }

    @discardableResult
    public func byKeyboardAppearance(_ builder: () -> UIKeyboardAppearance) -> Self {
        self.keyboardAppearance = builder()
        return self
    }

    @discardableResult
    public func byReturnKeyType(_ builder: () -> UIReturnKeyType) -> Self {
        self.returnKeyType = builder()
        return self
    }

    @discardableResult
    public func byEnablesReturnKeyAutomatically(_ builder: () -> Bool) -> Self {
        self.enablesReturnKeyAutomatically = builder()
        return self
    }
    @discardableResult
    public func byAutocapitalizationType(_ builder: () -> UITextAutocapitalizationType) -> Self {
        self.autocapitalizationType = builder()
        return self
    }

    @discardableResult
    public func byAutocorrectionType(_ builder: () -> UITextAutocorrectionType) -> Self {
        self.autocorrectionType = builder()
        return self
    }

    @discardableResult
    public func bySpellCheckingType(_ builder: () -> UITextSpellCheckingType) -> Self {
        self.spellCheckingType = builder()
        return self
    }
    @available(iOS 11.0, *)
    @discardableResult
    public func bySmartQuotesType(_ builder: () -> UITextSmartQuotesType) -> Self {
        self.smartQuotesType = builder()
        return self
    }
    @available(iOS 11.0, *)
    @discardableResult
    public func bySmartDashesType(_ builder: () -> UITextSmartDashesType) -> Self {
        self.smartDashesType = builder()
        return self
    }
    @available(iOS 11.0, *)
    @discardableResult
    public func bySmartInsertDeleteType(_ builder: () -> UITextSmartInsertDeleteType) -> Self {
        self.smartInsertDeleteType = builder()
        return self
    }
    @available(iOS 17.0, *)
    @discardableResult
    public func byInlinePredictionType(_ builder: () -> UITextInlinePredictionType) -> Self {
        self.inlinePredictionType = builder()
        return self
    }
    @available(iOS 18.0, *)
    @discardableResult
    public func byMathExpressionCompletionType(_ builder: () -> UITextMathExpressionCompletionType) -> Self {
        self.mathExpressionCompletionType = builder()
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
        self.allowedWritingToolsResultOptions = builder()
        return self
    }
    @discardableResult
    public func byTextContentType(_ builder: () -> UITextContentType?) -> Self {
        self.textContentType = builder()
        return self
    }
    @available(iOS 12.0, *)
    @discardableResult
    public func byPasswordRules(_ builder: () -> UITextInputPasswordRules?) -> Self {
        self.passwordRules = builder()
        return self
    }
    @discardableResult
    public func byClearButtonMode(_ builder: () -> UITextField.ViewMode) -> Self {
        self.clearButtonMode = builder()
        return self
    }
    @available(iOS 7.0, *)
    @discardableResult
    public func byDefaultTextAttributes(_ builder: () -> [NSAttributedString.Key : Any]) -> Self {
        self.defaultTextAttributes = builder()
        return self
    }
    @available(iOS 6.0, *)
    @discardableResult
    public func byAllowsEditingTextAttributes(_ builder: () -> Bool) -> Self {
        self.allowsEditingTextAttributes = builder()
        return self
    }
    @available(iOS 6.0, *)
    @discardableResult
    public func byTypingAttributes(_ builder: () -> [NSAttributedString.Key : Any]?) -> Self {
        self.typingAttributes = builder()
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
    public func byDelegate(_ builder: () -> UITextFieldDelegate?) -> Self {
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
}

extension UITextField {
    @discardableResult
    public func byLeftView(_ view: UIView?, mode: UITextField.ViewMode = .always) -> Self {
        self.leftView = view
        self.leftViewMode = mode
        return self
    }

    @discardableResult
    public func byRightView(_ view: UIView?, mode: UITextField.ViewMode = .always) -> Self {
        self.rightView = view
        self.rightViewMode = mode
        return self
    }
    /// 链式监听“发送/回车”键
    // ================================== Return 键回调（兼容 iOS 12+） ==================================
    @discardableResult
    public func onReturn(_ handler: @escaping jobsByTextFieldBlock) -> Self {
        // 先存起来（低版本 target-action 需要）
        _jobs_onReturnHandler = handler
        if #available(iOS 14.0, *) {
            // iOS14+: UIAction
            let action = UIAction(
                title: "",
                image: nil,
                identifier: nil,
                discoverabilityTitle: nil,
                attributes: [],
                state: .off
            ) { [weak self] _ in
                guard let self else { return }
                handler(self)
            }
            addAction(action, for: .editingDidEndOnExit)
        } else {
            // iOS13-: target-action
            addTarget(self, action: #selector(_jobs_handleReturn), for: .editingDidEndOnExit)
        };return self
    }
}

private var onReturnKey: UInt8 = 0
extension UITextField {
    private var _jobs_onReturnHandler: (jobsByTextFieldBlock)? {
        get { objc_getAssociatedObject(self, &onReturnKey) as? (jobsByTextFieldBlock) }
        set {
            objc_setAssociatedObject(
                self,
                &onReturnKey,
                newValue,
                .OBJC_ASSOCIATION_COPY_NONATOMIC
            )
        }
    }
    @objc private func _jobs_handleReturn() {
        _jobs_onReturnHandler?(self)
    }
}
// MARK: - 左侧图标 & 纯留白
extension UITextField {
    /// 设置左侧图标，并精确控制：leading（到边距）和 spacing（到文字）
    @discardableResult
    public func byLeftIcon(
        _ image: UIImage?,
        tint: UIColor? = nil,
        size: CGSize = .init(width: 18, height: 18),
        leading: CGFloat = 12,      // 图标距 TextField 左边缘
        spacing: CGFloat = 8        // 图标与文字之间
    ) -> Self {
        guard let image else {
            leftView = nil
            leftViewMode = .never
            return self
        }
        let containerW = leading + size.width + spacing
        let containerH = max(24, size.height)    // 高度随便给，系统会垂直居中
        let container = UIView(frame: CGRect(x: 0, y: 0, width: containerW, height: containerH))
        self.byLeftView(container.byAddSubviewRetSuper(UIImageView().byImage(tint == nil ? image : image.withRenderingMode(.alwaysTemplate))
            .byTintColor(tint)
            .byContentMode(.scaleAspectFit)
            .byFrame(CGRect(origin: .zero, size: size))
             // 把图标放到带 leading 的位置
            .byCenter(CGPoint(x: leading + size.width / 2, y: container.bounds.midY))
            .byAutoresizingMask([.flexibleTopMargin, .flexibleBottomMargin])),mode:.always)
        return self
    }
    /// 仅设置左侧留白（没有图标），常用于单纯增加文本左内边距
    @discardableResult
    public func byLeftPadding(_ padding: CGFloat) -> Self {
        let spacer = UIView(frame: CGRect(x: 0, y: 0, width: padding, height: 1))
        spacer.isUserInteractionEnabled = false
        leftView = spacer
        leftViewMode = .always
        return self
    }
}
