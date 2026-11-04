//
//  UIColor.swift
//  JobsByUIKit
//
//  Created by Jobs on 2026年5月13日，星期三.
//

#if os(OSX)
import AppKit
#elseif os(iOS) || os(tvOS)
import UIKit
#endif

extension UIColor {
    /// init method with RGB values from 0 to 255, instead of 0 to 1. With alpha(default:1)
    public convenience init(r: CGFloat,
                            g: CGFloat,
                            b: CGFloat,
                            a: CGFloat = 1) {
        self.init(red: r / 255.0,
                  green: g / 255.0,
                  blue: b / 255.0,
                  alpha: a)
    }
    /// init method with RGB values from 0 to 255, instead of 0 to 1. With alpha(default:1)
    public convenience init(_ r: CGFloat,
                            _ g: CGFloat,
                            _ b: CGFloat) {
        self.init(red: r / 255.0,
                  green: g / 255.0,
                  blue: b / 255.0,
                  alpha: 1.0)
    }
    /// init method with hex string and alpha(default: 1)
    /// 支持格式：
    /// "#RRGGBB" / "RRGGBB" / "0xRRGGBB"
    /// "#RGB"   / "RGB"
    /// "#AARRGGBB" / "AARRGGBB"
    public convenience init?(hexString: String,
                             alpha: CGFloat = 1) {
        var hex = hexString.trimmingCharacters(in: .whitespacesAndNewlines)
                           .lowercased()
        // 去掉前缀
        if hex.hasPrefix("#") {
            hex.removeFirst()
        } else if hex.hasPrefix("0x") {
            hex.removeFirst(2)
        }
        // 3 位压缩格式：RGB -> RRGGBB
        if hex.count == 3 {
            let r = hex[hex.startIndex]
            let g = hex[hex.index(hex.startIndex, offsetBy: 1)]
            let b = hex[hex.index(hex.startIndex, offsetBy: 2)]
            hex = "\(r)\(r)\(g)\(g)\(b)\(b)"
        }
        var a: CGFloat = alpha
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var value: UInt64 = 0
        guard Scanner(string: hex).scanHexInt64(&value) else { return nil }
        switch hex.count {
        /// RRGGBB
        case 6:
            r = CGFloat((value & 0xFF0000) >> 16) / 255.0
            g = CGFloat((value & 0x00FF00) >> 8)  / 255.0
            b = CGFloat( value & 0x0000FF)        / 255.0
        /// AARRGGBB
        case 8:
            a = CGFloat((value & 0xFF000000) >> 24) / 255.0
            r = CGFloat((value & 0x00FF0000) >> 16) / 255.0
            g = CGFloat((value & 0x0000FF00) >> 8)  / 255.0
            b = CGFloat( value & 0x000000FF)        / 255.0
        /// 未匹配已知分支时执行兜底处理
        default:
            return nil
        };self.init(red: r, green: g, blue: b, alpha: a)
    }
    /// init method from Gray value and alpha(default:1)
    public convenience init(gray: CGFloat, alpha: CGFloat = 1) {
        self.init(red: gray/255,
                  green: gray/255,
                  blue: gray/255,
                  alpha: alpha)
    }
    /// HSB/HSV 颜色的 Jobs 等价入口，参数范围与 UIKit 保持一致。
    public convenience init(h: CGFloat,
                            s: CGFloat,
                            b: CGFloat,
                            a: CGFloat = 1) {
        self.init(hue: h,
                  saturation: s,
                  brightness: b,
                  alpha: a)
    }
    /// 使用十六进制字符串初始化 UIColor
    ///
    /// 支持格式（不区分大小写）：
    /// - "FF0000" / "#FF0000" / "0xFF0000" / "##FF0000"
    ///
    /// 说明：
    /// - 仅支持 6 位 RGB（不支持 3 位简写、也不支持 8 位 ARGB/RGBA）
    /// - alpha 参数为透明度（0~1），默认 1.0（完全不透明）
    /// - 当输入长度不足 6 或解析失败时返回 nil
    ///
    /// - Parameters:
    ///   - hex: 十六进制颜色字符串
    ///   - alpha: 透明度（0~1）
    /// - Returns: 可选 UIColor，解析失败返回 nil
    public convenience init?(hex: String, alpha: CGFloat = 1.0) {
        var value = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if value.hasPrefix("0X") || value.hasPrefix("##") {
            value.removeFirst(2)
        } else if value.hasPrefix("#") {
            value.removeFirst()
        }
        guard value.utf8.count == 6,
              value.utf8.allSatisfy({ (48...57).contains($0) || (65...70).contains($0) }),
              let rgb = UInt32(value, radix: 16) else { return nil }
        self.init(r: CGFloat((rgb >> 16) & 255),
                  g: CGFloat((rgb >> 8) & 255),
                  b: CGFloat(rgb & 255),
                  a: alpha)
    }

