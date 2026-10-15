//
//  CALayer.swift
//  JobsByQuartzCore
//
//  Created by Jobs on 2026年5月13日，星期三.
//

#if os(OSX)
import AppKit
#elseif os(iOS) || os(tvOS)
import UIKit
#endif

extension CALayer {
    // MARK: - 几何 & 变换
    @discardableResult
    public func byBounds(_ bounds: CGRect) -> Self {
        self.bounds = bounds
        return self
    }

    @discardableResult
    public func byFrame(_ frame: CGRect) -> Self {
        self.frame = frame
        return self
    }

    @discardableResult
    public func byPosition(_ position: CGPoint) -> Self {
        self.position = position
        return self
    }

    @discardableResult
    public func byZPosition(_ z: CGFloat) -> Self {
        self.zPosition = z
        return self
    }

    @discardableResult
    public func byAnchorPoint(_ point: CGPoint) -> Self {
        self.anchorPoint = point
        return self
    }

    @discardableResult
    public func byAnchorPointZ(_ z: CGFloat) -> Self {
        self.anchorPointZ = z
        return self
    }

    @discardableResult
    public func byTransform(_ transform: CATransform3D) -> Self {
        self.transform = transform
        return self
    }

    @discardableResult
    public func byAffineTransform(_ transform: CGAffineTransform) -> Self {
        setAffineTransform(transform)
        return self
    }
    // MARK: - 显隐 / 翻转
    @discardableResult
    public func byHidden(_ hidden: Bool) -> Self {
        self.isHidden = hidden
        return self
    }

    @discardableResult
    public func byDoubleSided(_ flag: Bool) -> Self {
        self.isDoubleSided = flag
        return self
    }

    @discardableResult
    public func byGeometryFlipped(_ flag: Bool) -> Self {
        self.isGeometryFlipped = flag
        return self
    }
    // MARK: - 层级关系
    /// 把当前 layer 加到指定 superLayer 下
    @discardableResult
    public func byAddTo(_ superLayer: CALayer?) -> Self {
        superLayer?.addSublayer(self)
        return self
    }
    /// 当前 layer 追加一个子 layer
    @discardableResult
    public func byAddSublayer(_ layer: CALayer) -> Self {
        addSublayer(layer)
        return self
    }

    @discardableResult
    public func byInsertSublayer(_ layer: CALayer, at index: UInt32) -> Self {
        insertSublayer(layer, at: index)
        return self
    }

    @discardableResult
    public func byInsertSublayer(_ layer: CALayer, below sibling: CALayer?) -> Self {
        insertSublayer(layer, below: sibling)
        return self
    }

    @discardableResult
    public func byInsertSublayer(_ layer: CALayer, above sibling: CALayer?) -> Self {
        insertSublayer(layer, above: sibling)
        return self
    }

    @discardableResult
    public func byReplaceSublayer(_ old: CALayer, with newLayer: CALayer) -> Self {
        replaceSublayer(old, with: newLayer)
        return self
    }

    @discardableResult
    public func bySublayerTransform(_ transform: CATransform3D) -> Self {
        self.sublayerTransform = transform
        return self
    }

    @discardableResult
    public func byMask(_ mask: CALayer?) -> Self {
        self.mask = mask
        return self
    }
    /// 圆角遮罩（你原来的接口）
    @discardableResult
    public func byMasksToBounds(_ enabled: Bool) -> Self {
        self.masksToBounds = enabled
        return self
    }

    @discardableResult
    public func byRemoveFromSuperlayer() -> Self {
        removeFromSuperlayer()
        return self
    }
    // MARK: - 内容 & 拉伸
    @discardableResult
    public func byContents(_ contents: Any?) -> Self {
        self.contents = contents
        return self
    }

    @discardableResult
    public func byContentsRect(_ rect: CGRect) -> Self {
        self.contentsRect = rect
        return self
    }

    @discardableResult
    public func byContentsGravity(_ gravity: CALayerContentsGravity) -> Self {
        self.contentsGravity = gravity
        return self
    }

    @discardableResult
    public func byContentsScale(_ scale: CGFloat) -> Self {
        self.contentsScale = scale
        return self
    }

