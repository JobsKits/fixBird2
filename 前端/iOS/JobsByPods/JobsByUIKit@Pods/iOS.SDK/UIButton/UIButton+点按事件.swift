//
//  UIButton+点按事件.swift
//  JobsByUIKit
//
//  Created by Jobs on 2026年5月13日，星期三.
//

#if os(OSX)
import AppKit
#elseif os(iOS) || os(tvOS)
import UIKit
#endif

import JobsSwiftBlock

private enum JobsUIButtonAssociatedKeys {
    static var tapBlocks: UInt8 = 0
    static var tapSleeve: UInt8 = 0
    static var tapActionInstalled: UInt8 = 0
    static var longPressBlock: UInt8 = 0
}
// MARK: - 内部 Sleeve
private final class _JobsButtonTapSleeve: NSObject {
    weak var button: UIButton?
    init(button: UIButton?) {
        self.button = button
    }
    @objc func invoke(_ sender: UIButton) {
        // sender 优先，其次退回到弱引用的 button
        (sender as UIButton? ?? button)?.jobs_invokeTapBlocks()
    }
}

private final class _JobsButtonLongPressSleeve: NSObject {
    weak var button: UIButton?
    init(button: UIButton?) {
        self.button = button
    }
    @objc func invoke(_ g: UILongPressGestureRecognizer) {
        // ✅ 优先用 g.view 拿按钮，clone 的 button 也能拿到自己
        guard let btn = (g.view as? UIButton) ?? button else { return }
        btn.jobs_invokeLongPressBlocks(recognizer: g)
    }
}
// MARK: - 内部工具
extension UIButton {
    // 点击：存一组 block，方便「覆盖」和「叠加」
    private var jobsTapBlocks: [jobsByBtnBlock] {
        get {
            objc_getAssociatedObject(self, &JobsUIButtonAssociatedKeys.tapBlocks) as? [jobsByBtnBlock] ?? []
        }
        set {
            objc_setAssociatedObject(
                self,
                &JobsUIButtonAssociatedKeys.tapBlocks,
                newValue,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
        }
    }
    // 长按：最终聚合成一个 block（内部自己合并 old/new）
    private var jobsLongPressBlock: JobsButtonLongPressBlock? {
        get {
            objc_getAssociatedObject(self, &JobsUIButtonAssociatedKeys.longPressBlock) as? JobsButtonLongPressBlock
        }
        set {
            objc_setAssociatedObject(
                self,
                &JobsUIButtonAssociatedKeys.longPressBlock,
                newValue,
                .OBJC_ASSOCIATION_COPY_NONATOMIC
            )
        }
    }
    // 实际调用点击所有 block
    internal func jobs_invokeTapBlocks() {
        for block in jobsTapBlocks {
            block(self)
        }
    }
    // 实际调用长按聚合 block
    internal func jobs_invokeLongPressBlocks(recognizer: UILongPressGestureRecognizer) {
        jobsLongPressBlock?(self, recognizer)
    }
    // 确保已经挂上「统一点击入口」
    private func jobs_ensureTapHandlerInstalled() {
        if #available(iOS 14.0, *) {
            let installed = (objc_getAssociatedObject(self, &JobsUIButtonAssociatedKeys.tapActionInstalled) as? Bool) ?? false
            if installed { return }
            let action = UIAction { [weak self] _ in
                self?.jobs_invokeTapBlocks()
            }
            (self as UIControl).addAction(action, for: .touchUpInside)
            objc_setAssociatedObject(
                self,
                &JobsUIButtonAssociatedKeys.tapActionInstalled,
                true,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
        } else {
            if objc_getAssociatedObject(self, &JobsUIButtonAssociatedKeys.tapSleeve) != nil { return }
            let sleeve = _JobsButtonTapSleeve(button: self)
            addTarget(
                sleeve,
                action: #selector(_JobsButtonTapSleeve.invoke(_:)),
                for: .touchUpInside
            )
            objc_setAssociatedObject(
                self,
                &JobsUIButtonAssociatedKeys.tapSleeve,
                sleeve,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
        }
    }
    // 确保「统一长按入口」的手势已经挂上
    private func jobs_ensureLongPressRecognizer(minimumPressDuration: TimeInterval) -> Self {
        if let existing = (gestureRecognizers ?? [])
            .compactMap({ $0 as? UILongPressGestureRecognizer })
            .first(where: { objc_getAssociatedObject($0, &kJobsUIButtonLongPressSleeveKey) != nil }) {
            existing.minimumPressDuration = minimumPressDuration
            return self
        }
        let gr = UILongPressGestureRecognizer(target: nil, action: nil)
        gr.minimumPressDuration = minimumPressDuration
        let sleeve = _JobsButtonLongPressSleeve(button: self)
        gr.addTarget(
            sleeve,
            action: #selector(_JobsButtonLongPressSleeve.invoke(_:))
        )
        // 用全局指针 key 标记这是我们挂的 GR，clone 时也能保留 sleeve
        objc_setAssociatedObject(
            gr,
            &kJobsUIButtonLongPressSleeveKey,
            sleeve,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
        addGestureRecognizer(gr)
        isUserInteractionEnabled = true
        return self
    }
}
// MARK: - 闭包回调（低版本兜底）（保留）
private var actionKey: Void?
extension UIButton {
    @discardableResult
    private func _bindTapClosure(_ action: @escaping jobsByBtnBlock,
                                 for events: UIControl.Event = .touchUpInside) -> Self {
        objc_setAssociatedObject(
            self,
            &actionKey,
            action,
            .OBJC_ASSOCIATION_COPY_NONATOMIC
        )
        removeTarget(self, action: #selector(_jobsHandleAction(_:)), for: events)
        addTarget(self, action: #selector(_jobsHandleAction(_:)), for: events)
        return self
    }
    @discardableResult
    public func jobs_addTapClosure(_ action: @escaping jobsByBtnBlock,
                            for events: UIControl.Event = .touchUpInside) -> Self {
        _bindTapClosure(action, for: events)
    }
    @discardableResult
    public func addAction(_ action: @escaping jobsByBtnBlock,
                   for events: UIControl.Event = .touchUpInside) -> Self {
        _bindTapClosure(action, for: events)
    }

    @objc
    private func _jobsHandleAction(_ sender: UIButton) {
        if let action = objc_getAssociatedObject(self, &actionKey) as? (UIButton) -> Void {
            action(sender)
        }
    }
}
// MARK: - 点按事件统一入口
public var kJobsUIButtonLongPressSleeveKey: UInt8 = 0
extension UIButton {
    /// 点击方法@代码触发
    public func performTap() {
        sendActions(for: .touchUpInside)
    }
    @discardableResult
    /// 点击方法@普通
    public func onTap(_ handler: @escaping jobsByBtnBlock) -> Self {
        if #available(iOS 14.0, *) {
            (self as UIControl).addAction(UIAction { [weak self] _ in
                guard let s = self else { return }
                handler(s)
            }, for: .touchUpInside)
        } else {
            self.jobs_addTapClosure(handler)
        };return self
    }
    /// 点击方法@叠加
    @discardableResult
    public func onTapAppend(_ handler: @escaping jobsByBtnBlock) -> Self {
        var blocks = jobsTapBlocks
        blocks.append(handler)             // 叠加
        jobsTapBlocks = blocks
        jobs_ensureTapHandlerInstalled()
        return self
    }
    /// 长按方法@普通
    @discardableResult
    public func onLongPress(
        minimumPressDuration: TimeInterval = 0.5,
        _ handler: @escaping JobsButtonLongPressBlock
    ) -> Self {
        jobsLongPressBlock = handler
        return jobs_ensureLongPressRecognizer(
            minimumPressDuration: minimumPressDuration
        )
    }
    /// 长按方法@叠加
    @discardableResult
    public func onLongPressAppend(
        minimumPressDuration: TimeInterval = 0.5,
        _ handler: @escaping JobsButtonLongPressBlock
    ) -> Self {
        if let old = jobsLongPressBlock {
            // 和 OC 一样：old 在前，new 在后
            jobsLongPressBlock = { btn, gr in
                old(btn, gr)
                handler(btn, gr)
            }
        } else {
            jobsLongPressBlock = handler
        };return jobs_ensureLongPressRecognizer(minimumPressDuration: minimumPressDuration)
    }
}
