//
//  LanguageManager.swift
//  Jobsl10n
//
//  Created by Jobs on 2026年5月13日，星期三.
//

import Foundation

public final class LanguageManager {
    public static let shared = LanguageManager()
    private let lock = NSLock()
    private var languageCode: String
    private let defaults: UserDefaults
    private let preferredLanguages: () -> [String]
    private let resourceBundle: Bundle

    public var currentLanguageCode: String {
        lock.lock()
        defer {
            lock.unlock()
        }
        return languageCode
    }

    /// 地区语言先找完整码，再找基础码；缺失资源回退主 Bundle，override 会清除关联。
    public var localizedBundle: Bundle {
        Self.bundle(for: currentLanguageCode, in: resourceBundle)
    }

    public init(
        userDefaults: UserDefaults = .standard,
        resourceBundle: Bundle = .main,
        preferredLanguages: @escaping () -> [String] = { Locale.preferredLanguages }
    ) {
        self.defaults = userDefaults
        self.resourceBundle = resourceBundle
        self.preferredLanguages = preferredLanguages
        if userDefaults.string(forKey: languageModeKey) == "custom",
           let code = userDefaults.string(forKey: languageCodeKey), !code.isEmpty {
            languageCode = code.normalizedLanguageCode
        } else {
            languageCode = (preferredLanguages().first ?? "en").normalizedLanguageCode
        }
    }

    private static func bundle(for code: String, in resourceBundle: Bundle) -> Bundle {
        let base = code.split(separator: "-").first.map(String.init) ?? code
        for candidate in [code, base] {
            if let path = resourceBundle.path(forResource: candidate, ofType: "lproj"),
               let bundle = Bundle(path: path) {
                return bundle
            }
        }
        return resourceBundle
    }

    public func switchTo(_ code: String) {
        lock.lock()
        languageCode = code.normalizedLanguageCode
        defaults.set("custom", forKey: languageModeKey)
        defaults.set(languageCode, forKey: languageCodeKey)
        Bundle.setLanguageBundle(Self.bundle(for: languageCode, in: resourceBundle))
        lock.unlock()
        notifyLanguageChanged()
    }

    public func followSystemLanguage() {
        // 注入的 provider 可读取当前状态，调用时不持有状态锁。
        let systemCode = (preferredLanguages().first ?? "en").normalizedLanguageCode
        lock.lock()
        defaults.set("system", forKey: languageModeKey)
        defaults.removeObject(forKey: languageCodeKey)
        languageCode = systemCode
        // 系统模式始终清除定制 Bundle，即使当前语言码相同也执行。
        Bundle.clearLanguageBundle()
        lock.unlock()
        notifyLanguageChanged()
    }

    private func notifyLanguageChanged() {
        if Thread.isMainThread {
            NotificationCenter.default.post(name: .JobsLanguageDidChange, object: nil)
        } else {
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .JobsLanguageDidChange, object: nil)
            }
        }
    }
}
