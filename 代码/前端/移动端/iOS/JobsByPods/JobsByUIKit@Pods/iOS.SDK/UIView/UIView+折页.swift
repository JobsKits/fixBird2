//
//  UIView+折页.swift
//  JobsByUIKit
//
//  Created by Jobs on 2026年5月13日，星期三.
//

#if os(OSX)
import AppKit
#elseif os(iOS) || os(tvOS)
import UIKit
#endif

extension UIView {
    /// 修改 anchorPoint 但不让 view 在父视图里“跳一下”
    public func setAnchorPointWithoutJump(_ point: CGPoint) {
        let oldOrigin = frame.origin
        layer.anchorPoint = point
        let newOrigin = frame.origin
        let transition = CGPoint(x: newOrigin.x - oldOrigin.x,
                                 y: newOrigin.y - oldOrigin.y)
        center = CGPoint(x: center.x - transition.x,
                         y: center.y - transition.y)
    }
}