    public convenience init(hex: UInt32) {
        let red = CGFloat((hex & 0xFF0000) >> 16) / 255.0
        let green = CGFloat((hex & 0x00FF00) >> 8) / 255.0
        let blue = CGFloat(hex & 0x0000FF) / 255.0
        self.init(red: red, green: green, blue: blue, alpha: 1.0)
    }

    public convenience init(hexInt: Int) {
        let components = (
            R: CGFloat((hexInt >> 16) & 0xff) / 255,
            G: CGFloat((hexInt >> 08) & 0xff) / 255,
            B: CGFloat((hexInt >> 00) & 0xff) / 255
        )
        self.init(red: components.R, green: components.G, blue: components.B, alpha: 1)
    }
    /// 使用 6 位十六进制字符串初始化 UIColor（便捷构造）
    ///
    /// 支持格式：
    /// - "RRGGBB"
    /// - "#RRGGBB"（会自动去掉 `#`）
    ///
    /// 说明：
    /// - 会自动去掉首尾空白与换行
    /// - 仅支持 6 位 RGB，不支持 3 位简写（如 #FFF）或 8 位带透明度（如 #AARRGGBB / #RRGGBBAA）
    /// - 解析失败（长度不为 6）返回 nil
    ///
    /// - Parameter hex: 十六进制颜色字符串
    public convenience init?(_ hex: String) {
        // 1）去掉首尾空白与换行
        var cString: String = hex.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        // 2）如果以 # 开头，则去掉 #
        if cString.hasPrefix("#") {
            let index = cString.index(after: cString.startIndex)
            cString = String(cString[index..<cString.endIndex])
        }
        // 3）仅接受 6 位 RGB（RRGGBB）
        if cString.count != 6 {
            return nil
        }
        // 4）按两位一组切割出 R/G/B 字符串
        var startIndex = cString.startIndex
        var endIndex = cString.index(after: startIndex)
        let rString = String(cString[startIndex...endIndex])
        startIndex = cString.index(after: endIndex)
        endIndex = cString.index(after: startIndex)
        let gString = String(cString[startIndex...endIndex])
        startIndex = cString.index(after: endIndex)
        endIndex = cString.index(after: startIndex)
        let bString = String(cString[startIndex...endIndex])
        // 5）十六进制转数值（00~FF -> 0~255）
        var r: CUnsignedInt = 0, g: CUnsignedInt = 0, b: CUnsignedInt = 0
        Scanner(string: rString).scanHexInt32(&r)
        Scanner(string: gString).scanHexInt32(&g)
        Scanner(string: bString).scanHexInt32(&b)
        // 6）归一化到 0~1 并初始化 UIColor（默认 alpha = 1）
        self.init(
            red: CGFloat(r) / 255.0,
            green: CGFloat(g) / 255.0,
            blue: CGFloat(b) / 255.0,
            alpha: 1.0
        )
    }
}

