//
//  UIImage.swift
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
import CoreGraphics
/// 基础绘制

extension UIImage {
    /// 创建空图片；调用侧不直接使用 UIKit 空初始化器。
    public static func make(_ configure: (UIImage) -> Void) -> UIImage {
        let image = UIImage()
        configure(image)
        return image
    }

    /// 从明确的资源 Bundle 创建图片，保留找不到资源时的 nil 语义。
    public static func make(
        named name: String,
        in bundle: Bundle = .main,
        compatibleWith traits: UITraitCollection? = nil,
        configure: (UIImage) -> Void = { _ in }
    ) -> UIImage? {
        guard let image = UIImage(named: name, in: bundle, compatibleWith: traits) else {
            return nil
        }
        configure(image)
        return image
    }

    // MARK: - 绘制渐变色图片：任意方向线性渐变
    public convenience init?(gradientColors: [UIColor],
                             size: CGSize,
                             startPoint: CGPoint = .zero,       // 0~1 相对点
                             endPoint: CGPoint   = CGPoint(x: 1, y: 0),
                             opaque: Bool = false) {
        guard gradientColors.count >= 2,
              size.width > 0, size.height > 0 else { return nil }
        let renderer = UIGraphicsImageRenderer(size: size, format: {
            let f = UIGraphicsImageRendererFormat.default()
            f.opaque = opaque
            return f
        }())
        let img = renderer.image { ctx in
            let cgColors = gradientColors.map { $0.cgColor } as CFArray
            let space = CGColorSpaceCreateDeviceRGB()
            guard let gradient = CGGradient(colorsSpace: space,
                                            colors: cgColors,
                                            locations: nil) else { return }
            let sp = CGPoint(x: startPoint.x * size.width,
                             y: startPoint.y * size.height)
            let ep = CGPoint(x: endPoint.x * size.width,
                             y: endPoint.y * size.height)
            ctx.cgContext.drawLinearGradient(gradient, start: sp, end: ep, options: [])
        }
        guard let cg = img.cgImage else { return nil }
        self.init(cgImage: cg, scale: img.scale, orientation: .up)
    }
    // MARK: - 通用绘制器👉绘制纯色图片
    public static func solidColor(size: CGSize,
                                  color: UIColor,
                                  opaque: Bool = false) -> UIImage? {
        guard size.width > 0, size.height > 0 else { return nil }
        UIGraphicsBeginImageContextWithOptions(size, opaque, 0)
        defer { UIGraphicsEndImageContext() }
        color.setFill()
        UIRectFill(CGRect(origin: .zero, size: size))
        return UIGraphicsGetImageFromCurrentImageContext()
    }
    // MARK: - 按钮背景/控件填充👉将任意 UIColor 转换成一张纯色 UIImage
    public static func jobs_fromColor(_ color: UIColor, size: CGSize = CGSize(width: 1, height: 1)) -> UIImage {
        let rect = CGRect(origin: .zero, size: size)
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        color.setFill()
        UIRectFill(rect)
        let image = UIGraphicsGetImageFromCurrentImageContext() ?? UIImage.make { _ in }
        UIGraphicsEndImageContext()
        return image.resizableImage(withCapInsets: .zero, resizingMode: .stretch)
    }
    // MARK: - 图片转灰度
    public func grayScale() -> UIImage? {
        guard let cgImg = self.cgImage else { return nil }
        let scale = self.scale
        let width  = Int(size.width  * scale)
        let height = Int(size.height * scale)
        let colorSpace = CGColorSpaceCreateDeviceGray()
        let bitmapInfo = CGImageAlphaInfo.none.rawValue
        guard let ctx = CGContext(data: nil,
                                  width: width,
                                  height: height,
                                  bitsPerComponent: 8,
                                  bytesPerRow: 0,
                                  space: colorSpace,
                                  bitmapInfo: bitmapInfo) else {
            return nil
        }
        ctx.draw(cgImg, in: CGRect(x: 0, y: 0, width: width, height: height))
        guard let out = ctx.makeImage() else { return nil };return UIImage(cgImage: out, scale: scale, orientation: .up)
    }
    // MARK: - 用颜色生成图片（默认 1x1）
    static func fromColor(_ color: UIColor,
                          size: CGSize = CGSize(width: 1, height: 1)) -> UIImage {
        let rect = CGRect(origin: .zero, size: size)
        UIGraphicsBeginImageContextWithOptions(rect.size, false, 0)
        defer { UIGraphicsEndImageContext() }
        color.setFill()
        UIRectFill(rect)
        return UIGraphicsGetImageFromCurrentImageContext() ?? UIImage.make { _ in }
    }
}
/// 功能性方法
extension UIImage {
    /// 居中裁成正方形；像素边长超限时同步缩小，不放大小图。
    public func squareCropped(maximumPixelLength: CGFloat) -> UIImage? {
        let shortest = min(size.width, size.height)
        guard shortest > 0, scale > 0, maximumPixelLength > 0 else { return nil }
        let sourcePixelLength = shortest * scale
        let shouldDownsample = sourcePixelLength > maximumPixelLength
        let outputLength = shouldDownsample ? maximumPixelLength : shortest
        let outputScale = shouldDownsample ? 1.0 : scale
        let drawingScale = outputLength / shortest
        let outputSize = CGSize(width: outputLength, height: outputLength)
        UIGraphicsBeginImageContextWithOptions(outputSize, false, outputScale)
        defer { UIGraphicsEndImageContext() }
        draw(in: CGRect(
            x: (outputLength - size.width * drawingScale) / 2,
            y: (outputLength - size.height * drawingScale) / 2,
            width: size.width * drawingScale,
            height: size.height * drawingScale
        ))
        return UIGraphicsGetImageFromCurrentImageContext()
    }

