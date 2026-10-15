//
//  UIButton+防止快速连点.swift
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

// MARK: - 防止快速连点
extension UIButton {
    public func disableAfterClick(interval: TimeInterval = 1.0) {
        byUserInteractionEnabled(false)
        DispatchQueue.main.asyncAfter(deadline: .now() + interval) {
            self.isUserInteractionEnabled = true
        }
    }
}
