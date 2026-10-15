//
//  UISearchBar.swift
//  JobsByUIKit
//
//  Created by Jobs on 2026年5月13日，星期三.
//

#if os(OSX)
import AppKit
#elseif os(iOS) || os(tvOS)
import UIKit
#endif

extension UISearchBar {
    @discardableResult
    public func byDelegate(_ delegate: UISearchBarDelegate?) -> Self {
        self.delegate = delegate
        return self
    }

    @discardableResult
    public func byText(_ text: String?) -> Self {
        self.text = text
        return self
    }

    @discardableResult
    public func byPrompt(_ text: String?) -> Self {
        self.prompt = text
        return self
    }

    @discardableResult
    public func byPlaceholder(_ text: String?) -> Self {
        self.placeholder = text
        return self
    }

    @discardableResult
    public func byBarStyle(_ style: UIBarStyle) -> Self {
        self.barStyle = style
        return self
    }

    @discardableResult
    public func bySearchBarStyle(_ style: UISearchBar.Style) -> Self {
        self.searchBarStyle = style
        return self
    }

    @discardableResult
    public func byTranslucent(_ on: Bool) -> Self {
        self.isTranslucent = on
        return self
    }

    @discardableResult
    public func byBarTintColor(_ color: UIColor?) -> Self {
        self.barTintColor = color
        return self
    }

    @discardableResult
    public func byShowsCancelButton(_ show: Bool) -> Self {
        self.showsCancelButton = show
        return self
    }

    @discardableResult
    public func byShowsBookmarkButton(_ show: Bool) -> Self {
        self.showsBookmarkButton = show
        return self
    }

    @discardableResult
    public func byShowsSearchResultsButton(_ show: Bool) -> Self {
        self.showsSearchResultsButton = show
        return self
    }

    @discardableResult
    public func bySearchResultsButtonSelected(_ selected: Bool) -> Self {
        self.isSearchResultsButtonSelected = selected
        return self
    }

    @discardableResult
    public func byScopeButtonTitles(_ titles: [String]?) -> Self {
        self.scopeButtonTitles = titles
        return self
    }

    @discardableResult
    public func bySelectedScopeButtonIndex(_ index: Int) -> Self {
        self.selectedScopeButtonIndex = index
        return self
    }

    @discardableResult
    public func byShowsScopeBar(_ show: Bool) -> Self {
        self.showsScopeBar = show
        return self
    }

    @discardableResult
    public func byInputAccessoryView(_ view: UIView?) -> Self {
        self.inputAccessoryView = view
        return self
    }

    @available(iOS 16.4, tvOS 16.4, *)
    @discardableResult
    public func byEnabled(_ on: Bool) -> Self {
        self.isEnabled = on
        return self
    }

    @discardableResult
    public func byBackgroundImage(_ image: UIImage?) -> Self {
        self.backgroundImage = image
        return self
    }

    @discardableResult
    public func byScopeBarBackgroundImage(_ image: UIImage?) -> Self {
        self.scopeBarBackgroundImage = image
        return self
    }

    @discardableResult
    public func bySearchFieldBackgroundPositionAdjustment(_ offset: UIOffset) -> Self {
        self.searchFieldBackgroundPositionAdjustment = offset
        return self
    }

    @discardableResult
    public func bySearchTextPositionAdjustment(_ offset: UIOffset) -> Self {
        self.searchTextPositionAdjustment = offset
        return self
    }

    @available(iOS 17.0, visionOS 1.0, *)
    @discardableResult
    public func byLookToDictateEnabled(_ on: Bool) -> Self {
        self.isLookToDictateEnabled = on
        return self
    }
}
