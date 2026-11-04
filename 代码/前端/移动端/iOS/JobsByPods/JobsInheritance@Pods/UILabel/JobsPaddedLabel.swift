//
//  JobsPaddedLabel.swift
//  JobsInheritance
//
//  Created by Jobs on 2026年5月13日，星期三.
//

#if os(OSX)
import AppKit
#elseif os(iOS) || os(tvOS)
import UIKit
#endif

// MARK: 是实现 UILabel 的左右内边距，让文字和边框之间留点空隙，解决系统 UILabel 没有 padding 的问题
final class JobsPaddedLabel: UILabel {
    @IBInspectable var horizontalPadding: CGFloat = 0
    @IBInspectable var verticalPadding: CGFloat = 0

    private var insets: UIEdgeInsets {
        UIEdgeInsets(top: verticalPadding, left: horizontalPadding,
                     bottom: verticalPadding, right: horizontalPadding)
    }

    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.inset(by: insets))
    }

    override var intrinsicContentSize: CGSize {
        var size = super.intrinsicContentSize
        size.width  += insets.left + insets.right
        size.height += insets.top  + insets.bottom
        return size
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        // 让 AutoLayout / 手算尺寸都准确
        let target = CGRect(origin: .zero, size: size).inset(by: insets).size
        var s = super.sizeThatFits(target)
        s.width  += insets.left + insets.right
        s.height += insets.top  + insets.bottom
        return s
    }
}
