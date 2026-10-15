//
//  NSObject+屏幕常亮.swift
//  JobsByUIKit
//
//  Created by Jobs on 2026年5月13日，星期三.
//

#if os(OSX)
import AppKit
#elseif os(iOS) || os(tvOS)
import UIKit
#endif

// MARK: - 屏幕常亮
extension NSObject {
    /// 屏幕是否保持常亮
    public var isScreenAlwaysOn: Bool {
        get { UIApplication.shared.isIdleTimerDisabled }
        set { UIApplication.shared.isIdleTimerDisabled = newValue }
    }
    /// 开启常亮
    public func keepScreenOn() {
        UIApplication.shared.isIdleTimerDisabled = true
    }
    /// 关闭常亮
    public func endScreenOn() {
        UIApplication.shared.isIdleTimerDisabled = false
    }
}
