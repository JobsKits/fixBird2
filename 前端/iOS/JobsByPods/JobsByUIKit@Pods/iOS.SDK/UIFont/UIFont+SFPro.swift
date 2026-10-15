//
//  UIFont+SFPro.swift
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
    public enum SFProText {
        // MARK: - Public API
        public static func Ultralight(_ size: CGFloat) -> UIFont {
            make(.ultralight, size: size)
        }
        public static func Thin(_ size: CGFloat) -> UIFont {
            make(.thin, size: size)
        }
        public static func Light(_ size: CGFloat) -> UIFont {
            make(.light, size: size)
        }
        public static func Regular(_ size: CGFloat) -> UIFont {
            make(.regular, size: size)
        }
        public static func Medium(_ size: CGFloat) -> UIFont {
            make(.medium, size: size)
        }
        public static func Semibold(_ size: CGFloat) -> UIFont {
            make(.semibold, size: size)
        }
        public static func Bold(_ size: CGFloat) -> UIFont {
            make(.bold, size: size)
        }
        // MARK: - Core
        private enum SFWeight: String {
            case ultralight = "Ultralight"
            case thin       = "Thin"
            case light      = "Light"
            case regular    = "Regular"
            case medium     = "Medium"
            case semibold   = "Semibold"
            case bold       = "Bold"
            var uiWeight: UIFont.Weight {
                switch self {
                /// 处理 .ultralight 分支
                case .ultralight: return .ultraLight
                /// 处理 .thin 分支
                case .thin:       return .thin
                /// 处理 .light 分支
                case .light:      return .light
                /// 处理 .regular 分支
                case .regular:    return .regular
                /// 处理 .medium 分支
                case .medium:     return .medium
                /// 处理 .semibold 分支
                case .semibold:   return .semibold
                /// 处理 .bold 分支
                case .bold:       return .bold
                }
            }
            var fontName: String { "SFProText-\(rawValue)" }
        }
        private static func make(_ weight: SFWeight, size: CGFloat) -> UIFont {
            if let font = UIFont(name: weight.fontName, size: size) {
                return font
            } else {
                // 名字不可用/系统差异时兜底：依然是 SF（系统会自己选 Text/Display）
                return .systemFont(ofSize: size, weight: weight.uiWeight)
            }
        }
    }

    public enum SFProDisplay {
        // MARK: - Public API
        public static func Regular(_ size: CGFloat) -> UIFont {
            make(.regular, size: size)
        }
        public static func Medium(_ size: CGFloat) -> UIFont {
            make(.medium, size: size)
        }
        public static func Semibold(_ size: CGFloat) -> UIFont {
            make(.semibold, size: size)
        }
        public static func Bold(_ size: CGFloat) -> UIFont {
            make(.bold, size: size)
        }
        // MARK: - Core
        private enum SFWeight: String {
            case regular  = "Regular"
            case medium   = "Medium"
            case semibold = "Semibold"
            case bold     = "Bold"
            var fontName: String { "SFProDisplay-\(rawValue)" }
            var uiWeight: UIFont.Weight {
                switch self {
                /// 处理 .regular 分支
                case .regular:  return .regular
                /// 处理 .medium 分支
                case .medium:   return .medium
                /// 处理 .semibold 分支
                case .semibold: return .semibold
                /// 处理 .bold 分支
                case .bold:     return .bold
                }
            }
        }
        private static func make(_ weight: SFWeight, size: CGFloat) -> UIFont {
            if let font = UIFont(name: weight.fontName, size: size) {
                return font
            } else {
                return .systemFont(ofSize: size, weight: weight.uiWeight)
            }
        }
    }
}
