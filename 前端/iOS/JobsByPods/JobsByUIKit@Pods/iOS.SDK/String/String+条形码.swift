//
//  String+条形码.swift
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

// MARK: 条形码
extension String {
    /// Code128 条形码（可指定目标尺寸；自动无插值放大）
    /// - Parameters:
    ///   - size: 目标尺寸（建议宽>>高，如 260x100）
    ///   - quietSpace: 左右留白（点数，默认 7）
    @MainActor
    public func code128BarcodeImage(size: CGSize, quietSpace: CGFloat = 7) -> UIImage {
        guard !isEmpty,
              // Code128 推荐 ASCII；退化到 UTF8 也给过
              let msg = (self.data(using: .ascii) ?? self.data(using: .utf8)),
              let f = CIFilter(name: "CICode128BarcodeGenerator") else { return UIImage.make { _ in } }
        f.setDefaults()
        f.setValue(msg, forKey: "inputMessage")
        f.setValue(quietSpace, forKey: "inputQuietSpace") // 左右静区
        guard let out = f.outputImage, size.width > 0, size.height > 0 else { return UIImage.make { _ in } }
        // 非等比缩放到目标尺寸（条形码需要明确宽高）
        let scaleX: CGFloat = size.width  / out.extent.width
        let scaleY: CGFloat = size.height / out.extent.height
        let scaled = out.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
        let ctx = CIContext()
        guard let cg = ctx.createCGImage(scaled, from: scaled.extent) else { return UIImage.make { _ in } };return UIImage(cgImage: cg)
    }
    /// 生成带底部文字的人类可读 Code128 条形码
    /// - Parameters:
    ///   - width: 整体宽度（条码与文字共用）
    ///   - barHeight: 条码区高度
    ///   - quietSpace: 左右静区（点数）
    ///   - spacing: 条码与文字的间距
    ///   - font: 文字字体；会自动按宽度收缩
    ///   - textColor: 文字颜色（默认黑）
    ///   - background: 背景色（默认白）
    /// - Returns: UIImage
    @MainActor
    public func code128ByText(width: CGFloat,
                              barHeight: CGFloat = 100,
                              quietSpace: CGFloat = 7,
                              spacing: CGFloat = 6,
                              font: UIFont = JobsFont.monospacedDigitSystemFont(ofSize: 16, weight: .regular),
                              textColor: UIColor = JobsCor.black,
                              background: UIColor = JobsCor.white) -> UIImage {
        guard !isEmpty,
              let msg = (self.data(using: .ascii) ?? self.data(using: .utf8)),
              let f = CIFilter(name: "CICode128BarcodeGenerator"),
              width > 0, barHeight > 0
        else { return UIImage.make { _ in } }
        // 1) 生成条形码 CIImage
        f.setDefaults()
        f.setValue(msg, forKey: "inputMessage")
        f.setValue(quietSpace, forKey: "inputQuietSpace")
        guard let out = f.outputImage else { return UIImage.make { _ in } }
        // 2) 放大到目标条码尺寸（非等比按宽/高分别缩放）
        let scaleX = width  / out.extent.width
        let scaleY = barHeight / out.extent.height
        let scaled = out.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
        let ctx = CIContext()
        guard let cgBar = ctx.createCGImage(scaled, from: scaled.extent) else { return UIImage.make { _ in } }
        // 3) 计算文字区域高度（先用行高；若太宽会缩放字体）
        _ = font.lineHeight
        var drawFont = font
        let attr: [NSAttributedString.Key: Any] = [.font: drawFont]
        var textSize = (self as NSString).size(withAttributes: attr)
        if textSize.width > width { // 太宽就按比例缩小字体
            let factor = width / textSize.width
            drawFont = JobsFont.monospacedDigitSystemFont(ofSize: max(8, font.pointSize * factor),
                                                  weight: (font.fontDescriptor.symbolicTraits.contains(.traitBold) ? .bold : .regular))
            textSize = (self as NSString).size(withAttributes: [.font: drawFont])
        }
        let totalHeight = barHeight + spacing + ceil(textSize.height)
        // 4) 合成：上条码、下文字
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: totalHeight))
        return renderer.image { ctx in
            // 背景
            background.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: width, height: totalHeight))
            // 条码
            let barRect = CGRect(x: 0, y: 0, width: width, height: barHeight)
            UIImage(cgImage: cgBar).draw(in: barRect, blendMode: .normal, alpha: 1)
            // 文字（居中）
            let textY = barHeight + spacing
            let textX = (width - textSize.width) * 0.5
            (self as NSString).draw(at: CGPoint(x: textX, y: textY),
                                    withAttributes: [.font: drawFont, .foregroundColor: textColor])
        }
    }
}
