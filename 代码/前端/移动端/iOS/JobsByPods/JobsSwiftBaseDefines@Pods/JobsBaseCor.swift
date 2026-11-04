//
//  JobsBaseCor.swift
//  JobsSwiftBaseDefines
//
//  Created by Jobs on 2026年5月13日，星期三.
//

#if os(OSX)
import AppKit
#elseif os(iOS) || os(tvOS)
import UIKit
#endif

public enum JobsCor {
    // MARK: - Core Resolver
    /// 尝试从运行时拿到系统颜色（避免老 SDK 直接引用符号导致编译失败）
    private static func resolveUIColor(_ selectorName: String) -> UIColor? {
        let sel = NSSelectorFromString(selectorName)
        guard UIColor.responds(to: sel),
              let any = UIColor.perform(sel)?.takeUnretainedValue(),
              let color = any as? UIColor
        else { return nil };return color
    }

    private static func dynamic13(_ selectorName: String,
                                  fallbackRGB: (CGFloat, CGFloat, CGFloat),
                                  a: CGFloat = 1) -> UIColor {
        if #available(iOS 13.0, *), let c = resolveUIColor(selectorName) {
            return c
        };return UIColor(r: fallbackRGB.0, g: fallbackRGB.1, b: fallbackRGB.2, a: a)
    }

    private static func dynamic15(_ selectorName: String,
                                  fallbackRGB: (CGFloat, CGFloat, CGFloat),
                                  a: CGFloat = 1) -> UIColor {
        if #available(iOS 15.0, *), let c = resolveUIColor(selectorName) {
            return c
        };return UIColor(r: fallbackRGB.0, g: fallbackRGB.1, b: fallbackRGB.2, a: a)
    }
}
// MARK: - UIKit Base Palette
public extension JobsCor {
    static var clear: UIColor { UIColor.clear }
    static var black: UIColor { UIColor.black }
    static var white: UIColor { UIColor.white }
    static var gray: UIColor { UIColor.gray }
    static var darkGray: UIColor { UIColor.darkGray }
    static var lightGray: UIColor { UIColor.lightGray }
    static var red: UIColor { UIColor.red }
    static var green: UIColor { UIColor.green }
    static var blue: UIColor { UIColor.blue }
    static var cyan: UIColor { UIColor.cyan }
    static var yellow: UIColor { UIColor.yellow }
    static var magenta: UIColor { UIColor.magenta }
    static var orange: UIColor { UIColor.orange }
    static var purple: UIColor { UIColor.purple }
    static var brown: UIColor { UIColor.brown }
}
// MARK: - UIKit System Palette
public extension JobsCor {
    static var systemRed: UIColor { UIColor.systemRed }
    static var systemBlue: UIColor { UIColor.systemBlue }
    static var systemGreen: UIColor { UIColor.systemGreen }
    static var systemOrange: UIColor { UIColor.systemOrange }
    static var systemYellow: UIColor { UIColor.systemYellow }
    static var systemPink: UIColor { UIColor.systemPink }
    static var systemPurple: UIColor { UIColor.systemPurple }
    static var systemTeal: UIColor { UIColor.systemTeal }
    static var systemGray: UIColor { UIColor.systemGray }
}
// MARK: - iOS 13+ Grays
public extension JobsCor {
    static var systemGray2: UIColor { dynamic13("systemGray2Color", fallbackRGB: (199, 199, 204)) }
    static var systemGray3: UIColor { dynamic13("systemGray3Color", fallbackRGB: (209, 209, 214)) }
    static var systemGray4: UIColor { dynamic13("systemGray4Color", fallbackRGB: (229, 229, 234)) }
    static var systemGray5: UIColor { dynamic13("systemGray5Color", fallbackRGB: (242, 242, 247)) }
    static var systemGray6: UIColor { dynamic13("systemGray6Color", fallbackRGB: (252, 252, 255)) } // 很浅，接近背景
}
// MARK: - iOS 13+ Labels / Link / Placeholder / Separator
public extension JobsCor {
    static var label: UIColor { JobsThemeCenter.shared.color(.textPrimary) }
    static var secondaryLabel: UIColor { JobsThemeCenter.shared.color(.textSecondary) }
    static var tertiaryLabel: UIColor { JobsThemeCenter.shared.color(.textTertiary) }
    static var quaternaryLabel: UIColor { JobsThemeCenter.shared.color(.textQuaternary) }

