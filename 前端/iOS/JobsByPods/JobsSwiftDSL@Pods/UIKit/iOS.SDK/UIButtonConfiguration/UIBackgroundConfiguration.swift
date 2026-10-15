//
//  UIBackgroundConfiguration.swift
//  JobsByUIKit
//
//  Created by Jobs on 2026年5月13日，星期三.
//

#if os(OSX)
import AppKit
#elseif os(iOS) || os(tvOS)
import UIKit
#endif

@available(iOS 14.0, *)
public extension UIBackgroundConfiguration {
    // MARK: - Convenience factories
    @discardableResult
    @inlinable
    static func byClear() -> Self {
        .clear()
    }

    @available(iOS 18.0, tvOS 18.0, visionOS 2.0, *)
    @discardableResult
    @inlinable
    static func byListCell() -> Self {
        .listCell()
    }

    @available(iOS 18.0, tvOS 18.0, visionOS 2.0, *)
    @discardableResult
    @inlinable
    static func byListHeader() -> Self {
        .listHeader()
    }

    @available(iOS 18.0, tvOS 18.0, visionOS 2.0, *)
    @discardableResult
    @inlinable
    static func byListFooter() -> Self {
        .listFooter()
    }

    @discardableResult
    @inlinable
    static func byListAccompaniedSidebarCell() -> Self {
        .listAccompaniedSidebarCell()
    }
    // MARK: - Update helper
    @discardableResult
    @inlinable
    func byUpdated(for state: any UIConfigurationState) -> Self {
        self.updated(for: state)
    }
    // MARK: - Custom view
    @discardableResult
    @inlinable
    func byCustomView(_ view: UIView?) -> Self {
        var c = self
        c.customView = view
        return c
    }
    // MARK: - Corners / Insets / Edges
    @discardableResult
    @inlinable
    func byCornerRadius(_ r: CGFloat) -> Self {
        var c = self
        c.cornerRadius = r
        return c
    }

    @discardableResult
    @inlinable
    func byBackgroundInsets(_ insets: NSDirectionalEdgeInsets) -> Self {
        var c = self
        c.backgroundInsets = insets
        return c
    }

    @discardableResult
    @inlinable
    func byEdgesAddingLayoutMarginsToBackgroundInsets(_ edges: NSDirectionalRectEdge) -> Self {
        var c = self
        c.edgesAddingLayoutMarginsToBackgroundInsets = edges
        return c
    }
    // MARK: - Background color
    @discardableResult
    @inlinable
    func byBackgroundColor(_ color: UIColor?) -> Self {
        var c = self
        c.backgroundColor = color
        return c
    }

    @discardableResult
    @inlinable
    func byBackgroundColorTransformer(_ transformer: UIConfigurationColorTransformer?) -> Self {
        var c = self
        c.backgroundColorTransformer = transformer
        return c
    }
    // MARK: - Visual effect
    @discardableResult
    @inlinable
    func byVisualEffect(_ effect: UIVisualEffect?) -> Self {
        var c = self
        c.visualEffect = effect
        return c
    }
    // MARK: - Image (iOS 15+)
    @available(iOS 15.0, tvOS 15.0, *)
    @discardableResult
    @inlinable
    func byImage(_ image: UIImage?) -> Self {
        var c = self
        c.image = image
        return c
    }

    @available(iOS 15.0, tvOS 15.0, *)
    @discardableResult
    @inlinable
    func byImageContentMode(_ mode: UIView.ContentMode) -> Self {
        var c = self
        c.imageContentMode = mode
        return c
    }
    // MARK: - Stroke
    @discardableResult
    @inlinable
    func byStrokeColor(_ color: UIColor?) -> Self {
        var c = self
        c.strokeColor = color
        return c
    }

    @discardableResult
    @inlinable
    func byStrokeColorTransformer(_ transformer: UIConfigurationColorTransformer?) -> Self {
        var c = self
        c.strokeColorTransformer = transformer
        return c
    }

    @discardableResult
    @inlinable
    func byStrokeWidth(_ w: CGFloat) -> Self {
        var c = self
        c.strokeWidth = w
        return c
    }

    @discardableResult
    @inlinable
    func byStrokeOutset(_ o: CGFloat) -> Self {
        var c = self
        c.strokeOutset = o
        return c
    }
    // MARK: - Shadow (iOS 18+)
    @available(iOS 18.0, tvOS 18.0, visionOS 2.0, *)
    @discardableResult
    @inlinable
    func byShadowProperties(_ props: UIShadowProperties) -> Self {
        var c = self
        c.shadowProperties = props
        return c
    }
    // MARK: - Generic utilities (optional)
    @discardableResult
    @inlinable
    func by<T>(_ keyPath: WritableKeyPath<Self, T>, _ value: T) -> Self {
        var c = self
        c[keyPath: keyPath] = value
        return c
    }

    @discardableResult
    @inlinable
    func by(_ patch: (inout Self) -> Void) -> Self {
        var c = self
        patch(&c)
        return c
    }
}
