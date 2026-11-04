//
//  TRLang.swift
//  Jobsl10n
//
//  Created by Jobs on 2026年5月13日，星期三.
//

import Foundation

// MARK: - 统一语言桥（无兼容分支，仅此一套）
public enum TRLang {
    private static let lock = NSLock()
    private static var bundleStorage: () -> Bundle = { .main }
    private static var localeStorage: () -> String = { Locale.current.identifier }

    /// provider 的存取同步；自定义 closure 的内部线程合同由注入方负责。
    public static var bundleProvider: () -> Bundle {
        get {
            lock.lock()
            defer { lock.unlock() }
            return bundleStorage
        }
        set {
            lock.lock()
            let previous = bundleStorage
            bundleStorage = newValue
            lock.unlock()
            withExtendedLifetime(previous) {}
        }
    }

    public static var localeCodeProvider: () -> String {
        get {
            lock.lock()
            defer { lock.unlock() }
            return localeStorage
        }
        set {
            lock.lock()
            let previous = localeStorage
            localeStorage = newValue
            lock.unlock()
            withExtendedLifetime(previous) {}
        }
    }

    public static func bundle() -> Bundle {
        bundleProvider()
    }
}
