//
//  JobsBaseFont.swift
//  JobsSwiftBaseDefines
//
//  Created by Jobs on 2026年7月10日，星期五.
//

#if os(OSX)
import AppKit
#elseif os(iOS) || os(tvOS)
import UIKit
#endif

/// 系统字体的 Jobs 等价入口；调用侧不直接依赖 UIKit 的静态工厂。
public enum JobsFont {
    public static func systemFont(ofSize fontSize: CGFloat) -> UIFont {
        UIFont.systemFont(ofSize: fontSize)
    }

    public static func systemFont(ofSize fontSize: CGFloat,
                                  weight: UIFont.Weight) -> UIFont {
        UIFont.systemFont(ofSize: fontSize, weight: weight)
    }

    public static func boldSystemFont(ofSize fontSize: CGFloat) -> UIFont {
        UIFont.boldSystemFont(ofSize: fontSize)
    }

    public static func italicSystemFont(ofSize fontSize: CGFloat) -> UIFont {
        UIFont.italicSystemFont(ofSize: fontSize)
    }

    public static func monospacedDigitSystemFont(ofSize fontSize: CGFloat,
                                                 weight: UIFont.Weight) -> UIFont {
        UIFont.monospacedDigitSystemFont(ofSize: fontSize, weight: weight)
    }

    @available(iOS 13.0, tvOS 13.0, *)
    public static func monospacedSystemFont(ofSize fontSize: CGFloat,
                                            weight: UIFont.Weight) -> UIFont {
        UIFont.monospacedSystemFont(ofSize: fontSize, weight: weight)
    }

    public static func preferredFont(forTextStyle style: UIFont.TextStyle) -> UIFont {
        UIFont.preferredFont(forTextStyle: style)
    }

    public static func preferredFont(forTextStyle style: UIFont.TextStyle,
                                     compatibleWith traitCollection: UITraitCollection?) -> UIFont {
        UIFont.preferredFont(forTextStyle: style, compatibleWith: traitCollection)
    }
}
