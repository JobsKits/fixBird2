//
//  Decimal.swift
//  JobsSwiftFoundation
//
//  Created by Jobs on 2026年5月13日，星期三.
//

#if os(OSX)
import AppKit
#elseif os(iOS) || os(tvOS)
import UIKit
#endif

import JobsByUIKit
import JobsSwiftDSL

/*
     let a = Decimal(string: "1.005")!
     print(a.rounded(scale: 2, mode: .plain))       // 1.01  四舍五入
     print(a.rounded(scale: 2, mode: .bankers))     // 1.00  银行家舍入

     let b = Decimal(string: "-12.345")!
     print(b.rounded(scale: 2, mode: .towardZero))  // -12.34
     print(b.rounded(scale: 2, mode: .awayFromZero))// -12.35

     // 向十位取整：scale 可为负
     let c = Decimal(string: "1234.56")!
     print(c.rounded(scale: -1, mode: .plain))      // 1230

     // 展示（千分位 + 固定小数位）
     print(c.formatted(scale: 2, mode: .bankers))   // 1,234.56（随 locale 变化）
 */
/// 结合 SafeCodable 使用更佳
extension Decimal {
    /// 统一的舍入规则（覆盖业务常见口径）
    public enum RoundingRule {
        /// 四舍五入（.plain）
        case plain
        /// 向下取整（绝对值方向变小，.down）
        case down
        /// 向上取整（绝对值方向变大，.up）
        case up
        /// 银行家舍入（.bankers）：减少系统性偏差：大量数据求和/汇总时，比“逢 .5 一律进位（四舍五入）”更中性，累积误差更小——金融/报表爱用它。
        case bankers
        /// 趋近零（正数向下、负数向上）
        case towardZero
        /// 远离零（正数向上、负数向下）
        case awayFromZero
    }
    /// 非破坏性：返回舍入后的新值
    public func rounded(scale: Int, mode: RoundingRule = .bankers) -> Decimal {
        var value = self
        var result = Decimal()
        NSDecimalRound(&result, &value, scale, Self._nsMode(for: value, rule: mode))
        return result
    }
    /// 原地舍入
    public mutating func round(scale: Int, mode: RoundingRule = .bankers) {
        var tmp = self
        NSDecimalRound(&self, &tmp, scale, Self._nsMode(for: tmp, rule: mode))
    }
    /// 字符串展示：先按规则舍入，再格式化
    public func formatted(scale: Int,
                          mode: RoundingRule = .bankers,
                          usesGroupingSeparator: Bool = true,
                          locale: Locale = .current) -> String {
        let rounded = self.rounded(scale: scale, mode: mode)
        // 直接用 NSDecimalNumber 包装以避免 Double 精度丢失
        return NumberFormatter.jobsMake { _ in }
            .byLocale(locale)
            .byNumberStyle(.decimal)
            .byUsesGroupingSeparator(usesGroupingSeparator)
            .byMinimumFractionDigits(max(0, scale))
            .byMaximumFractionDigits(max(0, scale)).string(from: rounded as NSDecimalNumber) ?? "\(rounded)"
    }
    // MARK: - 内部：把自定义规则映射到 NSDecimalNumber.RoundingMode
    private static func _nsMode(for x: Decimal, rule: RoundingRule) -> NSDecimalNumber.RoundingMode {
        switch rule {
        /// 处理 .plain 分支
        case .plain:        return .plain
        /// 处理 .down 分支
        case .down:         return .down
        /// 处理 .up 分支
        case .up:           return .up
        /// 处理 .bankers 分支
        case .bankers:      return .bankers
        /// 处理 .towardZero 分支
        case .towardZero:
            // 正数向下，负数向上 -> 趋近零
            return (x >= 0) ? .down : .up
        /// 处理 .awayFromZero 分支
        case .awayFromZero:
            // 正数向上，负数向下 -> 远离零
            return (x >= 0) ? .up : .down
        }
    }
}
// 便捷比较：Decimal 默认可用 < >，这里补个 >= 以便内部判断
extension Decimal {
    public static func >= (lhs: Decimal, rhs: Decimal) -> Bool { (lhs as NSDecimalNumber).compare(rhs as NSDecimalNumber) != .orderedAscending }
}