    static var link: UIColor { dynamic13("linkColor", fallbackRGB: (0, 122, 255)) }
    static var placeholderText: UIColor { JobsThemeCenter.shared.color(.textPlaceholder) }

    static var separator: UIColor { dynamic13("separatorColor", fallbackRGB: (60, 60, 67), a: 0.29) }
    static var opaqueSeparator: UIColor { dynamic13("opaqueSeparatorColor", fallbackRGB: (198, 198, 200)) }
}
// MARK: - iOS 13+ Backgrounds
public extension JobsCor {
    static var systemBackground: UIColor { JobsThemeCenter.shared.color(.backgroundPrimary) }
    static var secondarySystemBackground: UIColor { JobsThemeCenter.shared.color(.backgroundSecondary) }
    static var tertiarySystemBackground: UIColor { JobsThemeCenter.shared.color(.backgroundTertiary) }

    static var systemGroupedBackground: UIColor { JobsThemeCenter.shared.color(.backgroundGrouped) }
    static var secondarySystemGroupedBackground: UIColor { JobsThemeCenter.shared.color(.backgroundGroupedSecondary) }
    static var tertiarySystemGroupedBackground: UIColor { JobsThemeCenter.shared.color(.backgroundGroupedTertiary) }
}
// MARK: - iOS 13+ Fills
public extension JobsCor {
    static var systemFill: UIColor { dynamic13("systemFillColor", fallbackRGB: (120, 120, 128), a: 0.20) }
    static var secondarySystemFill: UIColor { dynamic13("secondarySystemFillColor", fallbackRGB: (120, 120, 128), a: 0.16) }
    static var tertiarySystemFill: UIColor { dynamic13("tertiarySystemFillColor", fallbackRGB: (120, 120, 128), a: 0.12) }
    static var quaternarySystemFill: UIColor { dynamic13("quaternarySystemFillColor", fallbackRGB: (120, 120, 128), a: 0.08) }
}
// MARK: - iOS 13+ More System Colors
public extension JobsCor {
    static var systemIndigo: UIColor { dynamic13("systemIndigoColor", fallbackRGB: (88, 86, 214)) }
    static var systemBrown: UIColor { dynamic13("systemBrownColor", fallbackRGB: (162, 132, 94)) }
}
// MARK: - iOS 15+ Mint / Cyan / Tint
public extension JobsCor {
    static var systemMint: UIColor { dynamic15("systemMintColor", fallbackRGB: (0, 199, 190)) } // 退化成偏 teal
    static var systemCyan: UIColor { dynamic15("systemCyanColor", fallbackRGB: (50, 173, 230)) }
    static var tintColor: UIColor { dynamic15("tintColor", fallbackRGB: (0, 122, 255)) }
}

extension UIColor {
    /// init method with RGB values from 0 to 255, instead of 0 to 1. With alpha(default:1)
    convenience init(r: CGFloat,
                     g: CGFloat,
                     b: CGFloat,
                     a: CGFloat = 1) {
        self.init(red: r / 255.0,
                  green: g / 255.0,
                  blue: b / 255.0,
                  alpha: a)
    }
    /// init method with RGB values from 0 to 255, instead of 0 to 1. With alpha(default:1)
    convenience init(_ r: CGFloat,
                     _ g: CGFloat,
                     _ b: CGFloat) {
        self.init(red: r / 255.0,
                  green: g / 255.0,
                  blue: b / 255.0,
                  alpha: 1.0)
    }
}
