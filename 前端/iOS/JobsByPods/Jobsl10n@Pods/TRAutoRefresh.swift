//
//  TRAutoRefresh.swift
//  Jobsl10n
//
//  Created by Jobs on 2026年5月13日，星期三.
//

#if os(OSX)
import AppKit
#elseif os(iOS) || os(tvOS)
import UIKit
#endif

//
//  语言切换自动刷新引擎（无兼容分支）
//  依赖：Notification.Name.JobsLanguageDidChange、TRLang.bundleProvider()
//
// MARK: - Core
public enum TRAutoRefresh {
    // MARK: - 线程本地标记（.tr 内部调用）
    public enum Marker {
        private static let threadKey = "jobs.tr.marker.key"
        /// .tr 调用尾部调用：把 key/table 放到当前线程词典里，然后原样返回翻译后的字符串
        public static func pack(
            translated: String,
            key: String,
            table: String?
        ) -> String {
            Thread.current.threadDictionary[threadKey] = Info(key: key, table: table, translated: translated)
            return translated
        }
        /// 由控件入口（UILabel/UIButton 等）“消费”最近一次的 Key；消费后即清空
        static func consume(matching translated: String? = nil) -> Info? {
            let dict = Thread.current.threadDictionary
            guard let info = dict[threadKey] as? Info else { return nil }
            dict.removeObject(forKey: threadKey)
            guard translated == nil || translated == info.translated else {
                return nil
            }
            return info
        }
        /// 注意：ThreadDictionary 存 Swift struct 会走桥接（_SwiftValue），在 Release -O 下更容易触发编译器/优化器的角落问题
        /// 这里改为 NSObject 子类，避免桥接与类型擦除带来的不稳定因素
        public final class Info: NSObject {
            public let key: String
            public let table: String?
            public let translated: String?
            public init(key: String, table: String?, translated: String? = nil) {
                self.key = key
                self.table = table
                self.translated = translated
            }
        }
    }
    // MARK: - 注册表
    private final class Entry {
        weak var target: AnyObject?
        let key: String
        let table: String?
        let slot: String
        let apply: (AnyObject, String) -> Void
        init(
            target: AnyObject,
            key: String,
            table: String?,
            slot: String,
            apply: @escaping (AnyObject, String) -> Void
        ) {
            self.target = target
            self.key = key
            self.table = table
            self.slot = slot
            self.apply = apply
        }
    }

    private static var entries: [Entry] = []
    private static let lock = NSLock()
    private static var isObserving = false
    private static var token: NSObjectProtocol?
    /// 调用方持锁；保留被移除项及临时提升的弱目标，避免析构重入锁。
    private static func removeEntriesLocked(
        where predicate: (Entry, AnyObject?) -> Bool
    ) -> ([Entry], [AnyObject]) {
        let previous = entries
        var targets: [AnyObject] = []
        entries.removeAll { entry in
            let target = entry.target
            if let target {
                targets.append(target)
            }
            return predicate(entry, target)
        }
        return (previous, targets)
    }
    // MARK: - 注册与刷新
    private static func ensureObserver() {
        guard !isObserving else { return }
        isObserving = true
        token = NotificationCenter.default.addObserver(
            forName: .JobsLanguageDidChange,
            object: nil,
            queue: .main
        ) { _ in
            TRAutoRefresh.refreshAll()
        }
    }
    /// 把任意目标对象与 key 绑定；语言变化时会把 key.tr 再次设置回去
    public static func register<T: AnyObject>(
        _ target: T,
        key: String,
        table: String? = nil,
        slot: String = "default",
        apply: @escaping (T, String) -> Void
    ) {
        let entry = Entry(
            target: target,
            key: key,
            table: table,
            slot: slot
        ) { obj, text in
            if let t = obj as? T {
                apply(t, text)
            }
        }
        lock.lock()
        ensureObserver()
        let retired = removeEntriesLocked { entry, existing in
            existing == nil || (existing === target && entry.slot == slot)
        }
        entries.append(entry)
        lock.unlock()
        withExtendedLifetime(retired) {}
    }
    /// 主线程刷新全部已注册控件
    private static var _isRefreshing = false
    public static func refreshAll() {
        guard Thread.isMainThread else {
            DispatchQueue.main.async {
                refreshAll()
            }
            return
        }
        guard !_isRefreshing else { return }     // 防 re-entrancy
        _isRefreshing = true
        defer { _isRefreshing = false }
        lock.lock()
        let retired = removeEntriesLocked { _, target in target == nil }
        let snapshot = entries
        lock.unlock()
        withExtendedLifetime(retired) {}
        let bundle = TRLang.bundle()
        for e in snapshot {
            lock.lock()
            let isCurrent = entries.contains { $0 === e }
            lock.unlock()
            guard isCurrent, let obj = e.target else {
                continue
            }
            let translated = NSLocalizedString(
                e.key,
                tableName: e.table,
                bundle: bundle,
                value: e.key,
                comment: ""
            )
            e.apply(obj, translated)
        }
    }

    public static func unbind(_ target: AnyObject, slot: String? = nil) {
        lock.lock()
        let retired = removeEntriesLocked { entry, existing in
            existing == nil || (existing === target && (slot == nil || entry.slot == slot))
        }
        lock.unlock()
        withExtendedLifetime(retired) {}
    }

    public static var bindingCount: Int {
        lock.lock()
        let retired = removeEntriesLocked { _, target in target == nil }
        let count = entries.count
        lock.unlock()
        withExtendedLifetime(retired) {}
        return count
    }
}
// MARK: - One universal API: TRBind
/// 你的“最小开销做最大事”落地：
/// - 任何对象/任何属性，只要能在语言变化后重新 apply，就能自动刷新
public enum TRBind {
    /// 通用绑定：消费最近一次 ".tr" 的 marker，先 apply 一次，再注册语言变化自动 apply
    public static func bind<T: AnyObject>(
        _ target: T,
        translated: String,
        slot: String = "default",
        apply: @escaping (T, String) -> Void
    ) {
        let info = TRAutoRefresh.Marker.consume(matching: translated)
        guard let info else {
            TRAutoRefresh.unbind(target, slot: slot)
            applyOnMain(target, text: translated, apply: apply)
            return
        }
        TRAutoRefresh.register(
            target,
            key: info.key,
            table: info.table,
            slot: slot
        ) { t, text in
            apply(t, text)
        }
        applyOnMain(target, text: translated, apply: apply)
    }

    /// 显式 key 绑定不依赖最近一次 .tr 的线程标记。
    public static func bind<T: AnyObject>(
        _ target: T,
        key: String,
        table: String? = nil,
        slot: String = "default",
        apply: @escaping (T, String) -> Void
    ) {
        _ = TRAutoRefresh.Marker.consume()
        TRAutoRefresh.register(target, key: key, table: table, slot: slot, apply: apply)
        let translated = TRLang.bundle().localizedString(forKey: key, value: key, table: table)
        applyOnMain(target, text: translated, apply: apply)
    }

    private static func applyOnMain<T: AnyObject>(_ target: T, text: String, apply: @escaping (T, String) -> Void) {
        if Thread.isMainThread {
            apply(target, text)
        } else {
            DispatchQueue.main.async {
                apply(target, text)
            }
        }
    }
    /// 非自动刷新的场景（富文本等）：清 marker，避免串台
    public static func consumeMarkerIfNeeded() {
        _ = TRAutoRefresh.Marker.consume()
    }
}
