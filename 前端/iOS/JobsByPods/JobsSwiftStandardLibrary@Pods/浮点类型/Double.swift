//
//  Double.swift
//  JobsSwiftStandardLibrary
//
//  Created by Jobs on 2026年5月13日，星期三.
//

#if os(OSX)
import AppKit
#elseif os(iOS) || os(tvOS)
import UIKit
#endif

/// 定义于 Swift 标准库

public extension Double {
    // MARK: - 把 Double 转换成 金额字符串，始终保留 两位小数
    public func toAmount() -> String? {
        let format = NumberFormatter.init()
        format.numberStyle = .none
        //format.numberStyle = .currencyPlural
        format.locale = Locale(identifier: "zh_CN")
        format.maximumFractionDigits = 2
        format.minimumFractionDigits = 2
        let str0 = format.string(from: NSDecimalNumber(value: self)) ?? "0.00"
        return str0
    }

    /// 保留两位小数（截断，不四舍五入）
    func truncate(to decimals: Int) -> Double {
        let multiplier = pow(10.0, Double(decimals))
        return Double(Int(self * multiplier)) / multiplier
    }
}
// MARK: 获取屏幕相对宽高
public extension Double {
    static let screenWidth: CGFloat = min(UIScreen.main.bounds.size.width, UIScreen.main.bounds.size.height)
    static let screenHeight: CGFloat = max(UIScreen.main.bounds.size.width, UIScreen.main.bounds.size.height)

    private var py_scaleW: CGFloat { Self.screenWidth / 375 }
    private var py_scaleH: CGFloat { Self.screenHeight / 812 }

    var w: CGFloat { CGFloat(self) * py_scaleW }
    var h: CGFloat { CGFloat(self) * py_scaleH }
}
