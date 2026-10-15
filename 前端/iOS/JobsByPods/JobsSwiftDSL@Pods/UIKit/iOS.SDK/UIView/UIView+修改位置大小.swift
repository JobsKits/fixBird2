//
//  UIView+修改位置大小.swift
//  JobsByUIKit
//
//  Created by Jobs on 2026年5月13日，星期三.
//

#if os(OSX)
import AppKit
#elseif os(iOS) || os(tvOS)
import UIKit
#endif

import JobsSwiftBaseDefines
/// 对外需要加入

//#import <JobsByUIKit/JobsByUIKit-Swift.h>
//@import JobsByUIKit;
// MARK: - 自定义便捷计算属性@必要要暴露给OC
extension UIView {
    @objc public var x: CGFloat {
        get { frame.origin.x }
        set { frame.origin.x = newValue }
    }

    @objc public var y: CGFloat {
        get { frame.origin.y }
        set { frame.origin.y = newValue }
    }

    @objc public var maxX: CGFloat {
        self.x + self.width
    }

    @objc public var maxY: CGFloat {
        self.y + self.height
    }

    @objc public var centerX: CGFloat {
        get { center.x }
        set { center.x = newValue }
    }

    @objc public var centerY: CGFloat {
        get { center.y }
        set { center.y = newValue }
    }
    /// frame@origin
    @objc public var origin: CGPoint {
      get { frame.origin }
      set { frame.origin = newValue }
    }
    /// bounds@origin
    @objc public var boundsOrigin: CGPoint {
        get { bounds.origin }
        set { bounds.origin = newValue }
    }
    // MARK: 对UI控件@平面四个方向的坐标
    @objc public var top: CGFloat {
        get { frame.origin.y }
        set { frame.origin.y = newValue }
    }

    @objc public var left: CGFloat {
        get { frame.origin.x }
        set { frame.origin.x = newValue }
    }

    @objc public var bottom: CGFloat {
        get { frame.origin.y + frame.size.height }
        set { frame.origin.y = newValue - frame.size.height }
    }

    @objc public var right: CGFloat {
        get { frame.origin.x + frame.size.width }
        set { frame.origin.x = newValue - frame.size.width }
    }
    // MARK: 对UI控件@尺寸
    @objc public var size: CGSize {
        get { frame.size }
        set { frame.size = newValue }
    }

    @objc public var width: CGFloat {
        get { frame.size.width }
        set { frame.size.width = newValue }
    }

    @objc public var height: CGFloat {
        get { frame.size.height }
        set { frame.size.height = newValue }
    }

    @objc public var boundsSize: CGSize {
        get { bounds.size }
        set { bounds.size = newValue }
    }

    @objc public var boundsWidth: CGFloat {
        get { bounds.size.width }
        set { bounds.size.width = newValue }
    }

    @objc public var boundsHeight: CGFloat {
        get { bounds.size.height }
        set { bounds.size.height = newValue }
    }
}
// MARK: - 修改位置大小@DSL系统API结构体
extension UIView {
    @discardableResult
    public func byFrame(_ f: CGRect) -> Self {
        frame = f
        return self
    }

    @discardableResult
    public func byCenter(_ c: CGPoint) -> Self {
        center = c
        return self
    }

    @discardableResult
    public func byBounds(_ b: CGRect) -> Self {
        bounds = b
        return self
    }
}
// MARK: - 自定义便捷计算属性@DSL
extension UIView {
    @discardableResult
    public func byX(_ value: CGFloat) -> Self {
        x = value
        return self
    }

    @discardableResult
    public func byY(_ value: CGFloat) -> Self {
        y = value
        return self
    }

    @discardableResult
    public func byCenterX(_ value: CGFloat) -> Self {
        centerX = value
        return self
    }

    @discardableResult
    public func byCenterY(_ value: CGFloat) -> Self {
        centerY = value
        return self
    }

    @discardableResult
    public func byOrigin(_ value: CGPoint) -> Self {
        origin = value
        return self
    }

    @discardableResult
    public func byTop(_ value: CGFloat) -> Self {
        top = value
        return self
    }

    @discardableResult
    public func byLeft(_ value: CGFloat) -> Self {
        left = value
        return self
    }

    @discardableResult
    public func byBottom(_ value: CGFloat) -> Self {
        bottom = value
        return self
    }

    @discardableResult
    public func byRight(_ value: CGFloat) -> Self {
        right = value
        return self
    }
    // MARK: - UIView@尺寸
    @discardableResult
    public func byWidth(_ value: CGFloat) -> Self {
        width = value
        return self
    }

