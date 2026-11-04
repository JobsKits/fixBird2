//
//  UIWindowScene.swift
//  JobsGetWindow
//
//  Created by Jobs on 2026年5月13日，星期三.
//

#if os(OSX)
import AppKit
#elseif os(iOS) || os(tvOS)
import UIKit
#endif

@available(iOS 13.0, *)
public extension UIWindowScene {
    var keyWindowCompat: UIWindow? {
        if #available(iOS 15.0, *) {
            return self.keyWindow
        } else {
            return self.windows.first(where: { $0.isKeyWindow })
        }
    }
}

@available(*, deprecated, message: "Use UIWindowScene.keyWindowCompat instead.")
public func legacyKeyWindowPreiOS13() -> UIWindow? {
    if #available(iOS 13.0, *) {
        return UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }?
            .keyWindowCompat
    } else {
        return UIApplication.shared.keyWindow ?? UIApplication.shared.windows.first
    }
}