extension UIColor {
    /// UIColor 的红色分量（只读）
    ///
    /// 说明：
    /// - 仅对「可被分解为 RGB」的颜色有效（例如 sRGB / Display P3 等）
    /// - 对于 `patternColor`、部分 `UIColor` 动态色、或不在 RGB 色彩空间的颜色，`getRed` 可能失败
    /// - 失败时返回 0
    ///
    /// - Returns: 0 ~ 255 的整数值
    public var redComponent: Int {
        var r: CGFloat = 0
        guard getRed(&r, green: nil, blue: nil, alpha: nil) else { return 0 };return Int(r * 255)
    }
    /// UIColor 的绿色分量（只读）
    ///
    /// 说明：
    /// - 仅对「可被分解为 RGB」的颜色有效（例如 sRGB / Display P3 等）
    /// - 对于 `patternColor`、部分 `UIColor` 动态色、或不在 RGB 色彩空间的颜色，`getRed` 可能失败
    /// - 失败时返回 0
    ///
    /// - Returns: 0 ~ 255 的整数值
    public var greenComponent: Int {
        var g: CGFloat = 0
        guard getRed(nil, green: &g, blue: nil, alpha: nil) else { return 0 };return Int(g * 255)
    }

    /// UIColor 的蓝色分量（只读）
    ///
    /// 说明：
    /// - 仅对「可被分解为 RGB」的颜色有效（例如 sRGB / Display P3 等）
    /// - 对于 `patternColor`、部分 `UIColor` 动态色、或不在 RGB 色彩空间的颜色，`getRed` 可能失败
    /// - 失败时返回 0
    ///
    /// - Returns: 0 ~ 255 的整数值
    public var blueComponent: Int {
        var b: CGFloat = 0
        guard getRed(nil, green: nil, blue: &b, alpha: nil) else { return 0 };return Int(b * 255)
    }

    /// UIColor 的透明度 Alpha（只读）
    ///
    /// 说明：
    /// - 仅对「可被分解为 RGB」的颜色有效（例如 sRGB / Display P3 等）
    /// - 对于 `patternColor`、部分 `UIColor` 动态色、或不在 RGB 色彩空间的颜色，`getRed` 可能失败
    /// - 失败时返回 1（按完全不透明兜底）
    ///
    /// - Returns: 0 ~ 1 的浮点值
    public var alpha: CGFloat {
        var a: CGFloat = 0
        guard getRed(nil, green: nil, blue: nil, alpha: &a) else { return 1.0 };return a
    }
    /// 16 进制颜色
    class func hex(_ hex: UInt) -> UIColor {
        return hexAlpha(hex, alpha: 1.0)
    }
    /// 16 进制颜色 + 透明度
    public class func hexAlpha(_ hex: UInt, alpha: Float) -> UIColor {
        return UIColor(red: CGFloat((hex & 0xFF0000) >> 16) / 255.0,
                       green: CGFloat((hex & 0x00FF00) >> 8) / 255.0,
                       blue: CGFloat(hex & 0x0000FF) / 255.0,
                       alpha: CGFloat(alpha))
    }
    /// 获取RGB值
    public func getRGB() -> (CGFloat, CGFloat, CGFloat) {
        // 兼容入口：无法转换的 pattern 色返回零；需要区分失败时使用 jobsRGBComponents。
        return jobsRGBComponents() ?? (0, 0, 0)
    }
    /// 解析动态色后转换为 RGB；不可转换的颜色返回 nil。
    public func jobsRGBComponents(resolvingWith traits: UITraitCollection? = nil) -> (CGFloat, CGFloat, CGFloat)? {
        let color: UIColor
        if #available(iOS 13.0, tvOS 13.0, *), let traits {
            color = resolvedColor(with: traits)
        } else {
            color = self
        }
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        guard color.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else { return nil }
        return (red * 255, green * 255, blue * 255)
    }
    /// 计算两个 UIColor 在 RGB 三个通道上的差值（Delta）
    ///
    /// 返回值含义：
    /// - rDelta = firstColor.red   - secondColor.red
    /// - gDelta = firstColor.green - secondColor.green
    /// - bDelta = firstColor.blue  - secondColor.blue
    ///
    /// 常见用途：
    /// - 颜色渐变 / 过渡动画（根据差值逐步插值）
    /// - 判断两个颜色是否接近（对比 RGB 偏移量）
    /// - 动态主题、颜色校正计算
    ///
    /// - Parameters:
    ///   - firstColor: 基准颜色
    ///   - seccondColor: 对比颜色
    /// - Returns: (rDelta, gDelta, bDelta)，每个值可正可负
    public func getRGBDelta(_ firstColor: UIColor,
                            _ seccondColor: UIColor) -> (CGFloat, CGFloat, CGFloat) {
        let firstRGB = firstColor.getRGB()
        let secondRGB = seccondColor.getRGB()
        return (firstRGB.0 - secondRGB.0,
                firstRGB.1 - secondRGB.1,
                firstRGB.2 - secondRGB.2)
    }
    /// 用数值初始化颜色，便于生成设计图上标明的十六进制颜色
    public class func colorWith(hex: String, _ alpha: CGFloat = 1.0) -> UIColor {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6 else { return .red }
        var rgb: UInt64 = 0
        Scanner(string: s).scanHexInt64(&rgb)
        let r = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
        let g = CGFloat((rgb & 0x00FF00) >> 8)  / 255.0
        let b = CGFloat(rgb & 0x0000FF) / 255.0
        return UIColor(red: r, green: g, blue: b, alpha: alpha)
    }
}
// MARK: - 生成随机颜色
extension UIColor {
    public static func randomColor(_ alpha: CGFloat = 1.0) -> UIColor {
        return UIColor(red: CGFloat.random(in: 0...1),
                       green: CGFloat.random(in: 0...1),
                       blue: CGFloat.random(in: 0...1),
                       alpha: alpha)
    }

