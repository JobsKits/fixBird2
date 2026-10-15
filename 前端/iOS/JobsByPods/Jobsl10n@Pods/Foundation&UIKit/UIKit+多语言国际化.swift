//
//  UIKit+多语言国际化.swift
//  Jobsl10n
//
//  Created by Jobs on 2026年5月13日，星期三.
//

#if os(OSX)
import AppKit
#elseif os(iOS) || os(tvOS)
import UIKit
#endif

// MARK: - High frequency UI one-liners (small set, big coverage)
// ===== UILabel =====
extension UILabel {
    /// 直接把 ".tr" 的结果丢进来即可；会自动从线程标记里拿 key 并注册刷新
    @discardableResult
    public func tr_setText(_ string: String) -> Self {
        TRBind.bind(self, translated: string, slot: "text") { v, text in
            v.text = text
        };return self
    }
    /// 富文本不做自动注册（如需支持：自己用 TRBind 绑定“富文本工厂”）
    @discardableResult
    public func tr_setAttributedText(_ attr: NSAttributedString) -> Self {
        TRAutoRefresh.unbind(self, slot: "text")
        self.attributedText = attr
        TRBind.consumeMarkerIfNeeded()
        return self
    }
}
// ===== UIButton =====
extension UIButton {
    @discardableResult
    public func tr_setTitle(_ string: String, for state: UIControl.State) -> Self {
        TRBind.bind(self, translated: string, slot: "title.\(state.rawValue)") { btn, text in
            btn.setTitle(text, for: state)
        };return self
    }

    @discardableResult
    public func tr_setAttributedTitle(_ attr: NSAttributedString, for state: UIControl.State) -> Self {
        TRAutoRefresh.unbind(self, slot: "title.\(state.rawValue)")
        self.setAttributedTitle(attr, for: state)
        TRBind.consumeMarkerIfNeeded()
        return self
    }
}
// ===== UITextField =====
extension UITextField {
    @discardableResult
    public func tr_setPlaceholder(_ string: String) -> Self {
        TRBind.bind(self, translated: string, slot: "placeholder") { tf, text in
            tf.placeholder = text
        };return self
    }

    @discardableResult
    public func tr_setText(_ string: String) -> Self {
        TRBind.bind(self, translated: string, slot: "text") { tf, text in
            tf.text = text
        };return self
    }

    @discardableResult
    public func tr_setAttributedPlaceholder(_ attr: NSAttributedString) -> Self {
        TRAutoRefresh.unbind(self, slot: "placeholder")
        self.attributedPlaceholder = attr
        TRBind.consumeMarkerIfNeeded()
        return self
    }

    @discardableResult
    public func tr_setAttributedText(_ attr: NSAttributedString) -> Self {
        TRAutoRefresh.unbind(self, slot: "text")
        self.attributedText = attr
        TRBind.consumeMarkerIfNeeded()
        return self
    }
}
// ===== UITextView =====
extension UITextView {
    @discardableResult
    public func tr_setText(_ string: String) -> Self {
        TRBind.bind(self, translated: string, slot: "text") { tv, text in
            tv.text = text
        };return self
    }

