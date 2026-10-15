//
//  UITableViewCell+DSL.swift
//  JobsSwiftDSL
//
//  Created by Jobs on 2026年5月13日，星期三.
//

#if os(OSX)
import AppKit
#elseif os(iOS) || os(tvOS)
import UIKit
#endif

import JobsTextTools

#if canImport(JobsSwiftBaseDefines)
import JobsSwiftBaseDefines
#endif

// MARK: - UITableViewCell · 基础状态 & 选择/高亮/编辑
private extension UITableViewCell {
    func jobsApplyTitleColor(_ color: UIColor) {
        if #available(iOS 14.0, *) {
            _ = byContentConfiguration { cfg in
                cfg.textProperties.color = color
            }
        } else {
            textLabel?.textColor = color
        }
    }

    func jobsApplyDetailTitleColor(_ color: UIColor) {
        if #available(iOS 14.0, *) {
            _ = byContentConfiguration { cfg in
                cfg.secondaryTextProperties.color = color
            }
        } else {
            detailTextLabel?.textColor = color
        }
    }
}

extension UITableViewCell {
    /// 收口 Cell 子视图配置，保证调用端以 Cell 为唯一链起点。
    @discardableResult
    public func byTextLabel(_ build: (UILabel) -> Void) -> Self {
        if let textLabel {
            build(textLabel)
        };return self
    }

    @discardableResult
    public func byDetailTextLabel(_ build: (UILabel) -> Void) -> Self {
        if let detailTextLabel {
            build(detailTextLabel)
        };return self
    }

    @discardableResult
    public func byImageView(_ build: (UIImageView) -> Void) -> Self {
        if let imageView {
            build(imageView)
        };return self
    }

    @discardableResult
    public func byContentView(_ build: (UIView) -> Void) -> Self {
        build(contentView)
        return self
    }

    /// selectionStyle
    @discardableResult
    public func bySelectionStyle(_ style: UITableViewCell.SelectionStyle) -> Self {
        self.selectionStyle = style
        return self
    }
    /// isSelected（支持动画）
    @discardableResult
    public func bySelected(_ selected: Bool, animated: Bool = false) -> Self {
        self.setSelected(selected, animated: animated)
        return self
    }
    /// isHighlighted（支持动画）
    @discardableResult
    public func byHighlighted(_ highlighted: Bool, animated: Bool = false) -> Self {
        self.setHighlighted(highlighted, animated: animated)
        return self
    }
    /// 编辑状态
    @discardableResult
    public func byEditing(_ editing: Bool, animated: Bool = true) -> Self {
        self.setEditing(editing, animated: animated)
        return self
    }
    /// accessoryType / accessoryView
    @discardableResult
    public func byAccessoryType(_ type: UITableViewCell.AccessoryType) -> Self {
        self.accessoryType = type
        return self
    }

    @discardableResult
    public func byAccessoryView(_ view: UIView?) -> Self {
        self.accessoryView = view
        return self
    }
    /// 编辑态 accessory
    @discardableResult
    public func byEditingAccessoryType(_ type: UITableViewCell.AccessoryType) -> Self {
        self.editingAccessoryType = type
        return self
    }

    @discardableResult
    public func byEditingAccessoryView(_ view: UIView?) -> Self {
        self.editingAccessoryView = view
        return self
    }
    /// 缩进 & 拖拽/重排
    @discardableResult
    public func byIndentationLevel(_ level: Int) -> Self {
        self.indentationLevel = level
        return self
    }

    @discardableResult
    public func byIndentationWidth(_ width: CGFloat) -> Self {
        self.indentationWidth = width
        return self
    }

    @discardableResult
    public func byShowsReorderControl(_ show: Bool) -> Self {
        self.showsReorderControl = show
        return self
    }

    @discardableResult
    public func byShouldIndentWhileEditing(_ indent: Bool) -> Self {
        self.shouldIndentWhileEditing = indent
        return self
    }
    /// 分割线 inset
    @discardableResult
    public func bySeparatorInset(_ inset: UIEdgeInsets) -> Self {
        self.separatorInset = inset
        return self
    }
    /// 背景视图
    @discardableResult
    public func byBackgroundView(_ view: UIView?) -> Self {
        self.backgroundView = view
        return self
    }

    @discardableResult
    public func bySelectedBackgroundView(_ view: UIView?) -> Self {
        self.selectedBackgroundView = view
        return self
    }

    @discardableResult
    public func byMultipleSelectionBackgroundView(_ view: UIView?) -> Self {
        self.multipleSelectionBackgroundView = view
        return self
    }
    /// 焦点 & 拖拽
    @available(iOS 9.0, *)
    @discardableResult
    public func byFocusStyle(_ style: UITableViewCell.FocusStyle) -> Self {
        self.focusStyle = style
        return self
    }

