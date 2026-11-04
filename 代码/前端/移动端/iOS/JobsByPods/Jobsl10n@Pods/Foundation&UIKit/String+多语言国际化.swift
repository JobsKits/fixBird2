//
//  String+多语言国际化.swift
//  Jobsl10n
//
//  Created by Jobs on 2026年5月13日，星期三.
//

import Foundation

extension String {
    /// 当前字符串是否被目标字符串以本地化、忽略大小写方式包含
    public func inStr(_ data: String?) -> Bool {
        guard let data = data else { return false };return data.localizedCaseInsensitiveContains(self)
    }

    // 项目实际存在的 lproj（大小写按文件夹名写）
    private static let jobsSupportedLproj: [String] = [
        "en", "en-PH",
        "tl",
        "zh-Hans", "zh-Hant",
        "vi", "th", "tr", "ja",
        "pt-BR", "es-MX",
        "ar", "ar-EG"
    ]
    /// 将系统 / 外部语言码统一归一化为 App 内部支持的语言码（= lproj 文件夹名）
    var normalizedLanguageCode: String {
        return Self.normalizeToSupportedLproj(self,
                                              supported: Self.jobsSupportedLproj,
                                              fallback: "en")
    }

    private static func normalizeToSupportedLproj(_ raw: String,
                                                  supported: [String],
                                                  fallback: String) -> String {
        // 做一个“不区分大小写”的映射：lowercased -> 原始值（用于返回正确大小写的 lproj 名）
        let map: [String: String] = Dictionary(uniqueKeysWithValues: supported.map { ($0.lowercased(), $0) })
        // 统一分隔符：en_US -> en-US
        let tag = raw.replacingOccurrences(of: "_", with: "-").trimmingCharacters(in: .whitespacesAndNewlines)
        if tag.isEmpty { return fallback }
        // 拆 BCP-47
        let parts = tag.split(separator: "-").map(String.init)
        let language = (parts.first ?? "").lowercased()
        var script: String? = nil   // Hans / Hant
        var region: String? = nil   // PH / BR / MX / EG ...
        // 简单解析：第二段如果长度=4 当 script；长度=2/3 当 region
        if parts.count >= 2 {
            let p1 = parts[1]
            if p1.count == 4 { script = p1.capitalized }
            else if p1.count == 2 || p1.count == 3 { region = p1.uppercased() }
        }
        // 第三段可能是 region（当第二段是 script 时）
        if parts.count >= 3, region == nil {
            let p2 = parts[2]
            if p2.count == 2 || p2.count == 3 { region = p2.uppercased() }
        }
        // 1) 先尝试“完整匹配”：language-script-region / language-region / language-script
        func pick(_ candidate: String) -> String? { map[candidate.lowercased()] }
        if let s = script, let r = region, let hit = pick("\(language)-\(s)-\(r)") { return hit }
        if let r = region, let hit = pick("\(language)-\(r)") { return hit }
        if let s = script, let hit = pick("\(language)-\(s)") { return hit }
        // 2) 语言定制规则（你提到的目标语言）
        switch language {
        /// 处理 "zh" 分支
        case "zh":
            // 没给 script 时按 region 推断
            let preferHansRegions: Set<String> = ["CN", "SG", "MY"]
            let preferHantRegions: Set<String> = ["TW", "HK", "MO"]
            if let s = script?.lowercased() {
                if s == "hans", let hit = pick("zh-Hans") { return hit }
                if s == "hant", let hit = pick("zh-Hant") { return hit }
            }
            if let r = region {
                if preferHansRegions.contains(r), let hit = pick("zh-Hans") { return hit }
                if preferHantRegions.contains(r), let hit = pick("zh-Hant") { return hit }
            };return pick("zh-Hans") ?? fallback// 默认给简体（按你项目常见诉求）
        /// 处理 "en" 分支
        case "en":
            if region == "PH", let hit = pick("en-PH") { return hit };return pick("en") ?? fallback
        /// 合并处理 "fil"、"tl" 分支
        case "fil", "tl":
            return pick("tl") ?? fallback
        /// 处理 "ar" 分支
        case "ar":
            if region == "EG", let hit = pick("ar-EG") { return hit };return pick("ar") ?? fallback
        /// 处理 "pt" 分支
        case "pt":
            if region == "BR", let hit = pick("pt-BR") { return hit };return pick("pt") ?? fallback
        /// 处理 "es" 分支
        case "es":
            if region == "MX", let hit = pick("es-MX") { return hit };return pick("es") ?? fallback
        /// 未匹配已知分支时执行兜底处理
        default:
            break
        }
        // 3) 最后：只按 language 匹配（vi/th/tr/ja…）
        if let hit = pick(language) { return hit };return fallback
    }
}
