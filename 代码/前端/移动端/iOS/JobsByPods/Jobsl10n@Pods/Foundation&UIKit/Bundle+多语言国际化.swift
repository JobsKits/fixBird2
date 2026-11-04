//
//  Bundle+多语言国际化.swift
//  Jobsl10n
//
//  Created by Jobs on 2026年5月13日，星期三.
//

import Foundation
import ObjectiveC

// 用于把 Bundle.main 的 localizedString 重定向到我们指定的 language bundle
private var jobs_languageBundleKey: UInt8 = 0
private let jobs_languageOverrideLock = NSLock()
// 继承 Bundle 的并发合同；新增关联读取为 atomic，且永不关联自身。
private final class JobsLanguageOverrideBundle: Bundle, @unchecked Sendable {
    override func localizedString(forKey key: String,
                                  value: String?,
                                  table tableName: String?) -> String {
        if let b = objc_getAssociatedObject(self, &jobs_languageBundleKey) as? Bundle, b !== self {
            return b.localizedString(forKey: key,
                                     value: value,
                                     table: tableName)
        };return super.localizedString(forKey: key,
                                       value: value,
                                       table: tableName)
    }
}

extension Bundle {
    /// 只需要调用一次：把 Bundle.main 的类替换成可 override localizedString 的子类
    public static func enableLanguageOverride() {
        jobs_languageOverrideLock.lock()
        defer { jobs_languageOverrideLock.unlock() }
        if !(Bundle.main is JobsLanguageOverrideBundle) {
            object_setClass(Bundle.main, JobsLanguageOverrideBundle.self)
        }
    }
    /// 设置当前要使用的语言 bundle（例如 vi.lproj 对应的 Bundle）
    public static func setLanguageBundle(_ bundle: Bundle) {
        objc_setAssociatedObject(Bundle.main,
                                 &jobs_languageBundleKey,
                                 bundle === Bundle.main ? nil : bundle,
                                 .OBJC_ASSOCIATION_RETAIN)
    }
    public static func clearLanguageBundle() {
        objc_setAssociatedObject(Bundle.main, &jobs_languageBundleKey, nil, .OBJC_ASSOCIATION_RETAIN)
    }

}
