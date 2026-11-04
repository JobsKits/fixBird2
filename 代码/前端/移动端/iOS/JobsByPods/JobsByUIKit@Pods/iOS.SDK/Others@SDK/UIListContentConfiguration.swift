//
//  UIListContentConfiguration.swift
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
import JobsSwiftBlock
import JobsSwiftDSL

// ================================== 示例 ==================================
// cell.byListConfig {
//     $0.byText("主标题")
//       .bySecondaryText("副标题")
//       .byImage(systemName: "tray")
//       .byPreferredSymbol(pointSize: 18, weight: .semibold)
//       .byTintColor(JobsCor.systemBlue)
//       .byImageCornerRadius(6)
//       .byImageMaximumSize(CGSize(width: 28, height: 28))
//       .byTextFont(JobsFont.preferredFont(forTextStyle: .body))
//       .byTextColor(.label)
//       .bySecondaryFont(JobsFont.preferredFont(forTextStyle: .subheadline))
//       .bySecondaryColor(.secondaryLabel)
//       .byTextLines(1)
//       .bySecondaryLines(1)
//       .byPrefersSideBySideTextAndSecondaryText(true)
//       .byImageToTextPadding(8)
//       .byPrimarySecondaryHorizontalPadding(8)
//       .byDirectionalLayoutMargins(.init(top: 8, leading: 16, bottom: 8, trailing: 16))
// }
// ================================== 基础扩展 · 总体 ==================================
@available(iOS 14.0, tvOS 14.0, *)
@available(watchOS, unavailable)
extension UIListContentConfiguration {
    // MARK: - 小工具
    private func jobs_mutating(_ body: jobsByInoutListContentConfigBlock) -> UIListContentConfiguration {
        var copy = self
        body(&copy)
        return copy
    }
    // ================================== 便捷构造 ==================================
    /// `.cell()` / `.subtitleCell()` / `.valueCell()` 等系统模板的语义化便捷入口
    public static func jobsCell(text: String? = nil,
                                secondary: String? = nil,
                                image: UIImage? = nil) -> UIListContentConfiguration {
        var c = UIListContentConfiguration.cell()
        c.text = text
        c.secondaryText = secondary
        c.image = image
        return c
    }

    public static func jobsSubtitleCell(text: String? = nil,
                                        secondary: String? = nil,
                                        image: UIImage? = nil) -> UIListContentConfiguration {
        var c = UIListContentConfiguration.subtitleCell()
        c.text = text
        c.secondaryText = secondary
        c.image = image
        return c
    }

    public static func jobsValueCell(text: String? = nil,
                                     secondary: String? = nil,
                                     image: UIImage? = nil) -> UIListContentConfiguration {
        var c = UIListContentConfiguration.valueCell()
        c.text = text
        c.secondaryText = secondary
        c.image = image
        return c
    }

    @available(iOS 18.0, tvOS 18.0, *)
    public static func jobsHeader(text: String? = nil,
                                  secondary: String? = nil) -> UIListContentConfiguration {
        var c = UIListContentConfiguration.header()
        c.text = text
        c.secondaryText = secondary
        return c
    }

    @available(iOS 18.0, tvOS 18.0, *)
    public static func jobsFooter(text: String? = nil,
                                  secondary: String? = nil) -> UIListContentConfiguration {
        var c = UIListContentConfiguration.footer()
        c.text = text
        c.secondaryText = secondary
        return c
    }

    // ================================== 核心字段 ==================================
    @discardableResult
    public func byText(_ value: String?) -> Self {
        jobs_mutating { $0.text = value }
    }

    @discardableResult
    public func byAttributedText(_ value: NSAttributedString?) -> Self {
        jobs_mutating { $0.attributedText = value }
    }

    @discardableResult
    public func bySecondaryText(_ value: String?) -> Self {
        jobs_mutating { $0.secondaryText = value }
    }

    @discardableResult
    public func bySecondaryAttributedText(_ value: NSAttributedString?) -> Self {
        jobs_mutating { $0.secondaryAttributedText = value }
    }

    @discardableResult
    public func byImage(_ value: UIImage?) -> Self {
        jobs_mutating { $0.image = value }
    }
    /// 便捷：直接使用 SF Symbol 名称
    @discardableResult
    public func byImage(systemName: String) -> Self {
        jobs_mutating { $0.image = UIImage(systemName: systemName) }
    }
    // ================================== 布局/边距/排布 ==================================
    @discardableResult
    public func byAxesPreservingSuperviewLayoutMargins(_ axes: UIAxis) -> Self {
        jobs_mutating { $0.axesPreservingSuperviewLayoutMargins = axes }
    }

