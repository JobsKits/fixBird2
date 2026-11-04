//
//  UIFont+DIN.swift
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
    public enum DINAlternate {
        public static func Bold(_ size: CGFloat) -> UIFont {
            make("DINAlternate-Bold", size, fallback: .bold)
        }
        private static func make(_ name: String,
                                 _ size: CGFloat,
                                 fallback: UIFont.Weight) -> UIFont {
            UIFont(name: name, size: size) ?? .systemFont(ofSize: size, weight: fallback)
        }
    }

    public enum DINPro {
        public static func Bold(_ size: CGFloat) -> UIFont {
            make("DINPro-Bold", size, fallback: .bold)
        }
        public static func Medium(_ size: CGFloat) -> UIFont {
            make("DINPro-Medium", size, fallback: .medium)
        }
        private static func make(_ name: String,
                                 _ size: CGFloat,
                                 fallback: UIFont.Weight) -> UIFont {
            UIFont(name: name, size: size) ?? .systemFont(ofSize: size, weight: fallback)
        }
    }
}
