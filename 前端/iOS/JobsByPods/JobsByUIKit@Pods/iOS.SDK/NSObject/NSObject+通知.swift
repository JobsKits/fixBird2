//
//  NSObject+通知.swift
//  JobsByUIKit
//
//  Created by Jobs on 2026年5月13日，星期三.
//

import Foundation
import ObjectiveC
import JobsSwiftBlock
import JobsSwiftBaseDefines

// MARK: - 使用方式（建议看完）
/// =============================== 发通知（对齐系统参数） ===============================
///
/// ✅ 本文件只做两件事：
/// 1) 发通知：对齐系统 NotificationCenter.post(name:object:userInfo:)
/// 2) 收通知：提供闭包版监听，并自动持有 token（挂在 owner/self 上）
///
/// 1) 只发通知名：
///     self.post("RefreshUI")
///     NSObject.post("RefreshUI")
///
/// 2) 发 object：
///     self.post("IFSpecifiedTab", object: 3)
///     NSObject.post("IFSpecifiedTab", object: 3)
///
/// 3) 发 userInfo：
///     self.post("LoginStateChanged", userInfo: ["id": 1])
///     NSObject.post("LoginStateChanged", userInfo: ["id": 1])
///
/// 4) 同时发 object + userInfo：
///     self.post("SomethingChanged", object: model, userInfo: ["from": "mine"])
///
/// =============================== 收通知（闭包版，推荐） ===============================
/// ✅ 自动持有 token（挂在 owner/self 上），无需手动保存；deinit 里 remove 一下就行
///
/// 1) 最常用：只关心 object（Any?）
///     self.onObject("IFSpecifiedTab") { [weak self] obj in
///         guard let self else { return }
///         let idx = obj as? Int ?? 0
///     }
///
/// 2) 强类型：
///     self.onObject("IFSpecifiedTab") { [weak self] (idx: Int?) in
///         guard let self else { return }
///         print(idx ?? 0)
///     }
///
/// 3) 同时拿：Notification / object / userInfo
///     self.on("IFSpecifiedTab") { [weak self] noti, obj, userInfo in
///         guard let self else { return }
///         print(noti.name, obj as Any, userInfo as Any)
///     }
///
/// 4) 拿完整 Notification：
///     self.onNotification("IFSpecifiedTab") { [weak self] noti in
///         guard let self else { return }
///         print(noti)
///     }
/// =============================== 收通知（旧式 selector） ===============================
///
/// ✅ 完全兼容系统 addObserver(selector:)，你可以继续这样写：
///     NotificationCenter.default.addObserver(self,
///                                  selector: #selector(selectedSpecifiedIndex),
///                                  name: NSNotification.Name("IFSpecifiedTab"),
///                                  object: nil)
///
/// =============================== 移除通知 ===============================
///
/// ✅ 推荐：deinit 里调用
///     deinit { removeAllNotifications() }
///
/// 1) 移除所有：
///     self.removeAllNotifications()
///
/// 2) 移除某个通知名（同时清旧式 + token）：
///     self.removeNotification("IFSpecifiedTab")
///
/// 3) token 自己移除（静态监听时需要你保存 token）：
///     let t = NSObject.onObject("xxx") { _ in }
///     t.cancel()
///
// MARK: - JobsNotificationToken（无 Rx 版本）
public protocol JobsNotificationToken {
    func cancel()
}

public final class JobsAnyNotificationToken: JobsNotificationToken {
    private var _cancel: jobsByVoidBlock?
    public init(_ cancel: @escaping jobsByVoidBlock) { self._cancel = cancel }
    public func cancel() { _cancel?(); _cancel = nil }
    deinit { cancel() }
}
// MARK: - 内部 token 容器（挂到 owner/self 上）
private final class JobsNotiTokenBag: NSObject {
    /// name -> tokens
    var tokensByName: [String: [JobsNotificationToken]] = [:]

    func store(_ token: JobsNotificationToken, name: String) {
        tokensByName[name, default: []].append(token)
    }

    func cancelAll() {
        let dict = tokensByName
        tokensByName.removeAll()
        dict.values.flatMap { $0 }.forEach { $0.cancel() }
    }

    func cancel(name: String) {
        guard let tokens = tokensByName.removeValue(forKey: name) else { return }
        tokens.forEach { $0.cancel() }
    }

    deinit { cancelAll() }
}

