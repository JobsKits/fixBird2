//
//  UILabel+DSL.swift
//  JobsByUIKit
//
//  Created by Jobs on 2026年5月13日，星期三.
//

#if os(OSX)
import AppKit
#elseif os(iOS) || os(tvOS)
import UIKit
#endif

import JobsTextTools
import JobsSwiftBaseDefines

// MARK: - 直接赋值@单参数
extension UILabel {
    @discardableResult
    public func byJobsAttributedText(_ text: JobsText?) -> Self {
        guard let text else { return self }
        self.attributedText = text.asAttributed
        return self
    }

    @discardableResult
    public func byJobsText(_ text: JobsText?) -> Self {
        guard let text else { return self }
        self.text = text.asString
        return self
    }

    @discardableResult
    public func byText(_ text: String?) -> Self {
        self.text = text
        return self
    }

    @discardableResult
    public func byTextColor(_ color: UIColor?) -> Self {
        let slot = "UILabel.textColor"
        if let key = color?.jobsThemeColorKey {
            JobsThemeCenter.shared.bind(self, slot: slot) { object, center in
                (object as? UILabel)?.textColor = center.resolvedColor(key)
            }
        } else if color != nil {
            JobsThemeCenter.shared.unbind(self, slot: slot)
            textColor = color
        };return self
    }
    /// 固定字号（严格设计稿）
    @discardableResult
    public func byFont(_ font: UIFont?) -> Self {
        if font != nil {
            self.font = font
        }
        self.adjustsFontForContentSizeCategory = false
        return self
    }
    /// 动态字号（跟随系统文字大小）
    public func byDynamicFont(_ font: UIFont, style: UIFont.TextStyle) -> Self {
        self.font = UIFontMetrics(forTextStyle: style).scaledFont(for: font)
        self.adjustsFontForContentSizeCategory = true
        return self
    }

    @discardableResult
    public func byTextAlignment(_ alignment: NSTextAlignment) -> Self {
        self.textAlignment = alignment
        return self
    }

    @discardableResult
    public func byNumberOfLines(_ lines: Int) -> Self {
        self.numberOfLines = lines
        return self
    }

    @discardableResult
    public func byLineBreakMode(_ mode: NSLineBreakMode) -> Self {
        self.lineBreakMode = mode
        return self
    }

    @discardableResult
    public func byBgCor(_ color: UIColor?) -> Self {
        self.backgroundColor = color
        return self
    }

    @discardableResult
    public func byAttributedString(_ attributed: NSAttributedString?) -> Self {
        self.attributedText = attributed
        return self
    }

    /// UILabel 自身的文字阴影颜色；区别于 UIView DSL 的 CALayer 阴影颜色。
    @discardableResult
    public func byLabelShadowColor(_ color: UIColor?) -> Self {
        self.shadowColor = color
        return self
    }

    /// UILabel 自身的文字阴影偏移；区别于 UIView DSL 的 CALayer 阴影偏移。
    @discardableResult
    public func byLabelShadowOffset(_ offset: CGSize = .zero) -> Self {
        self.shadowOffset = offset
        return self
    }

    @discardableResult
    public func byNextText(_ str: String?) -> Self {
        self.text = (self.text ?? "") + (str ?? "")
        return self
    }

    @discardableResult
    public func byNextAttributedText(_ attributed: NSAttributedString?) -> Self {
        if let current = self.attributedText {
            let result = NSMutableAttributedString(attributedString: current)
            if let attributed { result.append(attributed) }
            self.attributedText = result
        } else {
            self.attributedText = attributed
        };return self
    }
    @discardableResult
    public func byHugging(_ priority: UILayoutPriority,
                          axis: NSLayoutConstraint.Axis = .horizontal) -> Self {
        setContentHuggingPriority(priority, for: axis)
        return self
    }
    /// 双轴便捷
    @discardableResult
    public func byHugging(_ horizontal: UILayoutPriority,
                          _ vertical: UILayoutPriority) -> Self {
        setContentHuggingPriority(horizontal, for: .horizontal)
        setContentHuggingPriority(vertical, for: .vertical)
        return self
    }

    @discardableResult
    public func byCompressionResistance(_ priority: UILayoutPriority,
                                        axis: NSLayoutConstraint.Axis = .horizontal) -> Self {
        setContentCompressionResistancePriority(priority, for: axis)
        return self
    }
    /// 双轴便捷
    @discardableResult
    public func byCompressionResistance(_ horizontal: UILayoutPriority,
                                        _ vertical: UILayoutPriority) -> Self {
        setContentCompressionResistancePriority(horizontal, for: .horizontal)
        setContentCompressionResistancePriority(vertical, for: .vertical)
        return self
    }
    // MARK: 背景图 → 平铺色
    @discardableResult
    public func bgImage(_ image: UIImage?) -> Self {
        if let img = image {
            self.backgroundColor = UIColor(patternImage: img)
        };return self
    }

    // 高亮 / 交互 / 启用
    @discardableResult
    public func byHighlightedTextColor(_ color: UIColor?) -> Self {
        self.highlightedTextColor = color
        return self
    }

    @discardableResult
    public func byIsHighlighted(_ v: Bool) -> Self {
        self.isHighlighted = v
        return self
    }

    @discardableResult
    public func byEnabled(_ v: Bool) -> Self {
        self.isEnabled = v
        return self
    }
    // 文本压缩/缩放策略
    @discardableResult
    public func byAdjustsFontSizeToFitWidth(_ v: Bool) -> Self {
        self.adjustsFontSizeToFitWidth = v
        return self
    }

    @discardableResult
    public func byBaselineAdjustment(_ v: UIBaselineAdjustment) -> Self {
        self.baselineAdjustment = v
        return self
    }

