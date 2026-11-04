//
//  UIButtonConfiguration.swift
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

@available(iOS 15.0, tvOS 15.0, *)
public extension UIButton.Configuration {
    // MARK: - Convenience style factories (static styles)
    @discardableResult
    @inlinable
    func byPlain() -> Self {
        .plain()
    }

    @discardableResult
    @inlinable
    func byTinted() -> Self {
        .tinted()
    }

    @discardableResult
    @inlinable
    func byGray() -> Self {
        .gray()
    }

    @discardableResult
    @inlinable
    func byFilled() -> Self {
        .filled()
    }

    @discardableResult
    @inlinable
    func byBorderless() -> Self {
        .borderless()
    }

    @discardableResult
    @inlinable
    func byBordered() -> Self {
        .bordered()
    }

    @discardableResult
    @inlinable
    func byBorderedTinted() -> Self {
        .borderedTinted()
    }

    @discardableResult
    @inlinable
    func byBorderedProminent() -> Self {
        .borderedProminent()
    }
    // MARK: - Update helper
    /// Equivalent to calling `updated(for:)` then chaining more.
    @discardableResult
    @inlinable
    func byUpdated(for button: UIButton) -> Self {
        self.updated(for: button)
    }
    // MARK: - Background
    @discardableResult
    @inlinable
    func byBackground(_ background: UIBackgroundConfiguration) -> Self {
        var c = self
        c.background = background
        return c
    }
    // MARK: - Corner / Size / Mac idiom
    @discardableResult
    @inlinable
    func byCornerStyle(_ style: UIButton.Configuration.CornerStyle) -> Self {
        var c = self
        c.cornerStyle = style
        return c
    }

    @discardableResult
    @inlinable
    func byButtonSize(_ size: UIButton.Configuration.Size) -> Self {
        var c = self
        c.buttonSize = size
        return c
    }

    @discardableResult
    @inlinable
    func byMacIdiomStyle(_ style: UIButton.Configuration.MacIdiomStyle) -> Self {
        var c = self
        c.macIdiomStyle = style
        return c
    }
    // MARK: - Base colors
    /// 把 background 拿出来改，改完写回去（copy-in/copy-out）
    @discardableResult
    @inlinable
    func byBackgroundPatch(_ patch: (inout UIBackgroundConfiguration) -> Void) -> Self {
        var c = self
        var bg = c.background
        patch(&bg)
        c.background = bg
        return c
    }

    @discardableResult
    @inlinable
    func byBaseForegroundColor(_ color: UIColor?) -> Self {
        var c = self
        c.baseForegroundColor = color
        return c
    }

    @discardableResult
    @inlinable
    func byBaseBackgroundColor(_ color: UIColor?) -> Self {
        var c = self
        c.baseBackgroundColor = color
        return c
    }
    // ---- Optional: keep your old misspelled APIs as aliases (won't break existing call sites)
    @discardableResult
    @inlinable
    func byBaseForegroundCor(_ color: UIColor?) -> Self {
        byBaseForegroundColor(color)
    }

    @discardableResult
    @inlinable
    func byBaseBackgroundCor(_ color: UIColor?) -> Self {
        byBaseBackgroundColor(color)
    }
    // MARK: - Image
    @discardableResult
    @inlinable
    func byImage(_ image: UIImage?) -> Self {
        var c = self
        c.image = image
        return c
    }

    @discardableResult
    @inlinable
    func byImageColorTransformer(_ transformer: UIConfigurationColorTransformer?) -> Self {
        var c = self
        c.imageColorTransformer = transformer
        return c
    }

    @discardableResult
    @inlinable
    func byPreferredSymbolConfigurationForImage(_ cfg: UIImage.SymbolConfiguration?) -> Self {
        var c = self
        c.preferredSymbolConfigurationForImage = cfg
        return c
    }
    // ---- Alias you used before
    @discardableResult
    @inlinable
    func byPreferredSymbolConfig(_ cfg: UIImage.SymbolConfiguration?) -> Self {
        byPreferredSymbolConfigurationForImage(cfg)
    }
    /// 注意：类型是 NSDirectionalRectEdge
    @discardableResult
    @inlinable
    func byImagePlacement(_ placement: NSDirectionalRectEdge) -> Self {
        var c = self
        c.imagePlacement = placement
        return c
    }