private var jobsNotiBagKey: UInt8 = 0
private extension NSObject {
    var jobs_notiBag: JobsNotiTokenBag {
        if let bag = objc_getAssociatedObject(self, &jobsNotiBagKey) as? JobsNotiTokenBag {
            return bag
        }
        let bag = JobsNotiTokenBag()
        objc_setAssociatedObject(self, &jobsNotiBagKey, bag, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        return bag
    }

    func jobs_store(_ token: JobsNotificationToken, name: String) {
        jobs_notiBag.store(token, name: name)
    }

    func jobs_cancelAllTokens() {
        jobs_notiBag.cancelAll()
    }

    func jobs_cancelTokens(name: String) {
        jobs_notiBag.cancel(name: name)
    }
}
// MARK: - NotificationCenter 基础监听实现（无 Rx）
extension NotificationCenter {
    /// 接收通知（内部基础实现）
    /// - 返回 JobsNotificationToken：用于手动 cancel（比如静态监听）
    @discardableResult
    public static func _onBase(
        _ name: Notification.Name,
        object: AnyObject? = nil,
        queue queue: OperationQueue? = nil,
        handler: @escaping jobsByNotiBlock
    ) -> JobsNotificationToken {
        let token = NotificationCenter.default.addObserver(
            forName: name,
            object: object,
            queue: queue,
            using: handler
        )
        return JobsAnyNotificationToken {
            NotificationCenter.default.removeObserver(token)
        }
    }
    /// owner 版（String）
    public static func on(
        _ rawName: String,
        owner: NSObject,
        object: AnyObject? = nil,
        queue queue: OperationQueue? = nil,
        handler: @escaping jobsByNotiBlock) {
        let t = _onBase(Notification.Name(rawName),
                        object: object,
                        queue: queue,
                        handler: handler)
        owner.jobs_store(t, name: rawName)
    }
    /// owner 版（Notification.Name）
    public static func on(
        _ name: Notification.Name,
        owner: NSObject,
        object: AnyObject? = nil,
        queue queue: OperationQueue? = nil,
        handler: @escaping jobsByNotiBlock) {
        let t = _onBase(name,
                        object: object,
                        queue: queue,
                        handler: handler)
        owner.jobs_store(t, name: name.rawValue)
    }
}
// MARK: - 发通知（对齐系统：name + object + userInfo）
extension NSObject {
    // MARK: Instance
    /// 只发 name
    @inline(__always)
    public func post(_ name: String) {
        Self.post(name, object: nil, userInfo: nil)
    }
    /// 发 userInfo
    @inline(__always)
    public func post(_ name: String, userInfo: [AnyHashable: Any]?) {
        Self.post(name, object: nil, userInfo: userInfo)
    }
    /// 发 object
    @inline(__always)
    public func post(_ name: String, object: Any?) {
        Self.post(name, object: object, userInfo: nil)
    }
    /// 发 object + userInfo（完整对齐系统参数）
    @inline(__always)
    public func post(_ name: String,
                     object: Any? = nil,
                     userInfo: [AnyHashable: Any]? = nil) {
        Self.post(name, object: object, userInfo: userInfo)
    }
    // MARK: Static / Class
    /// 只发 name
    @inline(__always)
    public class func post(_ name: String) {
        post(name, object: nil, userInfo: nil)
    }
    /// 发 userInfo
    @inline(__always)
    public class func post(_ name: String, userInfo: [AnyHashable: Any]?) {
        post(name, object: nil, userInfo: userInfo)
    }
    /// 发 object
    @inline(__always)
    public class func post(_ name: String, object: Any?) {
        post(name, object: object, userInfo: nil)
    }
    /// 发 object + userInfo（完整对齐系统参数）
    @inline(__always)
    public class func post(_ name: String,
                           object: Any? = nil,
                           userInfo: [AnyHashable: Any]? = nil) {
        let notiName = Notification.Name(name)
        onMainImmediateOrAsync {
            NotificationCenter.default.post(name: notiName,
                                            object: object,
                                            userInfo: userInfo)
        }
    }
}
// MARK: - 接收通知（易用 API）
/// 说明：
/// - Instance 版：自动存 token 到 self，生命周期自动管理
/// - Class 版：返回 token，需要你自己持有（否则立刻释放收不到）
extension NSObject {
    // MARK: Instance（推荐）
    /// 只拿 object（Any?）
    public func onObject(_ name: String,
                         object filter: AnyObject? = nil,
                         queue queue: OperationQueue? = nil,
                         _ block: @escaping jobsByAnyBlock) {
        NotificationCenter.on(Notification.Name(name),
                              owner: self,
                              object: filter,
                              queue: queue) { noti in
            block(noti.object)
        }
    }
    /// 强类型：直接拿到 CGFloat / Int / Model 等（从 noti.object 转）
    public func onObject<T>(_ name: String,
                            object filter: AnyObject? = nil,
                            queue queue: OperationQueue? = nil,
                            _ block: @escaping jobsByTypeBlock<T>) {
        NotificationCenter.on(Notification.Name(name),
                              owner: self,
                              object: filter,
                              queue: queue) { noti in
            block(noti.object as? T)
        }
    }
    /// 同时拿：noti / object / userInfo（都可选）
    public func on(_ name: String,
                   object filter: AnyObject? = nil,
                   queue queue: OperationQueue? = nil,
                   _ block: @escaping jobsByNotiObjUserInfoBlock) {
        NotificationCenter.on(Notification.Name(name),
                              owner: self,
                              object: filter,
                              queue: queue) { noti in
            block(noti, noti.object as AnyObject?, noti.userInfo)
        }
    }
    /// 如果想拿完整 Notification
    public func onNotification(_ name: String,
                               object filter: AnyObject? = nil,
                               queue queue: OperationQueue? = nil,
                               _ block: @escaping jobsByNotiBlock) {
        NotificationCenter.on(Notification.Name(name),
                              owner: self,
                              object: filter,
                              queue: queue,
                              handler: block)
    }
    // MARK: Class（需要手动持有 token）
    @discardableResult
    public class func onObject(_ name: String,
                               object filter: AnyObject? = nil,
                               queue queue: OperationQueue? = nil,
                               _ block: @escaping jobsByAnyBlock) -> JobsNotificationToken {
        NotificationCenter._onBase(Notification.Name(name),
                                   object: filter,
                                   queue: queue) { noti in
            block(noti.object)
        }
    }

