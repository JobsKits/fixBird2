//
//  JobsTextField.swift
//  JobsInheritance
//
//  Created by Jobs on 2026年5月13日，星期三.
//

#if os(OSX)
import AppKit
#elseif os(iOS) || os(tvOS)
import UIKit
#endif

import JobsByUIKit
import JobsSwiftDSL
import JobsSwiftBaseDefines
import SnapKit

public final class JobsTextField: UIImageView {
    // MARK: - Public
    public lazy var textField: UITextField = {
        UITextField.jobsMake { _ in }
            .byAddTo(self) { [unowned self] make in
                make.edges.equalToSuperview().inset(textInsets)
            }
    }()
    /// textField 相对 JobsTextField(UIImageView) 的内边距
    public var textInsets: UIEdgeInsets = .init(top: 0,
                                                left: 12,
                                                bottom: 0,
                                                right: 12) {
        didSet { updateTextInsets() }
    }
    // 如果你想按方向单独暴露（可选）
    public var insetTop: CGFloat { get { textInsets.top } set { textInsets.top = newValue; updateTextInsets() } }
    public var insetLeft: CGFloat { get { textInsets.left } set { textInsets.left = newValue; updateTextInsets() } }
    public var insetBottom: CGFloat { get { textInsets.bottom } set { textInsets.bottom = newValue; updateTextInsets() } }
    public var insetRight: CGFloat { get { textInsets.right } set { textInsets.right = newValue; updateTextInsets() } }
    // MARK: - Init
    public override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    // MARK: - Setup
    private func setup() {
        // 关键：UIImageView 默认不响应触摸
        isUserInteractionEnabled = true
        // 视图显示风格可按需改
        contentMode = .scaleToFill
        clipsToBounds = true
        textField.byVisible(YES)
    }

    private func updateTextInsets() {
        textField.snp.updateConstraints { make in
            make.edges.equalToSuperview().inset(textInsets)
        }
        setNeedsLayout()
        layoutIfNeeded()
    }
}
// MARK: - Convenience
extension JobsTextField {
    public convenience init() {
        self.init(frame: .zero)
    }

    public var text: String? {
        get { textField.text }
        set { textField.byText(newValue) }
    }

    public var placeholder: String? {
        get { textField.placeholder }
        set { textField.byPlaceholder(newValue) }
    }

    public var delegate: UITextFieldDelegate? {
        get { textField.delegate }
        set { textField.byDelegate(newValue) }
    }
}
// MARK: - DSL
extension JobsTextField {
    /// 设置 text（链式）
    @discardableResult
    public func byText(_ text: String?) -> Self {
        textField.byText(text)
        return self
    }
    /// 设置 placeholder（链式）
    @discardableResult
    public func byPlaceholder(_ placeholder: String?) -> Self {
        textField.byPlaceholder(placeholder)
        return self
    }
    /// 设置 delegate（链式）
    @discardableResult
    public func byDelegate(_ delegate: UITextFieldDelegate?) -> Self {
        textField.byDelegate(delegate)
        return self
    }
    /// 用回调配置内部 textField（链式）
    @discardableResult
    public func byTextFieldConfig(_ block: (UITextField) -> Void) -> Self {
        block(textField)
        return self
    }

    @discardableResult
    public func byInsetTop(_ v: CGFloat) -> Self {
        textInsets.byTop(v)
        updateTextInsets()
        return self
    }

    @discardableResult
    public func byInsetLeft(_ v: CGFloat) -> Self {
        textInsets.byLeft(v)
        updateTextInsets()
        return self
    }

    @discardableResult
    public func byInsetBottom(_ v: CGFloat) -> Self {
        textInsets.byBottom(v)
        updateTextInsets()
        return self
    }

    @discardableResult
    public func byInsetRight(_ v: CGFloat) -> Self {
        textInsets.byRight(v)
        updateTextInsets()
        return self
    }

    @discardableResult
    public func byInsetHorizontal(_ v: CGFloat) -> Self {
        textInsets.byHorizontal(v)
        updateTextInsets()
        return self
    }

    @discardableResult
    public func byInsetVertical(_ v: CGFloat) -> Self {
        textInsets.byVertical(v)
        updateTextInsets()
        return self
    }

    @discardableResult
    public func byInsetAll(_ v: CGFloat) -> Self {
        textInsets = .init(top: v, left: v, bottom: v, right: v)
        updateTextInsets()
        return self
    }
}
