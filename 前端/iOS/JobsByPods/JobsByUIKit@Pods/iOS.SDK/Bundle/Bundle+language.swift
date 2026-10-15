//
//  Bundle+language.swift
//  JobsByUIKit
//
//  Created by Jobs on 2026年5月13日，星期三.
//

#if os(OSX)
import AppKit
#elseif os(iOS) || os(tvOS)
import UIKit
#endif

import ObjectiveC
import Jobsl10n

private var _jobs_swizzled: Bool = false
extension Bundle {
    static func jobs_enableLanguageHook() {
        guard !_jobs_swizzled,
              let ori = class_getInstanceMethod(Bundle.self, #selector(localizedString(forKey:value:table:))),
              let new = class_getInstanceMethod(Bundle.self, #selector(jobs_localizedString(forKey:value:table:))) else { return }
        method_exchangeImplementations(ori, new)
        _jobs_swizzled = true
    }

    @objc private func jobs_localizedString(forKey key: String,
                                            value: String?,
                                            table tableName: String?) -> String {
        // 只改 main.bundle，避免递归和第三方 bundle 受影响
        if self == .main {
            let b = LanguageManager.shared.localizedBundle
            return b.jobs_localizedString(forKey: key,
                                          value: value,
                                          table: tableName)
        };return self.jobs_localizedString(forKey: key,
                                           value: value,
                                           table: tableName)
    }
}

extension Bundle {
    // MARK: - 支持语言类型
     public enum AppLang: Equatable, Hashable {
        case vietnamese          /// 越南语 vi
        case thai                /// 泰语 th
        case turkish             /// 土耳其语 tr
        case arabic              /// 阿拉伯语 ar
        case chineseSimplified   /// 简体中文 zh-Hans / zh-CN / zh-SG
        case chineseTraditional  /// 繁体中文 zh-Hant / zh-TW / zh-HK / zh-MO
        case filipino            /// 菲律宾语 fil / tl
        case japanese            /// 日语 ja
        case portuguese          /// 葡萄牙语 pt
        case spanish             /// 西班牙语 es
        case other
    }

    public static func lang() -> AppLang {
        let id = Locale.preferredLanguages.first ?? Locale.current.identifier
        return mapLanguageIdentifier(id)
    }

    private static func mapLanguageIdentifier(_ identifier: String) -> AppLang {
        let lower = identifier.lowercased()
        // 先处理中文（因为 zh 的变体很多）
        if lower.hasPrefix("zh") {
            // 1) 明确脚本标记优先
            if lower.contains("hans") { return .chineseSimplified }
            if lower.contains("hant") { return .chineseTraditional }
            // 2) 没有 Hans/Hant 时，用地区推断
            // zh-cn / zh-sg => 简体
            if lower.contains("-cn") || lower.contains("-sg") { return .chineseSimplified }
            // zh-tw / zh-hk / zh-mo => 繁体
            if lower.contains("-tw") || lower.contains("-hk") || lower.contains("-mo") {
                return .chineseTraditional
            }
            // 3) 兜底：绝大多数情况下更符合简体（你也可以改成 other）
            return .chineseSimplified
        }
        // 其它语言用主语言码匹配
        let code = lower.split(separator: "-").first.map(String.init) ?? lower
        switch code {
        /// 处理 "vi" 分支
        case "vi": return .vietnamese
        /// 处理 "th" 分支
        case "th": return .thai
        /// 处理 "tr" 分支
        case "tr": return .turkish
        /// 处理 "ar" 分支
        case "ar": return .arabic
        /// 合并处理 "fil"、"tl" 分支
        case "fil", "tl": return .filipino
        /// 处理 "ja" 分支
        case "ja": return .japanese
        /// 处理 "pt" 分支
        case "pt": return .portuguese
        /// 处理 "es" 分支
        case "es": return .spanish
        /// 未匹配已知分支时执行兜底处理
        default:
            return .other
        }
    }
}