    @available(iOS 11.0, *)
    @discardableResult
    public func byUserInteractionEnabledWhileDragging(_ enabled: Bool) -> Self {
        self.userInteractionEnabledWhileDragging = enabled
        return self
    }
}
// MARK: - iOS 14+ List Content（文本/副标题/图片 的统一配置）
extension UITableViewCell {
    /// 直接覆盖任意 contentConfiguration。
    @available(iOS 14.0, *)
    @discardableResult
    public func byContentConfiguration(_ configuration: UIContentConfiguration?) -> Self {
        contentConfiguration = configuration
        return self
    }

    /// 直接覆盖 contentConfiguration（默认会禁用自动更新，避免被系统覆盖）
    @available(iOS 14.0, *)
    @discardableResult
    public func byContentConfiguration(_ build: (inout UIListContentConfiguration) -> Void,
                                       automaticallyUpdates: Bool = false) -> Self {
        // ✅ 优先基于当前的 configuration 继续修改，避免每次重建把之前的覆盖掉
        var cfg: UIListContentConfiguration
        if let current = contentConfiguration as? UIListContentConfiguration {
            cfg = current
        } else {
            cfg = defaultContentConfiguration()
        }
        build(&cfg)
        automaticallyUpdatesContentConfiguration = automaticallyUpdates
        contentConfiguration = cfg
        return self
    }
    /// 解析为富文本
    public func byJobsAttributedText(_ text: JobsText?) -> Self {
        guard let text else { return self }
        if #available(iOS 14.0, *) {
            return byContentConfiguration { $0.attributedText = text.asAttributed }
        } else {
            self.textLabel?.attributedText = text.asAttributed
            return self
        };
    }
    /// 解析为普通文本
    public func byJobsText(_ text: JobsText?) -> Self {
        guard let text else { return self }
        if #available(iOS 14.0, *) {
            return byContentConfiguration { $0.text = text.asString }
        } else {
            self.textLabel?.text = text.asString
            return self
        };
    }
    @discardableResult
    public func byText(_ text: String?) -> Self {
        if #available(iOS 14.0, *) {
            return byContentConfiguration { $0.text = text }
        } else {
            self.textLabel?.text = text
            return self
        }
    }
    public func bySecondaryJobsText(_ text: JobsText?) -> Self {
        guard let text else { return self }
        if #available(iOS 14.0, *) {
            return byContentConfiguration { $0.secondaryAttributedText = text.asAttributed }
        } else {
            self.detailTextLabel?.attributedText = text.asAttributed
            return self
        };
    }
    /// 富文本标题
    @discardableResult
    public func byAttributedText(_ text: NSAttributedString?) -> Self {
        if #available(iOS 14.0, *) {
            return byContentConfiguration { $0.attributedText = text }
        } else {
            self.textLabel?.attributedText = text
            return self
        }
    }
    /// 副标题
    @discardableResult
    public func bySecondaryText(_ text: String?) -> Self {
        if #available(iOS 14.0, *) {
            return byContentConfiguration { $0.secondaryText = text }
        } else {
            byDetailText(text) // 旧系统需要 .subtitle 风格才显示
            return self
        }
    }

    @discardableResult
    public func byDetailText(_ text: String?) -> Self {
        self.detailTextLabel?.text = text
        return self
    }

    @discardableResult
    public func byDetailAttributedText(_ text: NSAttributedString?) -> Self {
        self.detailTextLabel?.attributedText = text
        return self
    }
    /// 富文本副标题
    @discardableResult
    public func byAttributedSecondaryText(_ text: NSAttributedString?) -> Self {
        if #available(iOS 14.0, *) {
            return byContentConfiguration { $0.secondaryAttributedText = text }
        } else {
            byDetailAttributedText(text)
            return self
        }
    }
    /// 主图
    @discardableResult
    public func byImage(_ image: UIImage?) -> Self {
        if #available(iOS 14.0, *) {
            return byContentConfiguration { $0.image = image }
        } else {
            self.imageView?.image = image
            return self
        }
    }
    /// 文本行数/对齐/间距等（iOS14+）
    @available(iOS 14.0, *)
    @discardableResult
    public func byTextConfig(_ build: (inout UIListContentConfiguration) -> Void) -> Self {
        return byContentConfiguration(build)
    }
}
// MARK: - iOS 14+ 背景配置（分离语义：选中/高亮自动更新）
extension UITableViewCell {
    @available(iOS 14.0, *)
    @discardableResult
    public func byBackgroundConfiguration(_ build: (inout UIBackgroundConfiguration) -> Void,
                                   automaticallyUpdates: Bool = false) -> Self {
        var bg = UIBackgroundConfiguration.listPlainCell()
        build(&bg)
        self.automaticallyUpdatesBackgroundConfiguration = automaticallyUpdates
        self.backgroundConfiguration = bg
        return self
    }
    /// 快捷：选中态背景色
    @available(iOS 14.0, *)
    @discardableResult
    public func bySelectedBackgroundColor(_ color: UIColor?) -> Self {
        return byBackgroundConfiguration { bg in
            bg.backgroundColor = JobsCor.clear
            if let color {
                var selected = UIBackgroundConfiguration.listPlainCell()
                selected.backgroundColor = color
                self.setHighlighted(self.isHighlighted, animated: false)
                self.setSelected(self.isSelected, animated: false)
                self.selectedBackgroundView = {
                    return UIView().byBackgroundColor(color)
                }()
            } else {
                self.selectedBackgroundView = nil
            }
        }
    }
}