    @discardableResult
    public class func onObject<T>(_ name: String,
                                  object filter: AnyObject? = nil,
                                  queue queue: OperationQueue? = nil,
                                  _ block: @escaping jobsByTypeBlock<T>) -> JobsNotificationToken {
        NotificationCenter._onBase(Notification.Name(name),
                                   object: filter,
                                   queue: queue) { noti in
            block(noti.object as? T)
        }
    }

    @discardableResult
    public class func on(_ name: String,
                         object filter: AnyObject? = nil,
                         queue queue: OperationQueue? = nil,
                         _ block: @escaping jobsByNotiObjUserInfoBlock) -> JobsNotificationToken {
        NotificationCenter._onBase(Notification.Name(name),
                                   object: filter,
                                   queue: queue) { noti in
            block(noti, noti.object as AnyObject?, noti.userInfo)
        }
    }

    @discardableResult
    public class func onNotification(_ name: String,
                                     object filter: AnyObject? = nil,
                                     on queue: OperationQueue? = nil,
                                     _ block: @escaping jobsByNotiBlock) -> JobsNotificationToken {
        NotificationCenter._onBase(Notification.Name(name),
                                   object: filter,
                                   queue: queue,
                                   handler: block)
    }
}
// MARK: - 旧式 selector 监听（可选）
extension NSObject {
    /// 用法：
    /// self.onSelector("RefreshUI", selector: #selector(onRefreshUI(_:)))
    /// @objc private func onRefreshUI(_ noti: Notification) {}
    @inline(__always)
    public func onSelector(_ name: String,
                           object: AnyObject? = nil,
                           selector: Selector) {
        NotificationCenter.default.addObserver(
            self,
            selector: selector,
            name: Notification.Name(name),
            object: object
        )
    }
}
// MARK: - 移除通知（完整：旧式 + token）
extension NSObject {
    /// 移除所有通知（旧式 + 闭包 token）
    /// 推荐：deinit 调用
    @inline(__always)
    public func removeAllNotifications() {
        NotificationCenter.default.removeObserver(self) // 旧式
        jobs_cancelAllTokens()                          // token
    }

    /// 移除某个 name 的通知（旧式 + token）
    @inline(__always)
    public func removeNotification(_ name: String, object: AnyObject? = nil) {
        NotificationCenter.default.removeObserver(self,
                                                  name: Notification.Name(name),
                                                  object: object) // 旧式
        jobs_cancelTokens(name: name) // token
    }
}

extension String {
    /// "通知名称".removeNotification(self)
    @inline(__always)
    public func removeNotification(_ observer: Any, object: AnyObject? = nil) {
        NotificationCenter.default.removeObserver(
            observer,
            name: Notification.Name(self),
            object: object
        )
        // 如果 observer 是 NSObject，并且使用了本文件的闭包 on(...)，顺便移除 token
        (observer as? NSObject)?.removeNotification(self, object: object)
    }
}

extension Notification.Name {
    /// Notification.Name("通知名称").removeNotification(self)
    @inline(__always)
    public func removeNotification(_ observer: Any, object: AnyObject? = nil) {
        NotificationCenter.default.removeObserver(
            observer,
            name: self,
            object: object
        )
        (observer as? NSObject)?.removeNotification(self.rawValue, object: object)
    }
}

extension JobsNotificationToken {
    /// token.cancel() 的语义糖
    @inline(__always)
    public func removeNotification() {
        cancel()
    }
}
