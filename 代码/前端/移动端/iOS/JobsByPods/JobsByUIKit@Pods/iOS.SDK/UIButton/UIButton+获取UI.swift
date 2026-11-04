//
//  UIButton+获取UI.swift
//  JobsByUIKit
//
//  Created by Jobs on 2026年5月13日，星期三.
//

#if os(OSX)
import AppKit
#elseif os(iOS) || os(tvOS)
import UIKit
#endif

import JobsSwiftDSL

// MARK: - 获取@标题、副标题、前景图、背景图
extension UIButton {
    @discardableResult
    public func byTitleLab(_ config: ((UILabel) -> Void)?) -> Self {
        if let lab = self.titleLabel {
            config?(lab)
        };return self
    }

    @available(iOS 15.0, *)
    @discardableResult
    public func bySubTitleLab(_ config: ((UILabel) -> Void)?) -> Self {
        if let lab = self.subtitleLabel {
            config?(lab)
        };return self
    }
    // MARK: 业务视角的“有效状态”
    /// 业务视角的有效状态：disabled > highlighted > selected > normal
    /// 用于：读取当前展示相关属性（颜色/标题/图片等）
    public var jobs_effectiveState: UIControl.State {
        if !isEnabled { return .disabled }
        if isHighlighted { return .highlighted }
        if isSelected { return .selected };return .normal
    }
    // MARK: Title（String / Attributed）
    /// 当前业务视角下的主标题：
    /// 优先 Configuration(.attributedTitle / .title)，再兜底 legacy title(for:)
    public var title: String? {
        return jobs_title(for: jobs_effectiveState)
    }
    /// 按状态取主标题（业务视角）
    public func jobs_title(for state: UIControl.State) -> String? {
        if #available(iOS 15.0, *), let cfg = configuration {
            if let att = cfg.attributedTitle { return String(att.characters) }
            if let t = cfg.title { return t }
        };return self.title(for: state)
            ?? self.attributedTitle(for: state)?.string
            ?? self.title(for: .normal)
            ?? self.attributedTitle(for: .normal)?.string
    }
    /// 按状态取主标题 attributed（业务视角）
    public func jobs_attributedTitle(for state: UIControl.State) -> NSAttributedString? {
        if #available(iOS 15.0, *), let cfg = configuration {
            // Configuration 模式下通常只配置了一份 attributedTitle，不按 state 分开
            if let att = cfg.attributedTitle { return NSAttributedString(att) }
        };return self.attributedTitle(for: state) ?? self.attributedTitle(for: .normal)
    }
    // MARK: SubTitle（String / Attributed）
    /// 当前业务视角下的副标题：
    /// 优先 Configuration(.attributedSubtitle / .subtitle)；
    /// iOS 15 以下只能从你之前组合的 “title\nsubtitle” 里拆（best-effort）。
    public var subTitle: String? {
        jobs_subTitle(for: jobs_effectiveState)
    }
    /// 按状态取副标题（业务视角）
    public func jobs_subTitle(for state: UIControl.State) -> String? {
        if #available(iOS 15.0, *), let cfg = configuration {
            if let att = cfg.attributedSubtitle { return String(att.characters) }
            if let t = cfg.subtitle { return t }
        }
        // < iOS 15：你 bySubTitle 的旧实现是 title + "\n" + subTitle，这里尽量拆一下
        let full = self.title(for: state)
            ?? self.attributedTitle(for: state)?.string
            ?? self.title(for: .normal)
            ?? self.attributedTitle(for: .normal)?.string
        guard
            let full,
            let idx = full.firstIndex(of: "\n"),
            full.index(after: idx) < full.endIndex
        else { return nil }
        let sub = full[full.index(after: idx)...]
        return String(sub)
    }
    /// 按状态取副标题 attributed（业务视角）
    public func jobs_attributedSubTitle(for state: UIControl.State) -> NSAttributedString? {
        if #available(iOS 15.0, *), let cfg = configuration {
            if let att = cfg.attributedSubtitle { return NSAttributedString(att) }
        };return nil // iOS15-：副标题往往不是单独 attributed 存储，基本拿不到；这里返回 nil
    }
    // MARK: Images
    /// 当前前景图：优先 Configuration.image，再兜底 image(for:)
    public var foregroundImage: UIImage? {
        jobs_foregroundImage(for: jobs_effectiveState)
    }

    public func jobs_foregroundImage(for state: UIControl.State) -> UIImage? {
        if #available(iOS 15.0, *),
           let cfg = configuration,
           let img = cfg.image {
            return img
        };return self.image(for: state) ?? self.image(for: .normal)
    }
    /// 当前背景图：优先 Configuration.background.image，再兜底 backgroundImage(for:)
    public var backgroundImage: UIImage? {
        jobs_backgroundImage(for: jobs_effectiveState)
    }

    public func jobs_backgroundImage(for state: UIControl.State) -> UIImage? {
        if #available(iOS 15.0, *),
           let cfg = configuration,
           let img = cfg.background.image {
            return img
        };return self.backgroundImage(for: state) ?? self.backgroundImage(for: .normal)
    }
}
// MARK: - 获取@标题/副标题 颜色 & 字体（给动画/渲染用）
extension UIButton {
    // MARK: Title color / font
    /// 主标题颜色（业务视角 best-effort）
    public func jobs_titleColor(for state: UIControl.State) -> UIColor? {
        // 1) Configuration.attributedTitle 里如果写了颜色，优先取
        if let att = jobs_attributedTitle(for: state),
           let c = att.jobs_firstColor {
            return c
        }
        // 2) iOS15+ Configuration 的 baseForegroundColor 可能影响 title/subtitle
        if #available(iOS 15.0, *), let cfg = configuration, let c = cfg.baseForegroundColor {
            return c
        };return self.titleColor(for: state) ?? self.titleColor(for: .normal) // 3) legacy
    }
    /// 读取 DSL 记录的标题字体（最可靠）
    public func jobs_dslTitleFont(for state: UIControl.State) -> UIFont? {
        // 你内部已经有 _titleFontDict
        _titleFontDict[state.rawValue] ?? _titleFontDict[UIControl.State.normal.rawValue]
    }
    /// 主标题字体（业务视角 best-effort）
    public func jobs_titleFont(for state: UIControl.State) -> UIFont? {
        let st = (state == .normal) ? jobs_effectiveState : state
        // ✅ 0) 最优先：读 DSL 缓存（不会被系统“冲”）
        if let f = jobs_dslTitleFont(for: st) {
            return f
        }
        if let f = jobs_dslTitleFont(for: .normal) {
            return f
        }
        // 1) attributedTitle 里如果写了 UIFont，也返回
        if let att = self.attributedTitle(for: st), let f = att.jobs_firstFont { return f }
        if let att = self.attributedTitle(for: .normal), let f = att.jobs_firstFont { return f }
        // 2) iOS15+ configuration.attributedTitle
        if #available(iOS 15.0, *),
           let cfg = configuration,
           let att = cfg.attributedTitle {
            let ns = NSAttributedString(att)
            if let f = ns.jobs_firstFont { return f }
        }
        // 3) 最后兜底（不稳）
        return self.titleLabel?.font
    }
    // MARK: SubTitle color / font
    /// 副标题颜色（业务视角 best-effort）
    public func jobs_subTitleColor(for state: UIControl.State) -> UIColor? {
        // 1) Configuration.attributedSubtitle 里写了颜色
        if let att = jobs_attributedSubTitle(for: state),
           let c = att.jobs_firstColor {
            return c
        }
        // 2) iOS15+ Configuration baseForegroundColor（副标题也常跟它走）
        if #available(iOS 15.0, *), let cfg = configuration, let c = cfg.baseForegroundColor {
            return c
        }
        // 3) subtitleLabel 当前颜色（注意：它不区分 state）
        if #available(iOS 15.0, *), let lab = subtitleLabel {
            return lab.textColor
        };return nil // 4) iOS15-：通常没有独立副标题 label，这里只能 nil
    }
    /// 副标题字体（业务视角 best-effort）
    public func jobs_subTitleFont(for state: UIControl.State) -> UIFont? {
        if let att = jobs_attributedSubTitle(for: state),
           let f = att.jobs_firstFont {
            return f
        }
        if #available(iOS 15.0, *), let lab = subtitleLabel {
            return lab.font
        };return nil
    }
}
// MARK: - 获取@contentEdgeInsets、imageEdgeInsets（兼容Configuration）
extension UIButton {
    /// ✅ 业务视角下的「内容内边距」：
    /// - iOS/tvOS 15+ 且使用 UIButton.Configuration 时：读取 cfg.contentInsets
    /// - 否则：读取 legacy contentEdgeInsets（⚠️ iOS15+ deprecated 但仍可存取）
    public var jobs_contentEdgeInsets: UIEdgeInsets {
        if #available(iOS 15.0, tvOS 15.0, *), let cfg = self.configuration {
            return jobs_uiEdgeInsets(from: cfg.contentInsets)
        };return jobs_legacyContentEdgeInsets
    }
    /// ✅ 业务视角下的「图片内边距」：
    /// - iOS/tvOS 15+ 且使用 UIButton.Configuration 时：legacy imageEdgeInsets 会被系统忽略
    ///   所以这里返回 .zero（并建议改用 cfg.imagePadding / cfg.imagePlacement）
    /// - 否则：读取 legacy imageEdgeInsets
    public var jobs_imageEdgeInsets: UIEdgeInsets {
        if #available(iOS 15.0, tvOS 15.0, *), self.configuration != nil {
            return .zero
        };return jobs_legacyImageEdgeInsets
    }
    /// ✅ 读取 legacy contentEdgeInsets（避免直接引用 deprecated API 产生 warning）
    public var jobs_legacyContentEdgeInsets: UIEdgeInsets {
        jobs_kvcEdgeInsets("contentEdgeInsets")
    }
    /// ✅ 读取 legacy imageEdgeInsets（避免直接引用 deprecated API 产生 warning）
    public var jobs_legacyImageEdgeInsets: UIEdgeInsets {
        jobs_kvcEdgeInsets("imageEdgeInsets")
    }
    /// iOS/tvOS 15+：Configuration 模式下等价信息
    @available(iOS 15.0, tvOS 15.0, *)
    public var jobs_cfgContentInsets: NSDirectionalEdgeInsets? {
        self.configuration?.contentInsets
    }

    @available(iOS 15.0, tvOS 15.0, *)
    public var jobs_cfgImagePadding: CGFloat? {
        self.configuration?.imagePadding
    }

    @available(iOS 15.0, tvOS 15.0, *)
    public var jobs_cfgImagePlacement: NSDirectionalRectEdge? {
        self.configuration?.imagePlacement
    }
}

