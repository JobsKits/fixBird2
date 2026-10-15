//
//  String+取色.swift
//  JobsByUIKit
//
//  Created by Jobs on 2026年5月13日，星期三.
//

#if os(OSX)
import AppKit
#elseif os(iOS) || os(tvOS)
import UIKit
#endif

import JobsSwiftBaseDefines

// MARK: - 字符串取颜色@校验成功后取色
/**
 "#353a3e".cor          // OK → 正常色
 "353a3e".cor           // OK
 "0x353a3e".cor         // OK
 "#FFF".cor             // OK → 展开成 #FFFFFF
 "80FF0000".cor         // OK → alpha=0x80, red
 "乱七八糟".cor         // ❌ → 直接红色

 "80FF0000".cor(alpha: 1) // alpha 走字符串里的 0x80，而不是你传的 1
 "垃圾".cor(JobsCor.black) // 非法 → black
 */
extension String {
    /// 支持格式：
    /// "#RRGGBB" / "RRGGBB" / "0xRRGGBB"
    /// "#RGB"   / "RGB"
    /// "#AARRGGBB" / "AARRGGBB"
    /// 是否是合法的 hex 颜色字符串（只判断上面支持的几种格式）
    public var isValidHexColor: Bool {
        jobsParseHexColor(self) != nil
    }
    /// 直接从字符串拿 UIColor
    /// - 若格式非法，直接返回红色（作为错误兜底）
    public var cor: UIColor {
        guard let (rgb, alpha) = jobsParseHexColor(self),
              let color = UIColor(hexString: rgb, alpha: alpha) else {
            return JobsCor.red
        };return color
    }
    /// 带 alpha 的版本
    /// - 若格式非法，返回对应 alpha 的红色
    /// - 若字符串本身带 AARRGGBB，则优先用字符串里的 alpha
    public func cor(alpha explicitAlpha: CGFloat) -> UIColor {
        let defaultAlpha = explicitAlpha
        guard let (rgb, parsedAlpha) = jobsParseHexColor(self, defaultAlpha: defaultAlpha),
              let color = UIColor(hexString: rgb, alpha: parsedAlpha) else {
            return JobsCor.red.withAlphaComponent(explicitAlpha)
        };return color
    }
    /// 指定兜底颜色版本（你要自定义 fallback 就用这个）
    public func cor(_ fallback: UIColor) -> UIColor {
        guard let (rgb, alpha) = jobsParseHexColor(self),
              let color = UIColor(hexString: rgb, alpha: alpha) else {
            return fallback
        };return color
    }
}
// MARK: - 字符串校验规定格式@取色
fileprivate func jobsParseHexColor(_ raw: String,
                                   defaultAlpha: CGFloat = 1.0) -> (rgbHex: String, alpha: CGFloat)? {
    var hex = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                 .lowercased()
    // 前缀处理
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
    // 只接受 6 / 8 位
    guard hex.count == 6 || hex.count == 8 else { return nil }
    // 只允许 0-9a-f
    let validChars = CharacterSet(charactersIn: "0123456789abcdef")
    guard hex.unicodeScalars.allSatisfy({ validChars.contains($0) }) else {
        return nil
    }

    if hex.count == 6 {
        // 纯 RRGGBB，用外面给的 defaultAlpha
        return (rgbHex: hex, alpha: defaultAlpha)
    } else {
        // AARRGGBB：前 2 位是 alpha，后 6 位是 RRGGBB
        let aStr = String(hex.prefix(2))
        let rgb  = String(hex.suffix(6))
        guard let aInt = UInt8(aStr, radix: 16) else { return nil }
        let alpha = CGFloat(aInt) / 255.0
        return (rgbHex: rgb, alpha: alpha)
    }
}
