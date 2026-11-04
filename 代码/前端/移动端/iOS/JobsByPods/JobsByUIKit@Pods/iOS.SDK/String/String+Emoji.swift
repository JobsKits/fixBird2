//
//  String+Emoji.swift
//  JobsByUIKit
//
//  Created by Jobs on 2026年5月13日，星期三.
//

import Foundation

/**
  用法示例
     let s = "Hi 👨‍👩‍👧‍👦! 🌈🇹🇭 ok?"
     print(s.containsEmoji)        // true
     print(s.emojis)               // ["👨‍👩‍👧‍👦", "🌈", "🇹🇭"]
     print(s.emojiCount)           // 3
     print(s.removingEmojis)       // "Hi !  ok?"
     print("😀😀".isAllEmoji)      // true
 */
extension String {
    // MARK: - Emoji Core
    /// 单个 Character 是否是 emoji（包含复合序列）
    public static func isEmoji(_ ch: Character) -> Bool {
        // 只要该 Character 的 unicodeScalars 里有一个 scalar 被判定为 emoji，并且不是纯组合符号
        ch.unicodeScalars.contains { $0.properties.isEmojiPresentation || $0.properties.isEmoji } &&
        !ch.unicodeScalars.allSatisfy { $0.properties.generalCategory == .nonspacingMark }
    }
    /// 是否包含至少一个 emoji
    public var containsEmoji: Bool {
        self.contains { Self.isEmoji($0) }
    }
    /// 是否全部都是 emoji（忽略空白与换行）
    public var isAllEmoji: Bool {
        let trimmed = self.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false };return trimmed.allSatisfy { Self.isEmoji($0) }
    }
    /// 提取字符串中的所有 emoji（按 Character 粒度）
    public var emojis: [String] {
        self.compactMap { Self.isEmoji($0) ? String($0) : nil }
    }
    /// emoji 个数（按 Character 粒度：复合 emoji 算 1 个）
    public var emojiCount: Int {
        self.reduce(into: 0) { $0 += Self.isEmoji($1) ? 1 : 0 }
    }
    /// 移除所有 emoji
    public var removingEmojis: String {
        String(self.filter { !Self.isEmoji($0) })
    }
    /// 只保留 emoji
    public var keepingEmojisOnly: String {
        String(self.filter { Self.isEmoji($0) })
    }
}
/**
  用法示例
     let s = "A ©️ ™️ 1️⃣ 😀 👨‍👩‍👧‍👦 🇹🇭 #️⃣"
     print(s.weakEmojis)    // ["©️", "™️", "1️⃣", "#️⃣"]
     print(s.strongEmojis)  // ["😀", "👨‍👩‍👧‍👦", "🇹🇭"]
 */
extension String {
    // ================================== Emoji Categories ==================================
    public enum EmojiStrength {
        case none
        case weak
        case strong
    }
    // ================================== Low-level helpers ==================================
    /// 判断某个 scalar 是否落在一些“典型 Strong emoji”区间（经验区间：表情、人物、手势、交通、杂项符号等）
    /// 说明：这是工程化的“Strong 倾向”加权，不等价于 Unicode 全量数据表，但对产品判定很实用。
    private static func isLikelyStrongEmojiScalar(_ s: UnicodeScalar) -> Bool {
        switch s.value {
        /// 大量 emoji 区（含扩展）
        case 0x1F300...0x1FAFF: return true
        /// Misc symbols（含部分 emoji，⚠️也含非emoji符号）
        case 0x2600...0x26FF:   return true
        /// Dingbats
        case 0x2700...0x27BF:   return true
        /// 未匹配已知分支时执行兜底处理
        default: return false
        }
    }

    private static let variationSelector16: UnicodeScalar = "\u{FE0F}" // VS16
    private static let zwj: UnicodeScalar = "\u{200D}"                 // ZWJ
    private static let keycap: UnicodeScalar = "\u{20E3}"              // keycap combining
    /// 判断是否为区域指示符（旗帜序列用）
    private static func isRegionalIndicator(_ s: UnicodeScalar) -> Bool {
        (0x1F1E6...0x1F1FF).contains(s.value)
    }
    // ================================== Core classification ==================================
    /// 对单个 Character 做分类：none / weak / strong
    public static func emojiStrength(of ch: Character) -> EmojiStrength {
        let scalars = Array(ch.unicodeScalars)
        if scalars.isEmpty { return .none }
        // 1) 必须至少是 Unicode 层面认定的 emoji（含序列）
        let hasEmojiProperty = scalars.contains { $0.properties.isEmoji }
        if !hasEmojiProperty { return .none }
        // 2) Keycap 序列：1️⃣ #️⃣ *️⃣ → 归 weak（产品感知一般也更像“符号”）
        if scalars.contains(keycap) { return .weak }
        // 3) 明确含 VS16：©️ ™️ ®️ 等 → weak
        if scalars.contains(variationSelector16) {
            // 如果它同时是明显的“表情类”且默认就是 emoji 展示，也可以判 strong，
            // 但通常 VS16 出现更多是“弱符号”场景，所以默认 weak。
            // 你要更激进可在这里加条件把某些变强。
            return .weak
        }
        // 4) ZWJ 序列：👨‍👩‍👧‍👦 等
        // 这类通常是“强表情/人物”，但也可能组合出符号风格。
        // 这里按“更符合用户预期” -> strong
        if scalars.contains(zwj) { return .strong }
        // 5) 旗帜：由两个 Regional Indicator 组成，通常是 strong（用户感知也是彩色旗帜）
        if scalars.count == 2, scalars.allSatisfy({ isRegionalIndicator($0) }) {
            return .strong
        }
        // 6) 默认 emoji 展示：强
        if scalars.contains(where: { $0.properties.isEmojiPresentation }) {
            return .strong
        }
        // 7) 兜底：如果是 emoji 但不默认 presentation，则一般当 weak
        //    例如某些符号类可能靠字体渲染成 emoji 风格（但不保证）
        //    如果它落在“强 emoji 区间”，可提升为 strong
        if scalars.contains(where: { isLikelyStrongEmojiScalar($0) }) {
            return .strong
        };return .weak
    }
    // ================================== Convenience APIs (String-level) ==================================
    /// 是否包含 strong emoji
    public var containsStrongEmoji: Bool {
        self.contains { Self.emojiStrength(of: $0) == .strong }
    }
    /// 是否包含 weak emoji
    public var containsWeakEmoji: Bool {
        self.contains { Self.emojiStrength(of: $0) == .weak }
    }
    /// 提取 strong emoji
    public var strongEmojis: [String] {
        self.compactMap { Self.emojiStrength(of: $0) == .strong ? String($0) : nil }
    }
    /// 提取 weak emoji
    public var weakEmojis: [String] {
        self.compactMap { Self.emojiStrength(of: $0) == .weak ? String($0) : nil }
    }
    /// 过滤：只保留 strong emoji
    public var keepingStrongEmojisOnly: String {
        String(self.filter { Self.emojiStrength(of: $0) == .strong })
    }
    /// 过滤：移除所有 weak emoji（保留 strong + 普通文本）
    public var removingWeakEmojis: String {
        String(self.filter { Self.emojiStrength(of: $0) != .weak })
    }
}
