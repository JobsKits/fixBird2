//
//  UITextView+输入字数限制显示.swift
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
import SnapKit

// MARK: - UITextView + HintLimit (charCount/limit)
extension UITextView {
    /// 右下角计数提示：`当前字数/限制字数`，如 `3/200`
    /// - Note: 视觉优先。一旦设置，对于限制字数的优先级 ➤ byHintLimit > byOnInput
    @discardableResult
    public func byHintLimit(_ limit: Int,
                            _ config: ((UILabel) -> Void)? = nil) -> Self {
        let locked = max(0, limit)
        jobs_hintLimitLocked = locked // ✅ 锁定优先级来源
        // ✅ 强制同步到真正的输入限制
        jobs_textInputObserver.limit = locked
        let lb = jobs_installHintLabelIfNeeded()
        config?(lb)
        jobs_adjustTextInsetForHintLabelIfNeeded()
        jobs_updateHintLabel()
        jobs_installTextDidChangeObserverIfNeeded()
        jobs_installSuperviewHookIfNeeded()
        jobs_attachHintLabelIfPossible()
        onMainAsync { [weak self] in
            guard let self else { return }
            self.jobs_attachHintLabelIfPossible()
            self.jobs_updateHintLabel()
            // 再同步一次，确保后续链式不会改掉
            if let locked = self.jobs_hintLimitLocked {
                self.jobs_textInputObserver.limit = locked
            }
        };return self
    }
    /// 显式关闭 hintLimit 优先级（关闭后，byOnInput 的 limit 才能重新生效）
    @discardableResult
    public func byHintLimitOff() -> Self {
        jobs_hintLimitLocked = nil
        jobs_hintLabel?.removeFromSuperview()
        jobs_hintLabel = nil
        jobs_didAdjustInset = false
        return self
    }

    public func jobs_refreshHintLimit() {
        jobs_updateHintLabel()
    }
}
// MARK: - Private Associated Storage
extension UITextView {
    private struct JobsHintKeys {
        static var labelKey: UInt8 = 0
        static var hintLockedKey: UInt8 = 0
        static var tokenKey: UInt8 = 0
        static var originalInsetKey: UInt8 = 0
        static var didAdjustInsetKey: UInt8 = 0
        static var deinitBoxKey: UInt8 = 0
        static var superviewHookKey: UInt8 = 0
    }

    private final class JobsDeinitBox {
        let cleanup: () -> Void
        init(_ cleanup: @escaping () -> Void) { self.cleanup = cleanup }
        deinit { cleanup() }
    }

    private final class JobsSuperviewHookView: UIView {
        weak var host: UITextView?
        @discardableResult
        public func byHost(_ host: UITextView?) -> Self {
            self.host = host
            return self
        }
        override func didMoveToSuperview() {
            super.didMoveToSuperview()
            host?.jobs_attachHintLabelIfPossible()
            host?.jobs_updateHintLabel()
        }
        override func didMoveToWindow() {
            super.didMoveToWindow()
            host?.jobs_attachHintLabelIfPossible()
            host?.jobs_updateHintLabel()
        }
    }

