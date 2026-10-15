//
//  UIGraphicsImageRenderer+Workbench.swift
//  RepairWorkbench
//
//  Created by Jobs on 2026年10月15日，星期四.
//

import UIKit

extension UIGraphicsImageRenderer {
    // 按像素导出签名，避免Retina倍率令原件超过服务端尺寸上限。
    static func make(size: CGSize) -> UIGraphicsImageRenderer {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: size, format: format)
    }
}
