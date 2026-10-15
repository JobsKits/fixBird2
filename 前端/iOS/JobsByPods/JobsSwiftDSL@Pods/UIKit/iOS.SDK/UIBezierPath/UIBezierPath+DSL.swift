//
//  UIBezierPath+DSL.swift
//  JobsSwiftDSL
//
//  Created by Jobs on 2026年7月10日，星期五.
//

#if os(OSX)
import AppKit
#elseif os(iOS) || os(tvOS)
import UIKit
#endif

// MARK: - 路径编排
public extension UIBezierPath {
    @discardableResult
    func byMove(to point: CGPoint) -> Self {
        move(to: point)
        return self
    }

    @discardableResult
    func byAddLine(to point: CGPoint) -> Self {
        addLine(to: point)
        return self
    }

    @discardableResult
    func byAddArc(withCenter center: CGPoint,
                  radius: CGFloat,
                  startAngle: CGFloat,
                  endAngle: CGFloat,
                  clockwise: Bool) -> Self {
        addArc(
            withCenter: center,
            radius: radius,
            startAngle: startAngle,
            endAngle: endAngle,
            clockwise: clockwise
        );return self
    }

    @discardableResult
    func byClose() -> Self {
        close()
        return self
    }

    @discardableResult
    func byAppend(_ path: UIBezierPath) -> Self {
        append(path)
        return self
    }

    @discardableResult
    func byUsesEvenOddFillRule(_ enabled: Bool) -> Self {
        usesEvenOddFillRule = enabled
        return self
    }

    @discardableResult
    func byFill() -> Self {
        fill()
        return self
    }

    @discardableResult
    func byFill(with blendMode: CGBlendMode,
                alpha: CGFloat = 1) -> Self {
        fill(with: blendMode, alpha: alpha)
        return self
    }
}
