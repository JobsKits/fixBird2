//
//  String+二维码.swift
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

// MARK: 二维码
extension String {
    /// 由当前字符串生成二维码 UIImage（无插值放大，清晰）
    /// - Parameters:
    ///   - widthSize: 目标边长（正方形）
    ///   - correction: 纠错等级 L/M/Q/H（默认 M）
    /// - Returns: 生成的二维码图片；失败返回空 `UIImage.make { _ in }`
    @MainActor
    public func qrcodeImage(_ widthSize: CGFloat, correction: String = "M") -> UIImage {
        guard !self.isEmpty,
              let data = self.data(using: .utf8),
              let filter = CIFilter(name: "CIQRCodeGenerator")
        else { return UIImage.make { _ in } }
        filter.setDefaults()
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue(correction, forKey: "inputCorrectionLevel") // "L" "M" "Q" "H"
        guard let output = filter.outputImage, widthSize > 0 else { return UIImage.make { _ in } }
        // 无插值等比放大
        let scale = max(widthSize / output.extent.width, widthSize / output.extent.height)
        let scaled = output.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let context = CIContext(options: nil)
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return UIImage.make { _ in } };return UIImage(cgImage: cgImage)
    }
    /// 可选：着色版（前景/背景色）
    @MainActor
    public func qrcodeImage(_ widthSize: CGFloat,
                            foreground: UIColor,
                            background: UIColor = JobsCor.white,
                            correction: String = "M") -> UIImage {
        guard !self.isEmpty,
              let data = self.data(using: .utf8),
              let gen = CIFilter(name: "CIQRCodeGenerator"),
              let falseColor = CIFilter(name: "CIFalseColor")
        else { return UIImage.make { _ in } }
        gen.setDefaults()
        gen.setValue(data, forKey: "inputMessage")
        gen.setValue(correction, forKey: "inputCorrectionLevel")
        guard let qr = gen.outputImage else { return UIImage.make { _ in } }
        // 颜色映射
        falseColor.setValue(qr, forKey: kCIInputImageKey)
        falseColor.setValue(CIColor(color: foreground), forKey: "inputColor0")
        falseColor.setValue(CIColor(color: background), forKey: "inputColor1")
        guard let colored = falseColor.outputImage else { return UIImage.make { _ in } }
        // 无插值放大
        let scale = max(widthSize / colored.extent.width, widthSize / colored.extent.height)
        let scaled = colored.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let context = CIContext(options: nil)
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return UIImage.make { _ in } };return UIImage(cgImage: cgImage)
    }
    /// 生成带中心 Logo 的二维码
    /// - Parameters:
    ///   - widthSize: 二维码目标边长
    ///   - correction: 纠错等级（默认 H，便于盖 Logo）
    ///   - logo: 中心 Logo（可为 nil）
    ///   - logoRatio: Logo 相对二维码边长比例（0.18~0.25 比较稳）
    ///   - logoCornerRadius: Logo 圆角
    ///   - borderWidth: Logo 外围白边宽度
    ///   - borderColor: Logo 外围白边颜色
    /// - Returns: UIImage
    @MainActor
    public func qrcodeImage(
        _ widthSize: CGFloat,
        correction: String = "H",
        centerLogo logo: UIImage?,
        logoRatio: CGFloat = 0.22,
        logoCornerRadius: CGFloat = 8,
        borderWidth: CGFloat = 4,
        borderColor: UIColor = JobsCor.white
    ) -> UIImage {
        // 1) 先生成基础二维码（无插值放大）
        guard !isEmpty,
              let data = data(using: .utf8),
              let filter = CIFilter(name: "CIQRCodeGenerator"),
              widthSize > 0
        else { return UIImage.make { _ in } }
        filter.setDefaults()
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue(correction, forKey: "inputCorrectionLevel") // L/M/Q/H
        guard let output = filter.outputImage else { return UIImage.make { _ in } }
        let scale = max(widthSize / output.extent.width, widthSize / output.extent.height)
        let scaled = output.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let ciCtx = CIContext()
        guard let qrCG = ciCtx.createCGImage(scaled, from: scaled.extent) else { return UIImage.make { _ in } }
        let qrImage = UIImage(cgImage: qrCG)
        // 2) 若没有 Logo，直接返回
        guard let logo = logo else { return qrImage }
        // 3) 计算 Logo 尺寸与绘制区域
        let canvasSize = CGSize(width: widthSize, height: widthSize)
        let logoSide = max(8, min(widthSize * logoRatio, widthSize * 0.3)) // 兜底限制
        let logoRect = CGRect(
            x: (canvasSize.width  - logoSide) * 0.5,
            y: (canvasSize.height - logoSide) * 0.5,
            width: logoSide,
            height: logoSide
        )
        // 4) 合成：先画二维码，再画带白边+圆角裁剪的 Logo
        let renderer = UIGraphicsImageRenderer(size: canvasSize)
        return renderer.image { ctx in
            // 画 QR（已经是整像素放大，不会糊）
            qrImage.draw(in: CGRect(origin: .zero, size: canvasSize))
            // 画 Logo 外围白色边框（圆角矩形）
            if borderWidth > 0 {
                let borderRect = logoRect.insetBy(dx: -borderWidth, dy: -borderWidth)
                let borderPath = UIBezierPath.make(roundedRect: borderRect, cornerRadius: logoCornerRadius + borderWidth)
                borderColor.setFill()
                borderPath.fill()
            }
            // 裁剪圆角并画 Logo
            let clipPath = UIBezierPath.make(roundedRect: logoRect, cornerRadius: logoCornerRadius)
            clipPath.addClip()
            logo.draw(in: logoRect)
        }
    }
}
