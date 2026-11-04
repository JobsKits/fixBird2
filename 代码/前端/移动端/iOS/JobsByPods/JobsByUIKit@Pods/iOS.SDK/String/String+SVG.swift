//
//  String+SVG.swift
//  JobsByUIKit
//
//  Created by Jobs on 2026年5月13日，星期三.
//

#if os(OSX)
import AppKit
#elseif os(iOS) || os(tvOS)
import UIKit
#endif

import SVGKit

extension String {
    private static let _svgCache = NSCache<NSString, UIImage>()
    /// "会员卡".svg  -> UIImage?
    /// 支持自动补 .svg；默认从 main bundle 取资源
    public var svg: UIImage? {
        Self.svgImage(named: self,
                             in: .main,
                             size: nil,
                             scale: UIScreen.main.scale)
    }
    /// 可选：指定输出尺寸
    public func svg(size: CGSize?,
                    in bundle: Bundle = .main,
                    scale: CGFloat = UIScreen.main.scale) -> UIImage? {
        Self.svgImage(named: self,
                             in:bundle,
                             size: size,
                             scale: scale)
    }

    private static func svgImage(named name: String,
                                 in bundle: Bundle,
                                 size: CGSize?,
                                 scale: CGFloat) -> UIImage? {
        let fileName: String = {
            if name.lowercased().hasSuffix(".svg") { return name };return name + ".svg"
        }()
        let cacheKey = "\(bundle.bundleIdentifier ?? "main")|\(fileName)|\(size?.width ?? -1)x\(size?.height ?? -1)|\(scale)" as NSString
        if let cached = _svgCache.object(forKey: cacheKey) {
            return cached
        }
        guard let url = bundle.url(forResource: fileName, withExtension: nil) else {
            return nil
        }
        guard let svgkImage = SVGKImage(contentsOf: url) else {
            return nil
        }
        if let size = size, size.width > 0, size.height > 0 {
            svgkImage.size = size
        } else {
            let intrinsic = svgkImage.size
            if intrinsic.width <= 0 || intrinsic.height <= 0 {
                svgkImage.size = CGSize(width: 100, height: 100) // 防止 0-size 渲染失败
            }
        }
        guard let img = svgkImage.uiImage else { return nil }
        let final: UIImage
        if let cg = img.cgImage, img.scale != scale {
            final = UIImage(cgImage: cg, scale: scale, orientation: img.imageOrientation)
        } else {
            final = img
        }
        _svgCache.setObject(final, forKey: cacheKey)
        return final
    }
}