    // MARK: - 拉伸适配（默认边距）
    func byResizable(edge: UIEdgeInsets = UIEdgeInsets(top: 10,
                                                       left: 20,
                                                       bottom: 10,
                                                       right: 20)) -> UIImage {
        return self.resizableImage(withCapInsets: edge, resizingMode: .stretch)
    }
    // MARK: - 圆角/圆形 + 内描边
    public func rounded(cornerRadius: CGFloat? = nil,
                        borderWidth: CGFloat = 0,
                        borderColor: UIColor = JobsCor.clear) -> UIImage? {
        let shortest = min(size.width, size.height)
        guard shortest > 0 else { return nil }
        let outputSize = CGSize(width: shortest, height: shortest)
        let rect = CGRect(origin: .zero, size: outputSize)
        UIGraphicsBeginImageContextWithOptions(outputSize, false, scale)
        defer { UIGraphicsEndImageContext() }
        let clipRadius = max(0, cornerRadius ?? shortest * 0.5)
        let clipPath: UIBezierPath = (cornerRadius == nil)
            ? UIBezierPath.make(ovalIn: rect)
            : UIBezierPath.make(roundedRect: rect, cornerRadius: clipRadius)
        clipPath.addClip()
        draw(in: CGRect(
            x: (shortest - size.width)  / 2,
            y: (shortest - size.height) / 2,
            width: size.width,
            height: size.height
        ))
        if borderWidth > 0 {
            let inset = borderWidth / 2
            let strokeRect = rect.insetBy(dx: inset, dy: inset)
            let strokeRadius = (cornerRadius == nil)
                ? strokeRect.width * 0.5
                : max(0, clipRadius - inset)
            let strokePath: UIBezierPath = (cornerRadius == nil)
                ? UIBezierPath.make(ovalIn: strokeRect)
                : UIBezierPath.make(roundedRect: strokeRect, cornerRadius: strokeRadius)
            borderColor.setStroke()
            strokePath.lineWidth = borderWidth
            strokePath.stroke()
        };return UIGraphicsGetImageFromCurrentImageContext()
    }
    // MARK: - 生成圆形图标
    static func circleIcon(diameter: CGFloat, color: UIColor) -> UIImage {
        let size = CGSize(width: diameter, height: diameter)
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        defer { UIGraphicsEndImageContext() }
        guard let ctx = UIGraphicsGetCurrentContext() else { return UIImage.make { _ in } }
        ctx.setFillColor(color.cgColor)
        ctx.fillEllipse(in: CGRect(origin: .zero, size: size))
        return UIGraphicsGetImageFromCurrentImageContext() ?? UIImage.make { _ in }
    }
    // MARK: - 图片叠加（overlay 居中 + 左右间距）
    func overlayed(with overlay: UIImage, horizontalInset: CGFloat = 2) -> UIImage {
        let size = self.size
        guard size.width > 0, size.height > 0 else { return self }
        UIGraphicsBeginImageContextWithOptions(size, false, self.scale)
        defer { UIGraphicsEndImageContext() }
        self.draw(in: CGRect(origin: .zero, size: size))
        let maxWidth = max(0, size.width - 2 * horizontalInset)
        guard maxWidth > 0, overlay.size.width > 0 else {
            return UIGraphicsGetImageFromCurrentImageContext() ?? self
        }
        let overlayHeight = overlay.size.height * (maxWidth / overlay.size.width)
        let overlayRect = CGRect(x: horizontalInset,
                                 y: (size.height - overlayHeight) / 2,
                                 width: maxWidth,
                                 height: overlayHeight)
        overlay.draw(in: overlayRect)
        return UIGraphicsGetImageFromCurrentImageContext() ?? self
    }
    //MARK: - 压缩图片至指定大小（字节）
    func compressed(to maxByteSize: Int,
                    minQuality: CGFloat = 0.3,
                    step: CGFloat = 0.1,
                    downscaleRatio: CGFloat = 0.9) -> Data? {
        guard maxByteSize > 0 else { return nil }
        let minQ = max(0, min(minQuality, 1))
        let stepQ = max(0.01, min(step, 0.5))
        let ratio = max(0.1, min(downscaleRatio, 0.99))
        guard let data = self.jpegData(compressionQuality: 1.0) else { return nil }
        if data.count <= maxByteSize { return data }
        // 逐步降低质量
        var q: CGFloat = 1.0
        while q > minQ {
            q -= stepQ
            if let d = self.jpegData(compressionQuality: q), d.count <= maxByteSize {
                return d
            }
        }
        // 缩尺寸 + 最低质量
        var currentImage = self
        while let d = currentImage.jpegData(compressionQuality: minQ) {
            if d.count <= maxByteSize { return d }
            let newSize = CGSize(width: currentImage.size.width * ratio,
                                 height: currentImage.size.height * ratio)
            if newSize.width < 16 || newSize.height < 16 { return d }
            autoreleasepool {
                UIGraphicsBeginImageContextWithOptions(newSize, false, 0)
                currentImage.draw(in: CGRect(origin: .zero, size: newSize))
                let resized = UIGraphicsGetImageFromCurrentImageContext()
                UIGraphicsEndImageContext()
                if let img = resized { currentImage = img }
            }
        };return nil
    }
}
