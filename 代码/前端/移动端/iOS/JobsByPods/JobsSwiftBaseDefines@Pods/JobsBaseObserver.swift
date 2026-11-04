//
//  JobsBaseObserver.swift
//  JobsSwiftBaseDefines
//
//  Created by Jobs on 2026年5月13日，星期三.
//

#if os(OSX)
import AppKit
#elseif os(iOS) || os(tvOS)
import UIKit
#endif

import ObjectiveC

// MARK: - 核心观察者（同时服务 UITextField / UITextView）
public final class JobsTextInputObserver: NSObject,
                                          UITextFieldDelegate,
                                          UITextViewDelegate {
    // 限制（nil = 不限制）
    public var limit: Int?
    // 输入回调：(当前输入字符, 当前控件值, 输入模式, 是否限制输入)
    public var onInput: ((String, String, JobsTextInputMode, Bool) -> Void)?
    // 激活/失活回调：(当前控件值)
    public var onBegin: ((String) -> Void)?
    public var onEnd: ((String) -> Void)?
    // 原 delegate（如果你外面自己设过 delegate，这里尽量转发）
    public weak var originalTextFieldDelegate: UITextFieldDelegate?
    public weak var originalTextViewDelegate: UITextViewDelegate?
    private weak var composingField: UITextField?
    private weak var composingView: UITextView?
    // MARK: - UITextFieldDelegate
    public func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool {
        let allow = originalTextFieldDelegate?.textFieldShouldBeginEditing?(textField) ?? true
        return allow
    }

    public func textFieldDidBeginEditing(_ textField: UITextField) {
        onBegin?(textField.text ?? "")
        originalTextFieldDelegate?.textFieldDidBeginEditing?(textField)
    }

    public func textFieldDidEndEditing(_ textField: UITextField) {
        onEnd?(textField.text ?? "")
        originalTextFieldDelegate?.textFieldDidEndEditing?(textField)
    }

    public func textFieldDidEndEditing(_ textField: UITextField, reason: UITextField.DidEndEditingReason) {
        onEnd?(textField.text ?? "")
        originalTextFieldDelegate?.textFieldDidEndEditing?(textField, reason: reason)
    }

    public func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        // 这里不是输入字符事件（真正的输入判定走 shouldChange），但保持 delegate 转发
        return originalTextFieldDelegate?.textFieldShouldReturn?(textField) ?? true
    }

    public func textField(_ textField: UITextField,
                          shouldChangeCharactersIn range: NSRange,
                          replacementString string: String) -> Bool {
        let old = textField.text ?? ""
        guard validRange(range, in: old) else {
            return false
        }
        let originalAllow = originalTextFieldDelegate?.textField?(textField, shouldChangeCharactersIn: range, replacementString: string) ?? true
        if textField.markedTextRange != nil {
            composingField = textField
            return originalAllow
        }
        let proposed = (old as NSString).replacingCharacters(in: range, with: string)
        let mode = inputMode(string, range: range)
        let lengthAllowed = limit.map { proposed.count <= max(0, $0) } ?? true
        let allow = originalAllow && lengthAllowed && mode != .space
        let value = allow ? proposed : old
        onInput?(mode == .delete || mode == .return ? "" : string, value, mode, limited(value))
        return allow
    }

    public func textFieldDidChangeSelection(_ textField: UITextField) {
        if textField.markedTextRange != nil {
            composingField = textField
        } else if composingField === textField {
            composingField = nil
            let committed = constrained(textField.text ?? "")
            if textField.text != committed {
                textField.text = committed
            }
            onInput?("", committed, .normal, limited(committed))
        }
        originalTextFieldDelegate?.textFieldDidChangeSelection?(textField)
    }
    // MARK: - UITextViewDelegate
    public func textViewShouldBeginEditing(_ textView: UITextView) -> Bool {
        let allow = originalTextViewDelegate?.textViewShouldBeginEditing?(textView) ?? true
        return allow
    }

    public func textViewDidBeginEditing(_ textView: UITextView) {
        onBegin?(textView.text ?? "")
        originalTextViewDelegate?.textViewDidBeginEditing?(textView)
    }

    public func textViewDidEndEditing(_ textView: UITextView) {
        onEnd?(textView.text ?? "")
        originalTextViewDelegate?.textViewDidEndEditing?(textView)
    }

    public func textView(_ textView: UITextView,
                         shouldChangeTextIn range: NSRange,
                         replacementText text: String) -> Bool {
        let old = textView.text ?? ""
        guard validRange(range, in: old) else {
            return false
        }
        let originalAllow = originalTextViewDelegate?.textView?(textView, shouldChangeTextIn: range, replacementText: text) ?? true
        if textView.markedTextRange != nil {
            composingView = textView
            return originalAllow
        }
        let proposed = (old as NSString).replacingCharacters(in: range, with: text)
        let mode = inputMode(text, range: range)
        let lengthAllowed = limit.map { proposed.count <= max(0, $0) } ?? true
        let allow = originalAllow && lengthAllowed
        let value = allow ? proposed : old
        onInput?(mode == .delete || mode == .return ? "" : text, value, mode, limited(value))
        return allow
    }

    public func textViewDidChange(_ textView: UITextView) {
        if textView.markedTextRange != nil {
            composingView = textView
        } else if composingView === textView {
            composingView = nil
            let committed = constrained(textView.text ?? "")
            if textView.text != committed {
                textView.text = committed
            }
            onInput?("", committed, .normal, limited(committed))
        }
        originalTextViewDelegate?.textViewDidChange?(textView)
    }

    private func validRange(_ range: NSRange, in string: String) -> Bool {
        let length = (string as NSString).length
        return range.location >= 0 && range.location <= length && range.length >= 0 && range.length <= length - range.location
    }

    private func inputMode(_ text: String, range: NSRange) -> JobsTextInputMode {
        if text == " " {
            return .space
        }
        if text == "\n" {
            return .return
        }
        if text.isEmpty && range.length > 0 {
            return .delete
        }
        return .normal
    }

    private func limited(_ text: String) -> Bool {
        limit.map { text.count >= max(0, $0) } ?? false
    }

    private func constrained(_ text: String) -> String {
        guard let limit else {
            return text
        }
        return String(text.prefix(max(0, limit)))
    }

}
// MARK: - Associated Keys
private enum JobsTextInputAssociatedKeys {
    static var observer: UInt8 = 0
}
// MARK: - 内部：获取/绑定 observer
public protocol JobsTextInputAttachable: AnyObject {}
extension UITextField: JobsTextInputAttachable {}
extension UITextView: JobsTextInputAttachable {}
extension JobsTextInputAttachable {
    public var jobs_textInputObserver: JobsTextInputObserver {
        if let obj = objc_getAssociatedObject(
            self,
            &JobsTextInputAssociatedKeys.observer
        ) as? JobsTextInputObserver {
            return obj
        }
        let obj = JobsTextInputObserver()
        objc_setAssociatedObject(
            self,
            &JobsTextInputAssociatedKeys.observer,
            obj,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        );return obj
    }
}

public final class WeakBox<T: AnyObject> {
    public weak var value: T?
    public init(_ value: T?) { self.value = value }
}
