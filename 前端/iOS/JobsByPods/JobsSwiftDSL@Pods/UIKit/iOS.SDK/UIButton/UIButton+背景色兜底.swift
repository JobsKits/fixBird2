//
//  UIButton+背景色兜底.swift
//  JobsByUIKit
//
//  Created by Jobs on 2026年5月13日，星期三.
//

#if os(OSX)
import AppKit
#elseif os(iOS) || os(tvOS)
import UIKit
#endif

// MARK: - 背景色兜底
extension UIButton {
    public func setBgCor(_ color: UIColor, forState: UIControl.State) {
        UIGraphicsBeginImageContext(CGSize(width: 1, height: 1))
        UIGraphicsGetCurrentContext()?.setFillColor(color.cgColor)
        UIGraphicsGetCurrentContext()?.fill(CGRect(x: 0, y: 0, width: 1, height: 1))
        UIGraphicsEndImageContext()
        setBackgroundImage(UIGraphicsGetImageFromCurrentImageContext(), for: forState)
    }

    public func setBackgroundColor(_ color: UIColor, forState state: UIControl.State) {
        let size = CGSize(width: 1, height: 1)
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        color.setFill()
        UIBezierPath(rect: CGRect(origin: .zero, size: size)).fill()
        UIGraphicsEndImageContext()
        setBackgroundImage(UIGraphicsGetImageFromCurrentImageContext(), for: state)
    }
}
