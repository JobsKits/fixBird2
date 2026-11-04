//
//  UIView+右上角角标.swift
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
import JobsSwiftDSL

// MARK: - 公共类型@右上角角标
public enum RTBadgeContent {
    case text(String)
    case attributed(NSAttributedString)
    case custom(UIView)
}

public struct RTBadgeConfig {
    public var backgroundColor: UIColor = JobsCor.systemRed
    public var textColor: UIColor = JobsCor.white
    public var font: UIFont = JobsFont.systemFont(ofSize: 12, weight: .semibold)
    /// nil = 自动按高度一半做胶囊圆角；给值则为固定圆角
    public var cornerRadius: CGFloat? = nil
    public var insets: UIEdgeInsets = .init(top: 2, left: 6, bottom: 2, right: 6)
    /// (+x 向右, +y 向下)。右上角常用：(-4, 4)
    public var offset: UIOffset = .init(horizontal: -4, vertical: 4)
    public var maxWidth: CGFloat = 200
    public var borderColor: UIColor? = nil
    public var borderWidth: CGFloat = 0
    public var shadowColor: UIColor? = nil
    public var shadowRadius: CGFloat = 0
    public var shadowOpacity: Float = 0
    public var shadowOffset: CGSize = .zero
    public var zIndex: CGFloat = 9999
    public init() {}
}

public extension RTBadgeConfig {
    @discardableResult
    func byOffset(_ v: UIOffset = .init(horizontal: -6, vertical: 6)) -> Self {
        var c = self; c.offset = v; return c
    }

    @discardableResult
    func byInsets(_ v: UIEdgeInsets = .init(top: 2, left: 6, bottom: 2, right: 6)) -> Self {
        var c = self; c.insets = v; return c
    }

    @discardableResult
    func byInset(_ v: UIEdgeInsets = .init(top: 2, left: 6, bottom: 2, right: 6)) -> Self {
        var c = self; c.insets = v; return c
    }

    @discardableResult
    func byBackgroundColor(_ v: UIColor = JobsCor.systemRed) -> Self {
        var c = self; c.backgroundColor = v; return c
    }

    @discardableResult
    func byTextColor(_ v: UIColor = JobsCor.white) -> Self {
        var c = self; c.textColor = v; return c
    }

    @discardableResult
    func byFont(_ v: UIFont = JobsFont.systemFont(ofSize: 11, weight: .bold)) -> Self {
        var c = self; c.font = v; return c
    }

    @discardableResult
    func byCornerRadius(_ v: CGFloat? = nil) -> Self {
        var c = self; c.cornerRadius = v; return c
    }

    @discardableResult
    func byBorder(color: UIColor? = nil, width: CGFloat = 0) -> Self {
        var c = self; c.borderColor = color; c.borderWidth = width; return c
    }

    @discardableResult
    func byMaxWidth(_ v: CGFloat = 200) -> Self {
        var c = self; c.maxWidth = v; return c
    }

    @discardableResult
    func byZIndex(_ v: CGFloat = 9999) -> Self {
        var c = self; c.zIndex = v; return c
    }

    @discardableResult
    func byShadowColor(_ v: UIColor?) -> Self {
        var c = self; c.shadowColor = v; return c
    }

    @discardableResult
    func byShadowRadius(_ v: CGFloat) -> Self {
        var c = self; c.shadowRadius = v; return c
    }

    @discardableResult
    func byShadowOpacity(_ v: Float) -> Self {
        var c = self; c.shadowOpacity = v; return c
    }

    @discardableResult
    func byShadowOffset(_ v: CGSize) -> Self {
        var c = self; c.shadowOffset = v; return c
    }

    @discardableResult
    func byShadow(
        color: UIColor? = JobsCor.black.withAlphaComponent(0.25),
        radius: CGFloat = 2,
        opacity: Float = 0.6,
        offset: CGSize = .init(width: 0, height: 1)
    ) -> Self {
        self
            .byShadowColor(color)
            .byShadowRadius(radius)
            .byShadowOpacity(opacity)
            .byShadowOffset(offset)
    }
}

