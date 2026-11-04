//
//  UITextView+监听.swift
//  JobsByUIKit
//
//  Created by Jobs on 2026年5月13日，星期三.
//

#if os(OSX)
import AppKit
#elseif os(iOS) || os(tvOS)
import UIKit
#endif

import JobsSwiftBaseDefines

// MARK: - UITextView 点语法
extension UITextView {
    /// 输入监听
    /// - Note: 视觉优先。一旦设置，对于限制字数的优先级 ➤ byHintLimit > byOnInput
    @discardableResult
    public func byOnInput(
        limit: Int? = nil,
        _ callback: @escaping (_ char: String,
                               _ value: String,
                               _ mode: JobsTextInputMode,
                               _ isLimited: Bool,
                               _ text: String,
                               _ tv: UITextView) -> Void
    ) -> Self {
        let obs = jobs_textInputObserver
        // ✅ 视觉优先：hintLimit 一旦存在，onInput 的 limit 不得覆盖
        if let locked = jobs_hintLimitLocked {
            obs.limit = locked
        } else {
            obs.limit = limit
        }
        obs.onInput = { [weak self] char, value, mode, isLimited in
            guard let self else { return }
            callback(char, value, mode, isLimited, self.text ?? "", self)
        }
        if delegate !== obs {
            obs.originalTextViewDelegate = delegate
            delegate = obs
        };return self
    }
    /// 显式取消输入限制（若已设置 byHintLimit，则此方法也无效；必须先 byHintLimitOff）
    @discardableResult
    public func byOnInputUnlimited() -> Self {
        let obs = jobs_textInputObserver
        if let locked = jobs_hintLimitLocked {
            obs.limit = locked
        } else {
            obs.limit = nil
        }
        if delegate !== obs {
            obs.originalTextViewDelegate = delegate
            delegate = obs
        };return self
    }
    /// 激活到输入态回调
    @discardableResult
    public func byBeginEditing(_ callback: @escaping (_ value: String) -> Void) -> Self {
        let obs = jobs_textInputObserver
        obs.onBegin = callback
        if delegate !== obs {
            obs.originalTextViewDelegate = delegate
            delegate = obs
        };return self
    }
    /// 失去激活状态回调
    @discardableResult
    public func byEndEditing(_ callback: @escaping (_ value: String) -> Void) -> Self {
        let obs = jobs_textInputObserver
        obs.onEnd = callback
        if delegate !== obs {
            obs.originalTextViewDelegate = delegate
            delegate = obs
        };return self
    }
}
