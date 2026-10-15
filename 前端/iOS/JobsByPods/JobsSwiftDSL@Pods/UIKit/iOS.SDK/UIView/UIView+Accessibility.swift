//
//  UIView+Accessibility.swift
//  JobsSwiftDSL
//
//  Created by Jobs on 2026年10月5日，星期一.
//

import UIKit

public extension UIView {
    @discardableResult
    func byAccessibilityLabel(_ label: String?) -> Self {
        accessibilityLabel = label
        return self
    }
}
