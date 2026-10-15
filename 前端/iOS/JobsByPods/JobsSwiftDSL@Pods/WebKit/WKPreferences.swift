//
//  WKPreferences.swift
//  JobsByWebKit
//
//  Created by Jobs on 2026年5月13日，星期三.
//

#if os(OSX)
import AppKit
#elseif os(iOS) || os(tvOS)
import UIKit
#endif

import WebKit

extension WKPreferences {
    // ================================== minimumFontSize ==================================
    @discardableResult
    public func byMinimumFontSize(_ value: CGFloat) -> Self {
        self.minimumFontSize = value
        return self
    }
    // ================================== javaScriptCanOpenWindowsAutomatically ==================================
    @discardableResult
    public func byJavaScriptCanOpenWindowsAutomatically(_ value: Bool) -> Self {
        self.javaScriptCanOpenWindowsAutomatically = value
        return self
    }
    // ================================== isFraudulentWebsiteWarningEnabled (iOS 13+) ==================================
    @available(iOS 13.0, *)
    @discardableResult
    public func byIsFraudulentWebsiteWarningEnabled(_ value: Bool) -> Self {
        self.isFraudulentWebsiteWarningEnabled = value
        return self
    }
    // ================================== shouldPrintBackgrounds (iOS 16.4+) ==================================
    @available(iOS 16.4, *)
    @discardableResult
    public func byShouldPrintBackgrounds(_ value: Bool) -> Self {
        self.shouldPrintBackgrounds = value
        return self
    }
    // ================================== isTextInteractionEnabled (iOS 14.5+) ==================================
    @available(iOS 14.5, *)
    @discardableResult
    public func byIsTextInteractionEnabled(_ value: Bool) -> Self {
        self.isTextInteractionEnabled = value
        return self
    }
    // ================================== isSiteSpecificQuirksModeEnabled (iOS 15.4+) ==================================
    @available(iOS 15.4, *)
    @discardableResult
    public func byIsSiteSpecificQuirksModeEnabled(_ value: Bool) -> Self {
        self.isSiteSpecificQuirksModeEnabled = value
        return self
    }
    // ================================== isElementFullscreenEnabled (iOS 15.4+) ==================================
    @available(iOS 15.4, *)
    @discardableResult
    public func byIsElementFullscreenEnabled(_ value: Bool) -> Self {
        self.isElementFullscreenEnabled = value
        return self
    }
    // ================================== inactiveSchedulingPolicy (iOS 17+) ==================================
    @available(iOS 17.0, *)
    @discardableResult
    public func byInactiveSchedulingPolicy(_ value: WKPreferences.InactiveSchedulingPolicy) -> Self {
        self.inactiveSchedulingPolicy = value
        return self
    }
}