    internal var jobs_hintLimitLocked: Int? {
        get { objc_getAssociatedObject(self, &JobsHintKeys.hintLockedKey) as? Int }
        set {
            objc_setAssociatedObject(
                self,
                &JobsHintKeys.hintLockedKey,
                newValue,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
        }
    }

    fileprivate var jobs_hintLabel: UILabel? {
        get { objc_getAssociatedObject(self, &JobsHintKeys.labelKey) as? UILabel }
        set {
            objc_setAssociatedObject(
                self,
                &JobsHintKeys.labelKey,
                newValue,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
        }
    }

    private var jobs_textDidChangeToken: NSObjectProtocol? {
        get { objc_getAssociatedObject(self, &JobsHintKeys.tokenKey) as? NSObjectProtocol }
        set {
            objc_setAssociatedObject(
                self,
                &JobsHintKeys.tokenKey,
                newValue,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
        }
    }

    private var jobs_originalTextInset: UIEdgeInsets? {
        get { (objc_getAssociatedObject(self, &JobsHintKeys.originalInsetKey) as? NSValue)?.uiEdgeInsetsValue }
        set {
            objc_setAssociatedObject(
                self,
                &JobsHintKeys.originalInsetKey,
                newValue.map { NSValue(uiEdgeInsets: $0) },
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
        }
    }

    fileprivate var jobs_didAdjustInset: Bool {
        get { (objc_getAssociatedObject(self, &JobsHintKeys.didAdjustInsetKey) as? Bool) ?? false }
        set {
            objc_setAssociatedObject(
                self,
                &JobsHintKeys.didAdjustInsetKey,
                newValue,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
        }
    }

    private var jobs_deinitBox: JobsDeinitBox? {
        get { objc_getAssociatedObject(self, &JobsHintKeys.deinitBoxKey) as? JobsDeinitBox }
        set {
            objc_setAssociatedObject(
                self,
                &JobsHintKeys.deinitBoxKey,
                newValue,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }

    private var jobs_superviewHook: JobsSuperviewHookView? {
        get { objc_getAssociatedObject(self, &JobsHintKeys.superviewHookKey) as? JobsSuperviewHookView }
        set {
            objc_setAssociatedObject(
                self,
                &JobsHintKeys.superviewHookKey,
                newValue,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
}
// MARK: - Install / Update
extension UITextView {
    @discardableResult
    fileprivate func jobs_installHintLabelIfNeeded() -> UILabel {
        if let lb = jobs_hintLabel { return lb }
        let lb = UILabel()
            .byUserInteractionEnabled(false)
            .byFont(JobsFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular))
            .byTextColor(JobsCor.secondaryLabel)
            .byBackgroundColor(JobsCor.clear)
            .byTextAlignment(.right)
            .byNumberOfLines(1)
            .byZPosition(.greatestFiniteMagnitude)
        jobs_hintLabel = lb
        return lb
    }

    fileprivate func jobs_attachHintLabelIfPossible() {
        guard let lb = jobs_hintLabel else { return }
        guard let sv = superview else { return }
        if lb.superview === sv {
            sv.bringSubviewToFront(lb)
            lb.byZPosition(.greatestFiniteMagnitude)
            return
        }
        lb.removeFromSuperview()
        sv.addSubview(lb)
        sv.bringSubviewToFront(lb)
        lb.byZPosition(.greatestFiniteMagnitude)
        lb.snp.remakeConstraints { make in
            make.right.equalTo(self.snp.right).offset(-6)
            make.bottom.equalTo(self.snp.bottom).offset(-6)
        }
    }

    fileprivate func jobs_installSuperviewHookIfNeeded() {
        if jobs_superviewHook != nil { return }
        jobs_superviewHook = JobsSuperviewHookView(frame: .zero)
            .byBackgroundColor(JobsCor.clear)
            .byUserInteractionEnabled(false)
            .byHost(self)
            .byAddTo(self) { [unowned self] make in
                make.edges.equalToSuperview()
            }
    }

    fileprivate func jobs_adjustTextInsetForHintLabelIfNeeded() {
        guard jobs_didAdjustInset == false else { return }
        jobs_originalTextInset = textContainerInset
        let minBottom: CGFloat = 22
        var inset = textContainerInset
        if inset.bottom < minBottom {
            inset.bottom = minBottom
            textContainerInset = inset
        }
        jobs_didAdjustInset = true
    }

    fileprivate func jobs_updateHintLabel() {
        guard let lb = jobs_hintLabel else { return }
        let current = (text ?? "").count
        lb.byText("\(current)/\(jobs_hintLimitLocked ?? 0)")
        jobs_attachHintLabelIfPossible()
        // ✅ 再兜底一次：永远保持 observer.limit 与 hintLock 同步
        if let locked = jobs_hintLimitLocked {
            jobs_textInputObserver.limit = locked
        }
    }

    fileprivate func jobs_installTextDidChangeObserverIfNeeded() {
        if jobs_textDidChangeToken != nil { return }
        let token = NotificationCenter.default.addObserver(
            forName: UITextView.textDidChangeNotification,
            object: self,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            self.jobs_updateHintLabel()
        }
        jobs_textDidChangeToken = token
        if jobs_deinitBox == nil {
            jobs_deinitBox = JobsDeinitBox { [weak self] in
                guard let self, let t = self.jobs_textDidChangeToken else { return }
                NotificationCenter.default.removeObserver(t)
                self.jobs_textDidChangeToken = nil
            }
        }
    }
}