extension UIButton {
    /// 用 KVC 读取 UIEdgeInsets，避免直接触达 iOS15+ deprecated 的属性导致编译 warning。
    /// - Note: 在使用 UIButton.Configuration 时，这些 legacy 值「可能存在但不会生效」。
    fileprivate func jobs_kvcEdgeInsets(_ key: String) -> UIEdgeInsets {
        guard let v = self.value(forKey: key) as? NSValue else { return .zero };return v.uiEdgeInsetsValue
    }

    @available(iOS 15.0, tvOS 15.0, *)
    fileprivate func jobs_uiEdgeInsets(from di: NSDirectionalEdgeInsets) -> UIEdgeInsets {
        // Directional -> UIEdgeInsets 需要考虑 RTL
        let isRTL = (self.effectiveUserInterfaceLayoutDirection == .rightToLeft)
        let left = isRTL ? di.trailing : di.leading
        let right = isRTL ? di.leading : di.trailing
        return UIEdgeInsets(top: di.top, left: left, bottom: di.bottom, right: right)
    }
}
// MARK: - NSAttributedString helper（只拿第一段属性，够动画用）
private extension NSAttributedString {
    var jobs_firstColor: UIColor? {
        guard length > 0 else { return nil }
        let c = attribute(.foregroundColor, at: 0, effectiveRange: nil)
        return c as? UIColor
    }

    var jobs_firstFont: UIFont? {
        guard length > 0 else { return nil }
        let f = attribute(.font, at: 0, effectiveRange: nil)
        return f as? UIFont
    }
}
