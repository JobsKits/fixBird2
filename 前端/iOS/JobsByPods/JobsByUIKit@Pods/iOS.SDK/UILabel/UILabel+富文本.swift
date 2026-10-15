//
//  UILabel+富文本.swift
//  JobsByUIKit
//
//  Created by Jobs on 2026年5月13日，星期三.
//

#if os(OSX)
import AppKit
#elseif os(iOS) || os(tvOS)
import UIKit
#endif

import JobsTextTools

extension UILabel {
    // MARK: 设置富文本
    @discardableResult
    public func richTextBy(_ runs: [JobsRichRun],
                           paragraphStyle: NSMutableParagraphStyle? = nil)->Self {
        self.attributedText = JobsRichText.make(runs, paragraphStyle: paragraphStyle)
        self.isUserInteractionEnabled = false
        return self;
    }
    // MARK: - 检测点击位置是否在指定富文本范围内
    public func didTapAttributedText(in range: NSRange,
                                     at: UITapGestureRecognizer) -> Bool {
        guard let attributedText = attributedText else { return false }
        // 1️⃣ 创建 NSTextStorage 管理文本
        let textStorage = NSTextStorage(attributedString: attributedText)
        let layoutManager = NSLayoutManager()
        let textContainer = NSTextContainer(size: bounds.size)
        textContainer.lineFragmentPadding = 0
        textContainer.maximumNumberOfLines = numberOfLines
        textContainer.lineBreakMode = lineBreakMode
        layoutManager.addTextContainer(textContainer)
        textStorage.addLayoutManager(layoutManager)
        // 2️⃣ 计算点击位置
        let location = at.location(in: self)
        let textBoundingBox = layoutManager.usedRect(for: textContainer)
        let offset = CGPoint(
            x: (bounds.size.width - textBoundingBox.size.width) * 0.5 - textBoundingBox.origin.x,
            y: (bounds.size.height - textBoundingBox.size.height) * 0.5 - textBoundingBox.origin.y
        )
        let locationInTextContainer = CGPoint(
            x: location.x - offset.x,
            y: location.y - offset.y
        )
        // 3️⃣ 获取点击的字符索引
        let index = layoutManager.characterIndex(for: locationInTextContainer,
                                                 in: textContainer,
                                                 fractionOfDistanceBetweenInsertionPoints: nil)
        return NSLocationInRange(index, range)
    }
    // MARK: 给 UILabel 里的文字加 下划线，并且可以指定下划线的颜色。
    public func underline(color: UIColor) {
        if let textString = self.text {
            let attributedString = NSMutableAttributedString(string: textString)
            attributedString.addAttribute(NSAttributedString.Key.underlineStyle,
                                          value: NSUnderlineStyle.single.rawValue,
                                          range: NSRange(location: 0, length: attributedString.length))
            attributedString.addAttribute(NSAttributedString.Key.underlineColor,
                                          value: color,
                                          range: NSRange(location: 0, length: attributedString.length))
            self.attributedText = attributedString
        }
    }
}