    @discardableResult
    public func byHeight(_ value: CGFloat) -> Self {
        height = value
        return self
    }

    @discardableResult
    public func bySize(_ value: CGSize) -> Self {
        size = value
        return self
    }

    @discardableResult
    public func byBoundsOrigin(_ value: CGPoint) -> Self {
        boundsOrigin = value
        return self
    }

    @discardableResult
    public func byBoundsSize(_ value: CGSize) -> Self {
        boundsSize = value
        return self
    }

    @discardableResult
    public func byBoundsWidth(_ value: CGFloat) -> Self {
        boundsWidth = value
        return self
    }

    @discardableResult
    public func byBoundsHeight(_ value: CGFloat) -> Self {
        boundsHeight = value
        return self
    }
}
// MARK: X/Y
extension UIView {
    /// 在当前宽度基础上叠加偏移（正负皆可）
    @discardableResult
    public func byWidthOffset(_ delta: CGFloat) -> Self {
        var f = frame
        f.size.width += delta
        frame = f
        return self
    }
    /// 在当前高度基础上叠加偏移（正负皆可）
    @discardableResult
    public func byHeightOffset(_ delta: CGFloat) -> Self {
        var f = frame
        f.size.height += delta
        frame = f
        return self
    }
}
// MARK: center
extension UIView {
    /// 在当前中心点基础上叠加偏移
    @discardableResult
    public func byCenterOffset(dx: CGFloat = 0,
                               dy: CGFloat = 0) -> Self {
        center = CGPoint(x: center.x + dx, y: center.y + dy)
        return self
    }
}
// MARK: frame
extension UIView {
    @discardableResult
    public func byFrame(x: CGFloat? = nil,
                        y: CGFloat? = nil,
                        width: CGFloat? = nil,
                        height: CGFloat? = nil) -> Self {
        var f = frame
        if let x = x { f.origin.x = x }
        if let y = y { f.origin.y = y }
        if let w = width { f.size.width = w }
        if let h = height { f.size.height = h }
        frame = f
        return self
    }

    @discardableResult
    public func byFrame(origin: CGPoint? = nil,
                        size: CGSize? = nil) -> Self {
        var f = frame
        if let origin { f.origin = origin }
        if let size { f.size = size }
        frame = f
        return self
    }

    @discardableResult
    func byFrame(_ patch: FramePatch) -> Self {
        var f = frame
        if let x = patch.x { f.origin.x = x }
        if let y = patch.y { f.origin.y = y }
        if let w = patch.width { f.size.width = w }
        if let h = patch.height { f.size.height = h }
        frame = f
        return self
    }
    /// 在当前 frame 基础上整体偏移（位置 + 尺寸）
    @discardableResult
    public func byFrameOffset(dx: CGFloat = 0,
                              dy: CGFloat = 0,
                              dw: CGFloat = 0,
                              dh: CGFloat = 0) -> Self {
        var f = frame
        f.origin.x += dx
        f.origin.y += dy
        f.size.width += dw
        f.size.height += dh
        frame = f
        return self
    }
}
// MARK: frame.origin
extension UIView {
    /// 在当前 x/y 基础上叠加偏移
    @discardableResult
    public func byOriginOffset(dx: CGFloat = 0,
                               dy: CGFloat = 0) -> Self {
        var f = frame
        f.origin.x += dx
        f.origin.y += dy
        frame = f
        return self
    }
    @discardableResult
    public func byOriginXOffset(_ dx: CGFloat = 0) -> Self {
        var f = frame
        f.origin.x += dx
        frame = f
        return self
    }
    @discardableResult
    public func byOriginYOffset(_ dy: CGFloat = 0) -> Self {
        var f = frame
        f.origin.y += dy
        frame = f
        return self
    }
}
// MARK: bySize
extension UIView {
    /// 允许在链式调用里“根据自身当前状态”计算 size
    @discardableResult
    public func bySize(_ make: (Self) -> CGSize) -> Self {
        sizeToFit()
        frame.size = make(self)
        return self
    }

    @discardableResult
    public func bySize(width: CGFloat,
                       height: CGFloat) -> Self {
        frame.size = CGSize(width: width, height: height)
        return self
    }
    /// 同时对宽高做偏移（正负皆可）
    @discardableResult
    public func bySizeOffset(width dw: CGFloat = 0,
                             height dh: CGFloat = 0) -> Self {
        var f = frame
        f.size.width += dw
        f.size.height += dh
        frame = f
        return self
    }
}
