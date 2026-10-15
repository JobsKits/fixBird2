//
//  UIFont+Avenir.swift
//  JobsByUIKit
//
//  Created by Jobs on 2026年5月13日，星期三.
//

#if os(OSX)
import AppKit
#elseif os(iOS) || os(tvOS)
import UIKit
#endif

extension UIFont {
    public enum Avenir {
        public static func Black(_ size: CGFloat) -> UIFont {
            UIFont(name: "Avenir-Black", size: size) ?? .systemFont(ofSize: size, weight: .black)
        }
    }
}