    @discardableResult
    public func byMinimumScaleFactor(_ v: CGFloat) -> Self {
        self.minimumScaleFactor = v
        return self
    }

    @discardableResult
    public func byAllowsDefaultTighteningForTruncation(_ v: Bool) -> Self {
        self.allowsDefaultTighteningForTruncation = v
        return self
    }

    @available(iOS 14.0, *)
    @discardableResult
    public func byLineBreakStrategy(_ s: NSParagraphStyle.LineBreakStrategy) -> Self {
        self.lineBreakStrategy = s
        return self
    }
    // AutoLayout
    @discardableResult
    public func byPreferredMaxLayoutWidth(_ w: CGFloat) -> Self {
        self.preferredMaxLayoutWidth = w
        return self
    }
    // iOS 17
    @available(iOS 17.0, *)
    @discardableResult
    public func byPreferredVibrancy(_ v: UILabelVibrancy) -> Self {
        self.preferredVibrancy = v
        return self
    }

    @available(iOS 17.0, *)
    @discardableResult
    public func byShowsExpansionTextWhenTruncated(_ v: Bool) -> Self {
        self.showsExpansionTextWhenTruncated = v
        return self
    }
}
// MARK: - 闭包重载@单参数
extension UILabel {
    @discardableResult
    public func byJobsAttributedText(_ builder: () -> JobsText?) -> Self {
        _byApplyOptional(builder) { [weak self] text in
            guard let self else { return }
            self.attributedText = text.asAttributed
        }
    }

    @discardableResult
    public func byJobsText(_ builder: () -> JobsText?) -> Self {
        _byApplyOptional(builder) { [weak self] text in
            guard let self else { return }
            self.text = text.asString
        }
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
        self.adjustsFontForContentSizeCategory = false
        return _byApplyOptional(builder) { [weak self] font in
            guard let self else { return }
            self.font = font
        }
    }

    @discardableResult
    public func byTextAlignment(_ builder: () -> NSTextAlignment) -> Self {
        _byApplyValue(builder) { [weak self] alignment in
            guard let self else { return }
            self.textAlignment = alignment
        }
    }

    @discardableResult
    public func byNumberOfLines(_ builder: () -> Int) -> Self {
        _byApplyValue(builder) { [weak self] lines in
            guard let self else { return }
            self.numberOfLines = lines
        }
    }

    @discardableResult
    public func byLineBreakMode(_ builder: () -> NSLineBreakMode) -> Self {
        _byApplyValue(builder) { [weak self] mode in
            guard let self else { return }
            self.lineBreakMode = mode
        }
    }

    @discardableResult
    public func byBgCor(_ builder: () -> UIColor?) -> Self {
        self.backgroundColor = builder()
        return self
    }

    @discardableResult
    public func byAttributedString(_ builder: () -> NSAttributedString?) -> Self {
        self.attributedText = builder()
        return self
    }

    @discardableResult
    public func byHighlightedTextColor(_ builder: () -> UIColor?) -> Self {
        self.highlightedTextColor = builder()
        return self
    }

    @discardableResult
    public func byIsHighlighted(_ builder: () -> Bool) -> Self {
        _byApplyValue(builder) { [weak self] value in
            guard let self else { return }
            self.isHighlighted = value
        }
    }

    @discardableResult
    public func byEnabled(_ builder: () -> Bool) -> Self {
        _byApplyValue(builder) { [weak self] value in
            guard let self else { return }
            self.isEnabled = value
        }
    }

    @discardableResult
    public func byAdjustsFontSizeToFitWidth(_ builder: () -> Bool) -> Self {
        _byApplyValue(builder) { [weak self] value in
            guard let self else { return }
            self.adjustsFontSizeToFitWidth = value
        }
    }

    @discardableResult
    public func byBaselineAdjustment(_ builder: () -> UIBaselineAdjustment) -> Self {
        _byApplyValue(builder) { [weak self] value in
            guard let self else { return }
            self.baselineAdjustment = value
        }
    }

    @discardableResult
    public func byMinimumScaleFactor(_ builder: () -> CGFloat) -> Self {
        _byApplyValue(builder) { [weak self] value in
            guard let self else { return }
            self.minimumScaleFactor = value
        }
    }

    @discardableResult
    public func byAllowsDefaultTighteningForTruncation(_ builder: () -> Bool) -> Self {
        _byApplyValue(builder) { [weak self] value in
            guard let self else { return }
            self.allowsDefaultTighteningForTruncation = value
        }
    }

    @discardableResult
    public func byPreferredMaxLayoutWidth(_ builder: () -> CGFloat) -> Self {
        _byApplyValue(builder) { [weak self] value in
            guard let self else { return }
            self.preferredMaxLayoutWidth = value
        }
    }

    @available(iOS 14.0, *)
    @discardableResult
    public func byLineBreakStrategy(_ builder: () -> NSParagraphStyle.LineBreakStrategy) -> Self {
        _byApplyValue(builder) { [weak self] value in
            guard let self else { return }
            self.lineBreakStrategy = value
        }
    }

    @available(iOS 17.0, *)
    @discardableResult
    public func byPreferredVibrancy(_ builder: () -> UILabelVibrancy) -> Self {
        _byApplyValue(builder) { [weak self] value in
            guard let self else { return }
            self.preferredVibrancy = value
        }
    }

    @available(iOS 17.0, *)
    @discardableResult
    public func byShowsExpansionTextWhenTruncated(_ builder: () -> Bool) -> Self {
        _byApplyValue(builder) { [weak self] value in
            guard let self else { return }
            self.showsExpansionTextWhenTruncated = value
        }
    }
}
