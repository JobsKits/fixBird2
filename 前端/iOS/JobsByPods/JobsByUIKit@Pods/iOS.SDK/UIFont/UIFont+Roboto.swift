//
//  UIFont+Roboto.swift
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
    public enum Roboto {
        public static func Regular(_ size: CGFloat) -> UIFont {
            make("Roboto-Regular", size, fallback: .regular)
        }
        public static func Medium(_ size: CGFloat) -> UIFont  {
            make("Roboto-Medium",  size, fallback: .medium)
        }
        public static func Semibold(_ size: CGFloat) -> UIFont{
            make("Roboto-Semibold",size, fallback: .semibold)
        }
        private static func make(_ name: String,
                                 _ size: CGFloat,
                                 fallback: UIFont.Weight) -> UIFont {
            UIFont(name: name, size: size) ?? .systemFont(ofSize: size, weight: fallback)
        }
    }
}
