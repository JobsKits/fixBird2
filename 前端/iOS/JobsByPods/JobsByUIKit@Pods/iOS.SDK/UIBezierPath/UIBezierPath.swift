//
//  UIBezierPath.swift
//  JobsByUIKit
//
//  Created by Jobs on 2026年7月10日，星期五.
//

#if os(OSX)
import AppKit
#elseif os(iOS) || os(tvOS)
import UIKit
#endif

// MARK: - 创建工厂
public extension UIBezierPath {
    /// 创建空路径。
    static func make() -> UIBezierPath {
        UIBezierPath()
    }

    /// 创建矩形路径。
    static func make(rect: CGRect) -> UIBezierPath {
        UIBezierPath(rect: rect)
    }

    /// 创建内接于矩形的椭圆路径。
    static func make(ovalIn rect: CGRect) -> UIBezierPath {
        UIBezierPath(ovalIn: rect)
    }

    /// 创建统一圆角的矩形路径。
    static func make(roundedRect rect: CGRect,
                     cornerRadius: CGFloat) -> UIBezierPath {
        UIBezierPath(roundedRect: rect, cornerRadius: cornerRadius)
    }

    /// 创建指定圆角位置和半径的矩形路径。
    static func make(roundedRect rect: CGRect,
                     byRoundingCorners corners: UIRectCorner,
                     cornerRadii: CGSize) -> UIBezierPath {
        UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: cornerRadii
        )
    }

    /// 创建圆弧路径。
    static func make(arcCenter center: CGPoint,
                     radius: CGFloat,
                     startAngle: CGFloat,
                     endAngle: CGFloat,
                     clockwise: Bool) -> UIBezierPath {
        UIBezierPath(
            arcCenter: center,
            radius: radius,
            startAngle: startAngle,
            endAngle: endAngle,
            clockwise: clockwise
        )
    }
}