    @discardableResult
    public func byContentsCenter(_ rect: CGRect) -> Self {
        self.contentsCenter = rect
        return self
    }
    // MARK: - 背景 & 圆角 & 边框
    /// 新的通用命名（可选 UIColor）
    @discardableResult
    public func byBackgroundColor(_ color: UIColor?) -> Self {
        self.backgroundColor = color?.cgColor
        return self
    }

    @discardableResult
    public func byBackgroundCGColor(_ color: CGColor?) -> Self {
        self.backgroundColor = color
        return self
    }
    /// 圆角（你原来的方法名，直接复用）
    @discardableResult
    public func byCornerRadius(_ radius: CGFloat) -> Self {
        self.cornerRadius = radius
        return self
    }

    @available(iOS 11.0, *)
    @discardableResult
    public func byMaskedCorners(_ corners: CACornerMask) -> Self {
        self.maskedCorners = corners
        return self
    }

    @available(iOS 13.0, *)
    @discardableResult
    public func byCornerCurve(_ curve: CALayerCornerCurve) -> Self {
        self.cornerCurve = curve
        return self
    }
    /// 边框宽度
    @discardableResult
    public func byBorderWidth(_ width: CGFloat) -> Self {
        self.borderWidth = width
        return self
    }
    /// 边框颜色
    @discardableResult
    public func byBorderColor(_ color: UIColor) -> Self {
        self.borderColor = color.cgColor
        return self
    }

    @discardableResult
    public func byBorderCGColor(_ color: CGColor?) -> Self {
        self.borderColor = color
        return self
    }
    // MARK: - 透明度 & 光栅化
    /// 透明度（你原来的方法名）
    @discardableResult
    public func byOpacity(_ value: Float) -> Self {
        self.opacity = value
        return self
    }

    @discardableResult
    public func byAllowsGroupOpacity(_ flag: Bool) -> Self {
        self.allowsGroupOpacity = flag
        return self
    }

    @discardableResult
    public func byShouldRasterize(_ flag: Bool) -> Self {
        self.shouldRasterize = flag
        return self
    }

    @discardableResult
    public func byRasterizationScale(_ scale: CGFloat) -> Self {
        self.rasterizationScale = scale
        return self
    }

    @discardableResult
    public func byOpaque(_ flag: Bool) -> Self {
        self.isOpaque = flag
        return self
    }
    // MARK: - 阴影（融合你原来的命名）
    @discardableResult
    public func byShadowColor(_ color: UIColor?) -> Self {
        self.shadowColor = color?.cgColor
        return self
    }
    /// 兼容你原来的 `byShadowOpacity(opacity:)`
    @discardableResult
    public func byShadowOpacity(_ opacity: Float = 0.5) -> Self {
        self.shadowOpacity = opacity
        return self
    }

    @discardableResult
    public func byShadowOffset(_ offset: CGSize = .zero) -> Self {
        self.shadowOffset = offset
        return self
    }

    @discardableResult
    public func byShadowRadius(_ radius: CGFloat = 3) -> Self {
        self.shadowRadius = radius
        return self
    }

    @discardableResult
    public func byShadow(color: UIColor,
                  opacity: Float = 0.5,
                  offset: CGSize = .zero,
                  radius: CGFloat = 3) -> Self {
        self.shadowColor = color.cgColor
        self.shadowOpacity = opacity
        self.shadowOffset = offset
        self.shadowRadius = radius
        return self
    }
    // MARK: - 布局 / 重绘
    @discardableResult
    public func byNeedsDisplayOnBoundsChange(_ flag: Bool) -> Self {
        self.needsDisplayOnBoundsChange = flag
        return self
    }

    @discardableResult
    public func byDrawsAsynchronously(_ flag: Bool) -> Self {
        self.drawsAsynchronously = flag
        return self
    }
    // MARK: - 名称 / 代理 / 样式
    @discardableResult
    public func byName(_ name: String?) -> Self {
        self.name = name
        return self
    }

    @discardableResult
    @inlinable
    public func byActions(_ v: [String: CAAction]?) -> Self {
        self.actions = v
        return self
    }

    @discardableResult
    public func byDelegate(_ delegate: CALayerDelegate?) -> Self {
        self.delegate = delegate
        return self
    }

    @discardableResult
    public func byStyle(_ style: [AnyHashable : Any]) -> Self {
        self.style = style
        return self
    }
    // MARK: - 通用 builder
    @discardableResult
    public func byConfig(_ builder: (CALayer) -> Void) -> Self {
        builder(self)
        return self
    }
}
