//
//  UIToolbarAppearance.swift
//  JobsByUIKit
//
//  Created by Jobs on 2026年5月13日，星期三.
//

#if os(OSX)
import AppKit
#elseif os(iOS) || os(tvOS)
import UIKit
#endif

import JobsSwiftBlock

@available(iOS 13.0, *)
extension UIToolbarAppearance {
    // MARK: - Configure presets
    @discardableResult
    public func byConfigureWithDefaultBackground() -> Self {
        self.configureWithDefaultBackground()
        return self
    }

    @discardableResult
    public func byConfigureWithOpaqueBackground() -> Self {
        self.configureWithOpaqueBackground()
        return self
    }

    @discardableResult
    public func byConfigureWithTransparentBackground() -> Self {
        self.configureWithTransparentBackground()
        return self
    }
    // MARK: - Button appearances
    @discardableResult
    public func byButtonAppearance(_ config: jobsByBarButtonItemAppearanceBlock) -> Self {
        config(self.buttonAppearance)
        return self
    }

    @discardableResult
    public func byDoneButtonAppearance(_ config: jobsByBarButtonItemAppearanceBlock) -> Self {
        config(self.doneButtonAppearance)
        return self
    }
}
