//
//  UIMenu.swift
//  JobsByUIKit
//
//  Created by Jobs on 2026年7月10日，星期五.
//

#if os(OSX)
import AppKit
#elseif os(iOS) || os(tvOS)
import UIKit
#endif

@available(iOS 13.0, tvOS 13.0, *)
public extension UIMenu {
    static func make(
        title: String = "",
        image: UIImage? = nil,
        identifier: UIMenu.Identifier? = nil,
        options: UIMenu.Options = [],
        children: [UIMenuElement]
    ) -> UIMenu {
        UIMenu(
            title: title,
            image: image,
            identifier: identifier,
            options: options,
            children: children
        )
    }
}
