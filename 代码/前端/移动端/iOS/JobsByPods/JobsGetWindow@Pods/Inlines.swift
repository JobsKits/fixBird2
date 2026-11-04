//
//  Inlines.swift
//  JobsGetWindow
//
//  Created by Jobs on 2026年5月13日，星期三.
//

#if os(OSX)
import AppKit
#elseif os(iOS) || os(tvOS)
import UIKit
#endif

import ObjectiveC

// MARK: - 获取 MainWindow
@inline(__always)
public func jobsGetMainWindow() -> UIWindow? {
    if #available(iOS 13.0, *) {
        return jobsGetMainWindowAfter13() ?? jobsGetMainWindowBefore13()
    }
    return jobsGetMainWindowBefore13()
}

@inline(__always)
public func jobsGetMainWindowBefore13() -> UIWindow? {
    if let window = UIApplication.shared.delegate?.window ?? nil {
        return window
    }
    if #available(iOS 13.0, *) {
        return nil
    }
    return UIApplication.shared.perform(#selector(getter: UIApplication.keyWindow))?
        .takeUnretainedValue() as? UIWindow
}

@inline(__always)
public func jobsGetMainWindowAfter13() -> UIWindow? {
    if #available(iOS 13.0, *) {
        for scene in UIApplication.shared.connectedScenes {
            guard let windowScene = scene as? UIWindowScene,
                  windowScene.activationState == .foregroundActive else {
                continue
            }
            if let window = windowScene.windows.first(where: \.isKeyWindow) {
                return window
            }
            if let window = windowScene.windows.first {
                return window
            }
        }
    }
    return nil
}