    @discardableResult
    @inlinable
    func byImagePadding(_ padding: CGFloat) -> Self {
        var c = self
        c.imagePadding = padding
        return c
    }
    // MARK: - Activity indicator
    @discardableResult
    @inlinable
    func byShowsActivityIndicator(_ show: Bool) -> Self {
        var c = self
        c.showsActivityIndicator = show
        return c
    }
    // ---- Alias you used before
    @discardableResult
    @inlinable
    func byShowsActivity(_ show: Bool) -> Self {
        byShowsActivityIndicator(show)
    }

    @discardableResult
    @inlinable
    func byActivityIndicatorColorTransformer(_ transformer: UIConfigurationColorTransformer?) -> Self {
        var c = self
        c.activityIndicatorColorTransformer = transformer
        return c
    }
    // MARK: - Title / Subtitle (plain & attributed)
    @discardableResult
    @inlinable
    func byTitle(_ title: String?) -> Self {
        var c = self
        c.title = title
        return c
    }

    @discardableResult
    @inlinable
    func byAttributedTitle(_ title: AttributedString?) -> Self {
        var c = self
        c.attributedTitle = title
        return c
    }

    @discardableResult
    @inlinable
    func byTitleTextAttributesTransformer(_ transformer: UIConfigurationTextAttributesTransformer?) -> Self {
        var c = self
        c.titleTextAttributesTransformer = transformer
        return c
    }
    /// 便捷：直接传闭包，少写一层 UIConfigurationTextAttributesTransformer(...)
    @discardableResult
    @inlinable
    func byTitleTextAttributesTransformer(
        _ block: @escaping (AttributeContainer) -> AttributeContainer
    ) -> Self {
        byTitleTextAttributesTransformer(UIConfigurationTextAttributesTransformer(block))
    }

    @discardableResult
    @inlinable
    func bySubtitle(_ subtitle: String?) -> Self {
        var c = self
        c.subtitle = subtitle
        return c
    }

    @discardableResult
    @inlinable
    func byAttributedSubtitle(_ subtitle: AttributedString?) -> Self {
        var c = self
        c.attributedSubtitle = subtitle
        return c
    }
    /// subtitleTextAttributesTransformer：直接传 transformer
    @discardableResult
    @inlinable
    func bySubtitleTextAttributesTransformer(_ transformer: UIConfigurationTextAttributesTransformer?) -> Self {
        var c = self
        c.subtitleTextAttributesTransformer = transformer
        return c
    }
    /// 便捷：直接传闭包（AttributeContainer -> AttributeContainer）
    @discardableResult
    @inlinable
    func bySubtitleTextAttributesTransformer(
        _ block: @escaping (AttributeContainer) -> AttributeContainer
    ) -> Self {
        bySubtitleTextAttributesTransformer(UIConfigurationTextAttributesTransformer(block))
    }
    // MARK: - Title layout
    @discardableResult
    @inlinable
    func byTitlePadding(_ padding: CGFloat) -> Self {
        var c = self
        c.titlePadding = padding
        return c
    }

    @discardableResult
    @inlinable
    func byTitleAlignment(_ alignment: UIButton.Configuration.TitleAlignment) -> Self {
        var c = self
        c.titleAlignment = alignment
        return c
    }
    // MARK: - Content layout
    @discardableResult
    @inlinable
    func byContentInsets(_ insets: NSDirectionalEdgeInsets) -> Self {
        var c = self
        c.contentInsets = insets
        return c
    }