    public static var randomColor: UIColor {
        randomColor()
    }
}
// MARK: - UIColor：兼容封装（iOS 12- / iOS 13+ / iOS 18+）
extension UIColor {
    // MARK: - iOS 13+ dynamicProvider / resolvedColor
    /// iOS13+ 才有的 dynamicProvider：低版本直接返回 provider(UITraitCollection())
    /// - 外部不需要写 fallback
    public static func jobsDynamic(_ provider: @escaping (UITraitCollection) -> UIColor) -> UIColor {
        if #available(iOS 13.0, tvOS 13.0, *) {
            return UIColor(dynamicProvider: provider)
        } else {
            return provider(UITraitCollection())
        }
    }
    /// iOS13+ 才有的 resolvedColor：低版本直接返回自身
    public func jobsResolvedColor(with traitCollection: UITraitCollection) -> UIColor {
        if #available(iOS 13.0, tvOS 13.0, *) {
            return self.resolvedColor(with: traitCollection)
        } else {
            return self
        }
    }
    // MARK: - iOS 18+ Prominence（安全封装：低版本无感降级）
    /// iOS18+：withProminence；低版本：原样返回
    /// - 参数用 Any：避免低版本工程被 UIColor.Prominence 类型卡住（外界可传 prominence 或 nil）
    public func jobsWithProminence(_ prominence: Any?) -> UIColor {
        if #available(iOS 18.0, tvOS 18.0, *),
           let p = prominence as? UIColor.Prominence {
            return self.withProminence(p)
        } else {
            return self
        }
    }
    /// iOS18+：prominence；低版本：nil
    /// - 返回 Any?：避免低版本工程直接引用 UIColor.Prominence
    public var jobsProminence: Any? {
        if #available(iOS 18.0, tvOS 18.0, *) {
            return self.prominence
        } else {
            return nil
        }
    }
}

extension UIColor {
    /// 生成 1×1 纯色图（默认可拉伸，适合做 UIButton backgroundImage）
    public func byImage(size: CGSize = CGSize(width: 1, height: 1)) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        let img = renderer.image { ctx in
            self.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
        };return img.withRenderingMode(.alwaysOriginal) // 🔥关键：禁止 tint 渲染
    }
}
/* 设置多颜色样式 会用到
 //透明度；alpha 取值对照
 100% — FF
 95% — F2
 90% — E6
 85% — D9
 80% — CC
 75% — BF
 70% — B3
 65% — A6
 60% — 99
 55% — 8C
 50% — 80
 45% — 73
 40% — 66
 35% — 59
 30% — 4D
 25% — 40
 20% — 33
 15% — 26
 10% — 1A
 5% — 0D
 0% — 00
 ————————————————
 版权声明：本文为CSDN博主「刘淏卿」的原创文章，遵循CC 4.0 BY-SA版权协议，转载请附上原文出处链接及本声明。
 原文链接：https://blog.csdn.net/pinglingying/article/details/52403819
 辅助网站可通过16禁止颜色号看到颜色：https://www.colorhexa.com/83899b
 */