extension UIView {
    /// 右上角角标：添加/更新，内容自定义（SnapKit 约束）
    @discardableResult
    public func byCornerBadge(_ content: RTBadgeContent,
                              build: ((RTBadgeConfig) -> RTBadgeConfig)? = nil) -> Self {
        assert(Thread.isMainThread, "UI must be updated on main thread")
        var cfg = RTBadgeConfig()
        if let build = build { cfg = build(cfg) }
        let container = ensureRTBadgeContainer()
        if container.superview !== self { addSubview(container) }
        container.byUserInteractionEnabled(false)
            .byMasksToBounds(false)
            .byBorderColor(cfg.borderColor)
            .byZPosition(cfg.zIndex)
            .byBackgroundColor(cfg.backgroundColor)
            .byBorderWidth(cfg.borderWidth)
        if let sc = cfg.shadowColor {
            container.byShadowColor(sc)
                .byShadowRadius(cfg.shadowRadius)
                .byShadowOpacity(cfg.shadowOpacity)
                .byShadowOffset(cfg.shadowOffset)
        } else {
            container.byShadowOpacity(cfg.shadowOpacity)
        }
        /// 内容
        install(content, into: container, config: cfg)
        /// 右上角定位（SnapKit）
        installRTBadgeConstraints(container: container,
                                  offset: cfg.offset,
                                  maxWidth: cfg.maxWidth)
        /// 圆角
        if let r = cfg.cornerRadius {
            container.autoCapsule = false
            container.byShadowRadius(r)
        } else {
            container.autoCapsule = true // 在 layoutSubviews 按高度一半
            container.refresh()
        };return self
    }
    /// 右上角角标：快捷文本
    @discardableResult
    public func byCornerBadgeText(_ text: String,
                                  build: ((RTBadgeConfig) -> RTBadgeConfig)? = nil) -> Self {
        byCornerBadge(.text(text), build: build)
    }
    /// 右上角小红点（纯圆）
    @discardableResult
    public func byCornerDot(diameter: CGFloat = 8,
                            offset: UIOffset = .init(horizontal: -4, vertical: 4),
                            color: UIColor = JobsCor.systemRed) -> Self {
        return byCornerBadge(.custom(UIView()
            .byBackgroundColor(color)
            .byCornerRadius(diameter / 2)
            .byAdd({ make in
                make.width.height.equalTo(diameter)
            }))) { cfg in
                cfg.byInset(.zero)
                    .byCornerRadius(diameter / 2)
                    .byOffset(offset)
                    .byBackgroundColor(JobsCor.clear)
                    .byBorder(color: nil, width: 0)
                    .byShadow(color: nil)
        }
    }
    /// 显示/隐藏（右上角）
    @discardableResult
    public func setCornerBadgeHidden(_ hidden: Bool,
                                     animated: Bool = false,
                                     duration: TimeInterval = 0.2) -> Self {
        guard let v = rt_badgeContainer() else { return self }
        let work = { v.alpha = hidden ? 0 : 1 }
        animated ? UIView.animate(withDuration: duration, animations: work) : work()
        return self
    }
    /// 移除（右上角）
    @discardableResult
    public func removeCornerBadge() -> Self {
        rt_badgeContainer()?.removeFromSuperview()
        setRTBadgeContainer(nil)
        return self
    }
}

private final class _BadgeContainerView: UIView {
    var autoCapsule: Bool = true
    override func layoutSubviews() {
        super.layoutSubviews()
        if autoCapsule {
            byCornerRadius(bounds.height / 2)
        }
    }
}
/// 仅一个 key（右上角）
private enum _RTBadgeKey { static var tr: UInt8 = 0 }
extension UIView {
    private func ensureRTBadgeContainer() -> _BadgeContainerView {
        if let v = rt_badgeContainer() as? _BadgeContainerView { return v }
        let v = _BadgeContainerView()
        setRTBadgeContainer(v)
        addSubview(v)
        return v
    }

    private func rt_badgeContainer() -> UIView? {
        objc_getAssociatedObject(self, &_RTBadgeKey.tr) as? UIView
    }

