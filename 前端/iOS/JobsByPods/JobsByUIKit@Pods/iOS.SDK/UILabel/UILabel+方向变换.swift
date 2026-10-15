//
//  UILabel+方向变换.swift
//  JobsByUIKit
//
//  Created by Jobs on 2026年5月13日，星期三.
//

#if os(OSX)
import AppKit
#elseif os(iOS) || os(tvOS)
import UIKit
#endif

import JobsSwiftDSL
import JobsSwiftBaseDefines

extension UILabel {
    // MARK: 方向变换（使用 CATextLayer，避免富文本/对齐丢失）
    @discardableResult
    public func transformLayer(_ direction: TransformLayerDirectionType) -> Self {
        superview?.layoutIfNeeded()
        let oldTextLayers = layer.sublayers?
            .compactMap { $0 as? CATextLayer }
            .filter { $0.name == "JobsTextLayer" } ?? []
        let currentTextColor = textColor.cgColor
        /// UILabel 已隐藏原始文字时，沿用旧文字层颜色，保证重复布局后仍然可见
        let textLayerColor = currentTextColor.alpha == 0
        ? (oldTextLayers.first?.foregroundColor ?? currentTextColor)
        : currentTextColor
        oldTextLayers.forEach { $0.removeFromSuperlayer() }
        let textLayer = CATextLayer()
            .byName("JobsTextLayer")
            .byContentsScale(UIScreen.main.scale)
            .byAlignmentMode(._jobs_fromNSTextAlignment(textAlignment))
            .byTruncationMode((lineBreakMode == .byTruncatingHead) ? .start :
                                (lineBreakMode == .byTruncatingMiddle) ? .middle :
                                (lineBreakMode == .byTruncatingTail) ? .end : .none)
            .byWrapped((numberOfLines == 0))
        if let attributed = attributedText {
            textLayer.byString(attributed)
        } else {
            textLayer.byString(text ?? "")
                .byForegroundColor(textLayerColor)
                .byFont(font)
                .byFontSize(font.pointSize)
        }
        textLayer.byFrame(bounds)
        switch direction {
        /// 处理 .up 分支
        case .up:
            break
        /// 处理 .left 分支
        case .left:
            textLayer
                .byAnchorPoint(CGPoint(x: 0.5, y: 0.5))
                .byPosition(CGPoint(x: bounds.midX, y: bounds.midY))
                .byTransform(CATransform3DMakeRotation(-.pi/2, 0, 0, 1))
        /// 处理 .down 分支
        case .down:
            textLayer
                .byAnchorPoint(CGPoint(x: 0.5, y: 0.5))
                .byPosition(CGPoint(x: bounds.midX, y: bounds.midY))
                .byTransform(CATransform3DMakeRotation(.pi, 0, 0, 1))
        /// 处理 .right 分支
        case .right:
            textLayer.byAnchorPoint(CGPoint(x: 0.5, y: 0.5))
                .byPosition(CGPoint(x: bounds.midX, y: bounds.midY))
                .byTransform(CATransform3DMakeRotation(.pi/2, 0, 0, 1))
        }
        self.byAddSublayer(textLayer)
        byTextColor(JobsCor.clear) // 只显示 layer 的文字
        return self
    }
}
// MARK: - 对齐映射（CATextLayerAlignmentMode ← NSTextAlignment）
extension CATextLayerAlignmentMode {
    internal static func _jobs_fromNSTextAlignment(_ a: NSTextAlignment) -> CATextLayerAlignmentMode {
        switch a {
        /// 处理 .left 分支
        case .left: return .left
        /// 处理 .right 分支
        case .right: return .right
        /// 处理 .center 分支
        case .center: return .center
        /// 处理 .justified 分支
        case .justified: return .justified
        /// 处理 .natural 分支
        case .natural: return .natural
        /// 处理系统后续新增的未知枚举值
        @unknown default: return .natural
        }
    }
}
