//
//  UIButton+Init.swift
//  JobsByUIKit
//
//  Created by Jobs on 2026年5月13日，星期三.
//

#if os(OSX)
import AppKit
#elseif os(iOS) || os(tvOS)
import UIKit
#endif

// MARK: - init
extension UIButton {
    public convenience init(x: CGFloat,
                            y: CGFloat,
                            w: CGFloat,
                            h: CGFloat,
                            target: AnyObject,
                            action: Selector) {
        self.init(frame: CGRect(x: x,
                                y: y,
                                width: w,
                                height: h))
        addTarget(target, action: action, for: .touchUpInside)
    }
    @available(iOS 7.0, *)
    public static func sys() -> UIButton {
        UIButton(type: .system)
    }

    public static func custom() -> UIButton {
        UIButton(type: .custom)
    }

    @available(iOS 13.0, *)
    public static func close() -> UIButton {
        UIButton(type: .close)
    }

    public static func detailDisclosure() -> UIButton {
        UIButton(type: .detailDisclosure)
    }

    public static func infoLight() -> UIButton {
        UIButton(type: .infoLight)
    }

    public static func infoDark() -> UIButton {
        UIButton(type: .infoDark)
    }

    public static func contactAdd() -> UIButton {
        UIButton(type: .contactAdd)
    }
}