extension UITableViewCell {
    /// 标题字体
    @discardableResult
    public func byTitleFont(_ font: UIFont) -> Self {
        if #available(iOS 14.0, *) {
            return byContentConfiguration { cfg in
                cfg.textProperties.font = font
            }
        } else {
            // ✅ iOS 13-
            textLabel?.font = font
            return self
        }
    }

    /// 标题对齐；List Content 将 left / right 按语义方向收口为 natural
    @discardableResult
    public func byTitleTextAlignment(_ alignment: NSTextAlignment) -> Self {
        if #available(iOS 14.0, *) {
            return byContentConfiguration { cfg in
                cfg.textProperties.alignment = alignment == .center
                    ? .center
                    : (alignment == .justified ? .justified : .natural)
            }
        } else {
            textLabel?.textAlignment = alignment
            return self
        }
    }

    /// 标题行数
    @discardableResult
    public func byTitleNumberOfLines(_ numberOfLines: Int) -> Self {
        if #available(iOS 14.0, *) {
            return byContentConfiguration { cfg in
                cfg.textProperties.numberOfLines = numberOfLines
            }
        } else {
            textLabel?.numberOfLines = numberOfLines
            return self
        }
    }
    /// 副标题字体
    @discardableResult
    public func byDetailTitleFont(_ font: UIFont) -> Self {
        if #available(iOS 14.0, *) {
            return byContentConfiguration { cfg in
                cfg.secondaryTextProperties.font = font
            }
        } else {
            detailTextLabel?.font = font
            return self
        }
    }

    /// 副标题对齐；List Content 将 left / right 按语义方向收口为 natural
    @discardableResult
    public func byDetailTitleTextAlignment(_ alignment: NSTextAlignment) -> Self {
        if #available(iOS 14.0, *) {
            return byContentConfiguration { cfg in
                cfg.secondaryTextProperties.alignment = alignment == .center
                    ? .center
                    : (alignment == .justified ? .justified : .natural)
            }
        } else {
            detailTextLabel?.textAlignment = alignment
            return self
        }
    }

    /// 副标题行数
    @discardableResult
    public func byDetailTitleNumberOfLines(_ numberOfLines: Int) -> Self {
        if #available(iOS 14.0, *) {
            return byContentConfiguration { cfg in
                cfg.secondaryTextProperties.numberOfLines = numberOfLines
            }
        } else {
            detailTextLabel?.numberOfLines = numberOfLines
            return self
        }
    }
    /// 标题颜色
    @discardableResult
    public func byTitleCor(_ cor: UIColor) -> Self {
#if canImport(JobsSwiftBaseDefines)
        let slot = "UITableViewCell.titleColor"
        if let key = cor.jobsThemeColorKey {
            JobsThemeCenter.shared.bind(self, slot: slot) { object, center in
                guard let cell = object as? UITableViewCell else { return }
                cell.jobsApplyTitleColor(center.resolvedColor(key))
            };return self
        }
        JobsThemeCenter.shared.unbind(self, slot: slot)
#endif
        jobsApplyTitleColor(cor)
        return self
    }
    /// 副标题颜色
    @discardableResult
    public func byDetailTitleCor(_ cor: UIColor) -> Self {
#if canImport(JobsSwiftBaseDefines)
        let slot = "UITableViewCell.detailTitleColor"
        if let key = cor.jobsThemeColorKey {
            JobsThemeCenter.shared.bind(self, slot: slot) { object, center in
                guard let cell = object as? UITableViewCell else { return }
                cell.jobsApplyDetailTitleColor(center.resolvedColor(key))
            };return self
        }
        JobsThemeCenter.shared.unbind(self, slot: slot)
#endif
        jobsApplyDetailTitleColor(cor)
        return self
    }
}
