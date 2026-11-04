//
//  UIFont+SourceSansPro.swift
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
    public enum SourceSansPro {
        public static func Regular(_ size: CGFloat) -> UIFont {
            make("SourceSansPro-Regular", size, fallback: .regular)
        }
        public static func Medium(_ size: CGFloat) -> UIFont {
            make("SourceSansPro-Semibold", size, fallback: .medium) // SourceSansPro 通常没有 Medium，用 Semibold 顶一下更接近
        }
        public static func Semibold(_ size: CGFloat) -> UIFont {
            make("SourceSansPro-Semibold", size, fallback: .semibold)
        }
        public static func Bold(_ size: CGFloat) -> UIFont {
            make("SourceSansPro-Bold", size, fallback: .bold)
        }
        private static func make(_ name: String,
                                 _ size: CGFloat,
                                 fallback: UIFont.Weight) -> UIFont {
            UIFont(name: name, size: size) ?? .systemFont(ofSize: size, weight: fallback)
        }
    }
}