    @discardableResult
    public func byDirectionalLayoutMargins(_ edges: NSDirectionalEdgeInsets) -> Self {
        jobs_mutating { $0.directionalLayoutMargins = edges }
    }
    /// 便捷：用 `UIEdgeInsets` 适配成 Directional
    @discardableResult
    public func byLayoutMargins(_ edges: UIEdgeInsets) -> Self {
        jobs_mutating {
            $0.directionalLayoutMargins = .init(top: edges.top,
                                                leading: edges.left,
                                                bottom: edges.bottom,
                                                trailing: edges.right)
        }
    }

    @discardableResult
    public func byPrefersSideBySideTextAndSecondaryText(_ flag: Bool) -> Self {
        jobs_mutating { $0.prefersSideBySideTextAndSecondaryText = flag }
    }

    @discardableResult
    public func byImageToTextPadding(_ v: CGFloat) -> Self {
        jobs_mutating { $0.imageToTextPadding = v }
    }

    @discardableResult
    public func byPrimarySecondaryHorizontalPadding(_ v: CGFloat) -> Self {
        jobs_mutating { $0.textToSecondaryTextHorizontalPadding = v }
    }

    @discardableResult
    public func byPrimarySecondaryVerticalPadding(_ v: CGFloat) -> Self {
        jobs_mutating { $0.textToSecondaryTextVerticalPadding = v }
    }

    @available(iOS 18.0, tvOS 18.0, *)
    @discardableResult
    public func byAlpha(_ value: CGFloat) -> Self {
        jobs_mutating { $0.alpha = value }
    }
    // ================================== 文本属性 · 主文案 ==================================
    @discardableResult
    public func byTextFont(_ font: UIFont) -> Self {
        jobs_mutating { $0.textProperties.font = font }
    }

    @discardableResult
    public func byTextColor(_ color: UIColor) -> Self {
        jobs_mutating { $0.textProperties.color = color }
    }

    @discardableResult
    public func byTextColorTransformer(_ transformer: UIConfigurationColorTransformer?) -> Self {
        jobs_mutating { $0.textProperties.colorTransformer = transformer }
    }

    @discardableResult
    public func byTextAlignment(_ alignment: UIListContentConfiguration.TextProperties.TextAlignment) -> Self {
        jobs_mutating { $0.textProperties.alignment = alignment }
    }

    @discardableResult
    public func byTextLineBreakMode(_ mode: NSLineBreakMode) -> Self {
        jobs_mutating { $0.textProperties.lineBreakMode = mode }
    }

    @discardableResult
    public func byTextLines(_ numberOfLines: Int) -> Self {
        jobs_mutating { $0.textProperties.numberOfLines = numberOfLines }
    }

    @discardableResult
    public func byTextAdjustsFontSizeToFitWidth(_ flag: Bool, minimumScaleFactor: CGFloat? = nil) -> Self {
        jobs_mutating {
            $0.textProperties.adjustsFontSizeToFitWidth = flag
            if let f = minimumScaleFactor { $0.textProperties.minimumScaleFactor = f }
        }
    }

    @discardableResult
    public func byTextAllowsDefaultTightening(_ flag: Bool) -> Self {
        jobs_mutating { $0.textProperties.allowsDefaultTighteningForTruncation = flag }
    }

    @discardableResult
    public func byTextAdjustsForContentSizeCategory(_ flag: Bool) -> Self {
        jobs_mutating { $0.textProperties.adjustsFontForContentSizeCategory = flag }
    }

    @discardableResult
    public func byTextTransform(_ transform: UIListContentConfiguration.TextProperties.TextTransform) -> Self {
        jobs_mutating { $0.textProperties.transform = transform }
    }

    #if targetEnvironment(macCatalyst)
    @available(macCatalyst 16.0, *)
    @discardableResult
    public func byTextShowsExpansionWhenTruncated(_ flag: Bool) -> Self {
        jobs_mutating { $0.textProperties.showsExpansionTextWhenTruncated = flag }
    }
    #endif

    // ================================== 文本属性 · 副文案 ==================================
    @discardableResult
    public func bySecondaryFont(_ font: UIFont) -> Self {
        jobs_mutating { $0.secondaryTextProperties.font = font }
    }

    @discardableResult
    public func bySecondaryColor(_ color: UIColor) -> Self {
        jobs_mutating { $0.secondaryTextProperties.color = color }
    }

