//
//  UITextField+监听.swift
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
import JobsSwiftDSL
import JobsSwiftBaseDefines

// MARK: - UITextField 输入监听
extension UITextField {
    /// 输入监听（默认不限制）
    /// 效果@等于父系方法UIControl.byAddAction.editingChanged，只不过比父系方法先调用
    @discardableResult
    public func byOnInput(limit: Int? = nil,
                          _ callback: @escaping (_ char: String,
                                                 _ value: String,
                                                 _ mode: JobsTextInputMode,
                                                 _ isLimited: Bool,
                                                 _ text: String,
                                                 _ tv: UITextField) -> Void) -> Self {
        let obs = jobs_textInputObserver
        obs.limit = limit
        obs.onInput = { [weak self] char, value, mode, isLimited in
            guard let self else { return }
            callback(char, value, mode, isLimited, self.text ?? "", self)
        }
        let proxy = installDelegateProxyIfNeeded()
        proxy.forward = obs
        obs.originalTextFieldDelegate = proxy.original
        return self
    }
    /// 输入框由不活跃状态 ➤ 活跃状态 只调用一次
    @discardableResult
    public func byBeginEditing(_ callback: @escaping (_ value: String) -> Void) -> Self {
        let obs = jobs_textInputObserver
        obs.onBegin = callback
        let proxy = installDelegateProxyIfNeeded()
        proxy.forward = obs
        obs.originalTextFieldDelegate = proxy.original
        return self
    }
    /// 失去激活状态回调
    @discardableResult
    public func byEndEditing(_ callback: @escaping (_ value: String) -> Void) -> Self {
        let obs = jobs_textInputObserver
        obs.onEnd = callback
        let proxy = installDelegateProxyIfNeeded()
        proxy.forward = obs
        obs.originalTextFieldDelegate = proxy.original
        return self
    }
}
// MARK: - UITextField 系统的删除键监听
public final class UITextFieldDelegateProxy: NSObject, UITextFieldDelegate {
    /// 负责“输入监听”的真实 delegate（你的 jobs_textInputObserver）
    weak var forward: UITextFieldDelegate?
    /// jobs_textInputObserver 用来转发的“原 delegate”
    weak var original: UITextFieldDelegate?
    /// clear 按钮回调
    var shouldClear: ((UITextField) -> Bool)?
    // 关键：把没实现的 delegate 方法全转发给 forward
    public override func forwardingTarget(for aSelector: Selector!) -> Any? {
        if let forward, forward.responds(to: aSelector) { return forward };return super.forwardingTarget(for: aSelector)
    }

    public override func responds(to aSelector: Selector!) -> Bool {
        if super.responds(to: aSelector) { return true }
        if let forward, forward.responds(to: aSelector) { return true };return false
    }

    // 我们只拦截 clear
    public func textFieldShouldClear(_ textField: UITextField) -> Bool {
        if let shouldClear { return shouldClear(textField) };return forward?.textFieldShouldClear?(textField)
            ?? original?.textFieldShouldClear?(textField)
            ?? true
    }
}

private var tfProxyKey: UInt8 = 0
public extension UITextField {
    var textFieldDelegateProxy: UITextFieldDelegateProxy {
        if let p = objc_getAssociatedObject(self, &tfProxyKey) as? UITextFieldDelegateProxy {
            return p
        }
        let p = UITextFieldDelegateProxy()
        objc_setAssociatedObject(self, &tfProxyKey, p, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        return p
    }
    /// 确保 proxy 是 delegate（永远不被覆盖）
    @discardableResult
    func installDelegateProxyIfNeeded() -> UITextFieldDelegateProxy {
        let p = textFieldDelegateProxy
        if delegate !== p {
            // 记录当时的 delegate 作为 original，供 obs 转发
            p.original = delegate
            delegate = p
        };return p
    }
    /// 链式监听系统 clear
    @discardableResult
    func onShouldClear(_ block: @escaping (UITextField) -> Bool) -> Self {
        installDelegateProxyIfNeeded().shouldClear = block
        return self
    }
}