    @discardableResult
    public func tr_setAttributedText(_ attr: NSAttributedString) -> Self {
        TRAutoRefresh.unbind(self, slot: "text")
        self.attributedText = attr
        TRBind.consumeMarkerIfNeeded()
        return self
    }
}
// ===== UIBarButtonItem =====
extension UIBarButtonItem {
    @discardableResult
    public func tr_setTitle(_ string: String) -> Self {
        TRBind.bind(self, translated: string, slot: "title") { item, text in
            item.title = text
        };return self
    }
}
// MARK: - Common "container" text (still low API count)
// ===== UINavigationItem =====
extension UINavigationItem {
    @discardableResult
    public func tr_setTitle(_ string: String?) -> Self {
        guard let string else {
            TRAutoRefresh.unbind(self, slot: "title")
            self.title = nil
            TRBind.consumeMarkerIfNeeded()
            return self
        }
        TRBind.bind(self, translated: string, slot: "title") { item, text in
            item.title = text
        };return self
    }
    /// 主标题上面那一行小字
    @discardableResult
    public func tr_setPrompt(_ string: String?) -> Self {
        guard let string else {
            TRAutoRefresh.unbind(self, slot: "prompt")
            self.prompt = nil
            TRBind.consumeMarkerIfNeeded()
            return self
        }
        TRBind.bind(self, translated: string, slot: "prompt") { item, text in
            item.prompt = text
        };return self
    }
    /// 返回按钮文字
    @discardableResult
    public func tr_setBackButtonTitle(_ string: String?) -> Self {
        guard let string else {
            TRAutoRefresh.unbind(self, slot: "backButtonTitle")
            self.backButtonTitle = nil
            TRBind.consumeMarkerIfNeeded()
            return self
        }
        TRBind.bind(self, translated: string, slot: "backButtonTitle") { item, text in
            item.backButtonTitle = text
        };return self
    }
}
// ===== UITabBarItem =====
extension UITabBarItem {
    @discardableResult
    public func tr_setTitle(_ string: String?) -> Self {
        guard let string else {
            TRAutoRefresh.unbind(self, slot: "title")
            self.title = nil
            TRBind.consumeMarkerIfNeeded()
            return self
        }
        TRBind.bind(self, translated: string, slot: "title") { item, text in
            item.title = text
        };return self
    }
}
// ===== UISegmentedControl =====
extension UISegmentedControl {
    @discardableResult
    public func tr_setTitle(_ string: String, forSegmentAt index: Int) -> Self {
        guard index >= 0, index < numberOfSegments else {
            TRBind.consumeMarkerIfNeeded()
            return self
        }
        TRBind.bind(self, translated: string, slot: "segment.\(index)") { seg, text in
            seg.setTitle(text, forSegmentAt: index)
        };return self
    }
}
// ===== UISearchBar =====
extension UISearchBar {
    @discardableResult
    public func tr_setPlaceholder(_ string: String?) -> Self {
        guard let string else {
            TRAutoRefresh.unbind(self, slot: "placeholder")
            self.placeholder = nil
            TRBind.consumeMarkerIfNeeded()
            return self
        }
        TRBind.bind(self, translated: string, slot: "placeholder") { bar, text in
            bar.placeholder = text
        };return self
    }

    @discardableResult
    public func tr_setPrompt(_ string: String?) -> Self {
        guard let string else {
            TRAutoRefresh.unbind(self, slot: "prompt")
            self.prompt = nil
            TRBind.consumeMarkerIfNeeded()
            return self
        }
        TRBind.bind(self, translated: string, slot: "prompt") { bar, text in
            bar.prompt = text
        };return self
    }
}
// MARK: - Alert (avoid inheritance name conflicts)
/// 注意：不扩 UIViewController 的 tr_setTitle，避免和 UIAlertController 这种子类写同名 API 冲突
extension UIAlertController {
    @discardableResult
    public func tr_setAlertTitle(_ string: String?) -> Self {
        guard let string else {
            TRAutoRefresh.unbind(self, slot: "title")
            self.title = nil
            TRBind.consumeMarkerIfNeeded()
            return self
        }
        TRBind.bind(self, translated: string, slot: "title") { alert, text in
            alert.title = text
        };return self
    }

    @discardableResult
    public func tr_setMessage(_ string: String?) -> Self {
        guard let string else {
            TRAutoRefresh.unbind(self, slot: "message")
            self.message = nil
            TRBind.consumeMarkerIfNeeded()
            return self
        }
        TRBind.bind(self, translated: string, slot: "message") { alert, text in
            alert.message = text
        };return self
    }
}
// MARK: - Accessibility (minimal, non-conflicting)
extension UIView {
    /// A11y label 也需要跟语言切换刷新
    @discardableResult
    public func tr_setA11yLabel(_ string: String?) -> Self {
        guard let string else {
            TRAutoRefresh.unbind(self, slot: "accessibilityLabel")
            self.accessibilityLabel = nil
            TRBind.consumeMarkerIfNeeded()
            return self
        }
        TRBind.bind(self, translated: string, slot: "accessibilityLabel") { v, text in
            v.accessibilityLabel = text
        };return self
    }
    /// A11y hint 也需要跟语言切换刷新
    @discardableResult
    public func tr_setA11yHint(_ string: String?) -> Self {
        guard let string else {
            TRAutoRefresh.unbind(self, slot: "accessibilityHint")
            self.accessibilityHint = nil
            TRBind.consumeMarkerIfNeeded()
            return self
        }
        TRBind.bind(self, translated: string, slot: "accessibilityHint") { v, text in
            v.accessibilityHint = text
        };return self
    }
}