    @discardableResult
    public func bySecondaryColorTransformer(_ transformer: UIConfigurationColorTransformer?) -> Self {
        jobs_mutating { $0.secondaryTextProperties.colorTransformer = transformer }
    }

    @discardableResult
    public func bySecondaryAlignment(_ alignment: UIListContentConfiguration.TextProperties.TextAlignment) -> Self {
        jobs_mutating { $0.secondaryTextProperties.alignment = alignment }
    }

    @discardableResult
    public func bySecondaryLines(_ numberOfLines: Int) -> Self {
        jobs_mutating { $0.secondaryTextProperties.numberOfLines = numberOfLines }
    }

    @discardableResult
    public func bySecondaryLineBreakMode(_ mode: NSLineBreakMode) -> Self {
        jobs_mutating { $0.secondaryTextProperties.lineBreakMode = mode }
    }

    @discardableResult
    public func bySecondaryTransform(_ transform: UIListContentConfiguration.TextProperties.TextTransform) -> Self {
        jobs_mutating { $0.secondaryTextProperties.transform = transform }
    }
    // ================================== 图片属性 ==================================
    @discardableResult
    public func byPreferredSymbolConfiguration(_ cfg: UIImage.SymbolConfiguration?) -> Self {
        jobs_mutating { $0.imageProperties.preferredSymbolConfiguration = cfg }
    }
    /// 便捷：直接传入 pointSize / weight / scale 生成 `preferredSymbolConfiguration`
    @discardableResult
    public func byPreferredSymbol(pointSize: CGFloat? = nil,
                           weight: UIImage.SymbolWeight? = nil,
                           scale: UIImage.SymbolScale? = nil) -> Self {
        let pieces: [UIImage.SymbolConfiguration] = [
            pointSize.map { .init(pointSize: $0) },
            weight.map    { .init(weight: $0)    },
            scale.map     { .init(scale: $0)     }
        ].compactMap { $0 }
        let merged = pieces.reduce(nil as UIImage.SymbolConfiguration?) { acc, cfg in
            acc?.applying(cfg) ?? cfg
        };return byPreferredSymbolConfiguration(merged)
    }

    @discardableResult
    public func byTintColor(_ color: UIColor?) -> Self {
        jobs_mutating { $0.imageProperties.tintColor = color }
    }

    @discardableResult
    public func byTintColorTransformer(_ transformer: UIConfigurationColorTransformer?) -> Self {
        jobs_mutating { $0.imageProperties.tintColorTransformer = transformer }
    }

    @discardableResult
    public func byImageCornerRadius(_ radius: CGFloat) -> Self {
        jobs_mutating { $0.imageProperties.cornerRadius = radius }
    }

    @discardableResult
    public func byImageMaximumSize(_ size: CGSize) -> Self {
        jobs_mutating { $0.imageProperties.maximumSize = size }
    }
    /// 为图片预留布局尺寸（即使无图也占位）
    @discardableResult
    public func byImageReservedLayoutSize(_ size: CGSize) -> Self {
        jobs_mutating { $0.imageProperties.reservedLayoutSize = size }
    }

    @discardableResult
    public func byImageIgnoresInvertColors(_ flag: Bool) -> Self {
        jobs_mutating { $0.imageProperties.accessibilityIgnoresInvertColors = flag }
    }

    @available(iOS 18.0, tvOS 18.0, *)
    @discardableResult
    public func byImageStrokeColor(_ color: UIColor?) -> Self {
        jobs_mutating { $0.imageProperties.strokeColor = color }
    }

    @available(iOS 18.0, tvOS 18.0, *)
    @discardableResult
    public func byImageStrokeColorTransformer(_ transformer: UIConfigurationColorTransformer?) -> Self {
        jobs_mutating { $0.imageProperties.strokeColorTransformer = transformer }
    }

    @available(iOS 18.0, tvOS 18.0, *)
    @discardableResult
    public func byImageStrokeWidth(_ width: CGFloat) -> Self {
        jobs_mutating { $0.imageProperties.strokeWidth = width }
    }
    // ================================== 状态更新 / ContentView ==================================
    /// 对任意 `UIConfigurationState` 做增量更新（一般配合 `UICellConfigurationState` 使用）
    @discardableResult
    public func jobsUpdated(for state: UIConfigurationState) -> UIListContentConfiguration {
        self.updated(for: state)
    }

    /// 直接生成 `UIListContentView`
    @MainActor
    public func makeJobsContentView() -> (UIView & UIContentView) {
        self.makeContentView()
    }
}