    @discardableResult
    @inlinable
    func bySetDefaultContentInsets() -> Self {
        var c = self
        c.setDefaultContentInsets()
        return c
    }
    // MARK: - Behavior
    @discardableResult
    @inlinable
    func byAutomaticallyUpdateForSelection(_ enabled: Bool) -> Self {
        var c = self
        c.automaticallyUpdateForSelection = enabled
        return c
    }
    // ---- Alias you used before
    @discardableResult
    @inlinable
    func byAutoUpdateForSelection(_ enabled: Bool) -> Self {
        byAutomaticallyUpdateForSelection(enabled)
    }
    // MARK: - iOS 16+ Indicator
    @available(iOS 16.0, tvOS 16.0, *)
    @discardableResult
    @inlinable
    func byIndicator(_ indicator: UIButton.Configuration.Indicator) -> Self {
        var c = self
        c.indicator = indicator
        return c
    }

    @available(iOS 16.0, tvOS 16.0, *)
    @discardableResult
    @inlinable
    func byIndicatorColorTransformer(_ transformer: UIConfigurationColorTransformer?) -> Self {
        var c = self
        c.indicatorColorTransformer = transformer
        return c
    }
    // MARK: - iOS 26+ Symbol content transition
    @available(iOS 26.0, tvOS 26.0, *)
    @available(watchOS, unavailable)
    @discardableResult
    @inlinable
    func bySymbolContentTransition(_ t: UISymbolContentTransition?) -> Self {
        var c = self
        c.symbolContentTransition = t
        return c
    }
    // MARK: - Generic utilities (optional but useful)
    /// Generic keyPath setter, helps you avoid writing wrappers for your own custom fields.
    @discardableResult
    @inlinable
    func by<T>(_ keyPath: WritableKeyPath<Self, T>, _ value: T) -> Self {
        var c = self
        c[keyPath: keyPath] = value
        return c
    }
    /// Patch multiple fields at once.
    @discardableResult
    @inlinable
    func by(_ patch: (inout Self) -> Void) -> Self {
        var c = self
        patch(&c)
        return c
    }
    /// 强制切到 `.plain()`，并尽量保留旧配置里的内容/布局/行为等字段（用 DSL 全量搬运）
    @discardableResult
    @inlinable
    func byForcePlainKeepingContent() -> Self {
        let old = self
        var c : UIButton.Configuration = .plain()
            // MARK: - Background / base colors
            .byBackground(old.background)
            .byBaseForegroundColor(old.baseForegroundColor)
            .byBaseBackgroundColor(old.baseBackgroundColor)
            // MARK: - Corner / Size / Mac idiom
            .byCornerStyle(old.cornerStyle)
            .byButtonSize(old.buttonSize)
            .byMacIdiomStyle(old.macIdiomStyle)
            // MARK: - Title / Subtitle
            .byTitle(old.title)
            .byAttributedTitle(old.attributedTitle)
            .byTitleTextAttributesTransformer(old.titleTextAttributesTransformer)
            .bySubtitle(old.subtitle)
            .byAttributedSubtitle(old.attributedSubtitle)
            .bySubtitleTextAttributesTransformer(old.subtitleTextAttributesTransformer)
            // MARK: - Image
            .byImage(old.image)
            .byImageColorTransformer(old.imageColorTransformer)
            .byPreferredSymbolConfigurationForImage(old.preferredSymbolConfigurationForImage)
            .byImagePlacement(old.imagePlacement)
            .byImagePadding(old.imagePadding)
            // MARK: - Layout
            .byContentInsets(old.contentInsets)
            .byTitlePadding(old.titlePadding)
            .byTitleAlignment(old.titleAlignment)
            // MARK: - Activity indicator
            .byShowsActivityIndicator(old.showsActivityIndicator)
            .byActivityIndicatorColorTransformer(old.activityIndicatorColorTransformer)
            // MARK: - Behavior
            .byAutomaticallyUpdateForSelection(old.automaticallyUpdateForSelection)
        // MARK: - iOS 16+ Indicator
        if #available(iOS 16.0, tvOS 16.0, *) {
            c = c
                .byIndicator(old.indicator)
                .byIndicatorColorTransformer(old.indicatorColorTransformer)
        }
        // MARK: - iOS 26+ Symbol content transition
        if #available(iOS 26.0, tvOS 26.0, *) {
            c = c.bySymbolContentTransition(old.symbolContentTransition)
        };return c
    }
}