    private func setRTBadgeContainer(_ v: UIView?) {
        objc_setAssociatedObject(
            self,
            &_RTBadgeKey.tr,
            v,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
    }

    private func install(_ content: RTBadgeContent,
                         into container: _BadgeContainerView,
                         config: RTBadgeConfig) {
        container.subviews.forEach { $0.removeFromSuperview() }
        switch content {
        /// 处理 .text 分支
        case .text(let s):
            let label = _InsetLabel()
                .byText(s)
                .byTextColor(config.textColor)
                .byFont(config.font)
                .byNumberOfLines(1)
                .byContentInsets(config.insets)
                .byAddTo(container) { [unowned self] make in
                    make.edges.equalToSuperview()
                }
            label.setContentCompressionResistancePriority(.required, for: .horizontal)
            label.setContentHuggingPriority(.required, for: .horizontal)
        /// 处理 .attributed 分支
        case .attributed(let attr):
            let label = _InsetLabel()
                .byAttributedString(attr)
                .byTextColor(config.textColor)
                .byFont(config.font)
                .byNumberOfLines(1)
                .byContentInsets(config.insets)
                .byAddTo(container) { [unowned self] make in
                    make.edges.equalToSuperview()
                }
            label.setContentCompressionResistancePriority(.required, for: .horizontal)
            label.setContentHuggingPriority(.required, for: .horizontal)
        /// 处理 .custom 分支
        case .custom(let view):
            view.byAddTo(container) { [unowned self] make in
                make.edges.equalToSuperview().inset(config.insets)
            }
        }
    }
    /// 右上角定位（统一 remake，避免重复约束）
    private func installRTBadgeConstraints(container: UIView,
                                           offset: UIOffset,
                                           maxWidth: CGFloat) {
        // ② installRTBadgeConstraints(container:offset:maxWidth:)
        container.snp.remakeConstraints { make in
            make.top.equalToSuperview().offset(offset.vertical)
            make.right.equalToSuperview().offset(offset.horizontal)
            make.width.lessThanOrEqualTo(maxWidth)
        }
        container.setContentCompressionResistancePriority(.required, for: .horizontal)
        container.setContentHuggingPriority(.required, for: .horizontal)
    }
}

private final class _InsetLabel: UILabel {
    /// 文本内容的内边距（默认为 .zero）
    var contentInsets: UIEdgeInsets = .zero {
        didSet {
            guard oldValue != contentInsets else { return }
            invalidateIntrinsicContentSize()
            refresh()
            setNeedsLayout()
            setNeedsDisplay()
        }
    }
    /// 实际绘制：直接在缩减后的区域画
    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.inset(by: contentInsets))
    }
    /// 参与 Auto Layout 的固有尺寸：加上内边距
    override var intrinsicContentSize: CGSize {
        let s = super.intrinsicContentSize
        return CGSize(width: s.width + contentInsets.left + contentInsets.right,
                      height: s.height + contentInsets.top + contentInsets.bottom)
    }
    /// 计算文本绘制矩形：先缩进，再把结果外扩回去（系统要求）
    override func textRect(forBounds bounds: CGRect, limitedToNumberOfLines numberOfLines: Int) -> CGRect {
        /// 先将可用区域减去内边距
        let insetBounds = bounds.inset(by: contentInsets)
        /// 让父类在缩减后的区域中排版
        let textRect = super.textRect(forBounds: insetBounds, limitedToNumberOfLines: numberOfLines)
        /// 再把结果外扩回原坐标系（相当于“反向”内边距）
        let out = UIEdgeInsets(top: -contentInsets.top, left: -contentInsets.left,
                               bottom: -contentInsets.bottom, right: -contentInsets.right)
        return textRect.inset(by: out)
    }
}
// MARK: - 链式 DSL
private extension _InsetLabel {
    /// 直接设置 UIEdgeInsets
    @discardableResult
    func byContentInsets(_ insets: UIEdgeInsets) -> Self {
        self.contentInsets = insets
        return self
    }
    /// 上下左右等距
    @discardableResult
    func byContentInsets(_ all: CGFloat) -> Self {
        self.contentInsets = UIEdgeInsets(top: all,
                                          left: all,
                                          bottom: all,
                                          right: all)
        return self
    }
    /// 垂直/水平 分量设置（例如 vertical=6, horizontal=10）
    @discardableResult
    func byContentInsets(vertical v: CGFloat, horizontal h: CGFloat) -> Self {
        self.contentInsets = UIEdgeInsets(top: v,
                                          left: h,
                                          bottom: v,
                                          right: h)
        return self
    }
    /// 分别指定四边
    @discardableResult
    func byContentInsets(top: CGFloat,
                         left: CGFloat,
                         bottom: CGFloat,
                         right: CGFloat) -> Self {
        self.contentInsets = UIEdgeInsets(top: top,
                                          left: left,
                                          bottom: bottom,
                                          right: right)
        return self
    }
}
