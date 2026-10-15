//
//  UIControl+DSL.swift
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

// MARK: - 直接赋值@单参数
extension UIControl {
    // MARK: - 基础状态
    @discardableResult
    public func byEnabled(_ on: Bool?) -> Self {
        self.isEnabled = on ?? false
        return self
    }

    @discardableResult
    public func bySelected(_ on: Bool?) -> Self {
        self.isSelected = on ?? false
        return self
    }

    @discardableResult
    public func byToggleSelected() -> Self {
        self.isSelected.toggle()
        return self
    }

    @discardableResult
    public func byHighlighted(_ on: Bool?) -> Self {
        self.isHighlighted = on ?? false
        return self
    }
    // MARK: - 内容对齐（你关心的 contentHorizontalAlignment / contentVerticalAlignment）
    /// ✅ 单独设置 contentHorizontalAlignment
    @discardableResult
    public func byContentHorizontalAlignment(_ alignment: UIControl.ContentHorizontalAlignment) -> Self {
        self.contentHorizontalAlignment = alignment
        return self
    }
    /// ✅ 单独设置 contentVerticalAlignment
    @discardableResult
    public func byContentVerticalAlignment(_ alignment: UIControl.ContentVerticalAlignment) -> Self {
        self.contentVerticalAlignment = alignment
        return self
    }
    // MARK: - Context Menu（iOS 14+）
    /// 开启/关闭把菜单作为主操作（touch-down 展开）
    @available(iOS 14.0, *)
    @discardableResult
    public func byShowsMenuAsPrimaryAction(_ on: Bool) -> Self {
        self.showsMenuAsPrimaryAction = on
        return self
    }
    /// 启用/禁用上下文菜单交互
    @available(iOS 14.0, *)
    @discardableResult
    public func byContextMenuEnabled(_ on: Bool) -> Self {
        self.isContextMenuInteractionEnabled = on
        return self
    }
    // MARK: - ToolTip（iOS 15+）
    @available(iOS 15.0, *)
    @discardableResult
    public func byToolTip(_ text: String?) -> Self {
        self.toolTip = text
        return self
    }
    // MARK: - SF Symbol 动画（iOS 17+）
    @available(iOS 17.0, *)
    @discardableResult
    public func bySymbolAnimationEnabled(_ on: Bool) -> Self {
        self.isSymbolAnimationEnabled = on
        return self
    }
}
// MARK: - 闭包重载@单参数
extension UIControl {
    @discardableResult
    public func byEnabled(_ builder: () -> Bool?) -> Self {
        self.isEnabled = builder() ?? false
        return self
    }

    @discardableResult
    public func bySelected(_ builder: () -> Bool?) -> Self {
        self.isSelected = builder() ?? false
        return self
    }

    @discardableResult
    public func byHighlighted(_ builder: () -> Bool?) -> Self {
        self.isHighlighted = builder() ?? false
        return self
    }
    @discardableResult
    public func byContentHorizontalAlignment(_ builder: () -> UIControl.ContentHorizontalAlignment) -> Self {
        self.contentHorizontalAlignment = builder()
        return self
    }
    @discardableResult
    public func byContentVerticalAlignment(_ builder: () -> UIControl.ContentVerticalAlignment) -> Self {
        self.contentVerticalAlignment = builder()
        return self
    }
    @available(iOS 14.0, *)
    @discardableResult
    public func byShowsMenuAsPrimaryAction(_ builder: () -> Bool) -> Self {
        self.showsMenuAsPrimaryAction = builder()
        return self
    }
    @available(iOS 14.0, *)
    @discardableResult
    public func byContextMenuEnabled(_ builder: () -> Bool) -> Self {
        self.isContextMenuInteractionEnabled = builder()
        return self
    }
    @available(iOS 15.0, *)
    @discardableResult
    public func byToolTip(_ builder: () -> String?) -> Self {
        self.toolTip = builder()
        return self
    }
    @available(iOS 17.0, *)
    @discardableResult
    public func bySymbolAnimationEnabled(_ builder: () -> Bool) -> Self {
        self.isSymbolAnimationEnabled = builder()
        return self
    }
}

private var trampolines: UInt8 = 0
extension UIControl {
    private final class _JobsActionTrampoline: NSObject {
        let handler: (UIControl) -> Void
        init(_ handler: @escaping (UIControl) -> Void) { self.handler = handler }
        @objc func invoke(_ sender: UIControl) { handler(sender) }
    }

    private var _jobs_trampolines: NSMutableArray {
        if let arr = objc_getAssociatedObject(self, &trampolines) as? NSMutableArray {
            return arr
        }
        let arr = NSMutableArray()
        objc_setAssociatedObject(
            self,
            &trampolines,
            arr,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        );return arr
    }
    /// 同时设置
    @discardableResult
    public func byContentAlignment(horizontal: UIControl.ContentHorizontalAlignment? = nil,
                                   vertical: UIControl.ContentVerticalAlignment? = nil) -> Self {
        if let h = horizontal { self.contentHorizontalAlignment = h }
        if let v = vertical { self.contentVerticalAlignment = v };return self
    }
    /// effectiveContentHorizontalAlignment 是只读属性：这里只能提供读取（无法 DSL set）
    @discardableResult
    public func onEffectiveContentHorizontalAlignment(_ block: (UIControl.ContentHorizontalAlignment) -> Void) -> Self {
        block(self.effectiveContentHorizontalAlignment)
        return self
    }
    // MARK: - Target-Action（传统）
    @discardableResult
    public func byAddTarget(_ target: Any?,
                            action: Selector,
                            for events: UIControl.Event) -> Self {
        addTarget(target, action: action, for: events)
        return self
    }
    @discardableResult
    public func byRemoveTarget(_ target: Any?,
                               action: Selector? = nil,
                               for events: UIControl.Event) -> Self {
        removeTarget(target, action: action, for: events)
        return self
    }
    /// 触发指定事件（比如 .touchUpInside）
    @discardableResult
    public func bySendActions(for events: UIControl.Event) -> Self {
        sendActions(for: events)
        return self
    }
    // MARK: - UIAction（iOS 14+）
    /// 直接加一个 UIAction；identifier 相同会被替换
    @available(iOS 14.0, *)
    @discardableResult
    public func byAddAction(_ action: UIAction, for events: UIControl.Event) -> Self {
        addAction(action, for: events)
        return self
    }
    /// ✅ 闭包形式，iOS12/13/14+ 都能用
    @discardableResult
    public func byAddAction(for events: UIControl.Event,
                            _ handler: @escaping (Self) -> Void) -> Self {
        // iOS 14+ 走系统 UIAction（更干净）
        if #available(iOS 14.0, *) {
            let action = UIAction { [weak self] _ in
                guard let self else { return }
                handler(self)
            }
            addAction(action, for: events)
            // UIAction 系统会持有，不强制需要我们保存
            return self
        }
        // iOS 13-：用 trampoline
        let trampoline = _JobsActionTrampoline { control in
            guard let typed = control as? Self else { return }
            handler(typed)
        }
        _jobs_trampolines.add(trampoline) // 必须保存，不然 trampoline 会被释放
        addTarget(trampoline, action: #selector(_JobsActionTrampoline.invoke(_:)), for: events)
        return self
    }
    // ================================== ✅ 强壮版：允许链式中类型被“擦除”也能拿到具体 sender ==================================
    /// 典型场景：UISwitch().byOn(YES).byAddAction(for: .valueChanged) { (sw: UISwitch) in ... }
    /// 即使前面 DSL 把静态类型变成了 UIControl，这个重载也能通过闭包参数推断 T=UISwitch。
    @discardableResult
    public func byAddAction<T: UIControl>(for events: UIControl.Event,
                                          _ handler: @escaping (T) -> Void) -> Self {
        // iOS 14+：UIAction
        if #available(iOS 14.0, *) {
            let action = UIAction { [weak self] _ in
                guard let self, let typed = self as? T else { return }
                handler(typed)
            }
            addAction(action, for: events)
            return self
        }
        // iOS 13-：trampoline
        let trampoline = _JobsActionTrampoline { control in
            guard let typed = control as? T else { return }
            handler(typed)
        }
        _jobs_trampolines.add(trampoline)
        addTarget(trampoline, action: #selector(_JobsActionTrampoline.invoke(_:)), for: events)
        return self
    }
    /// 移除指定实例的 UIAction
    @available(iOS 14.0, *)
    @discardableResult
    public func byRemoveAction(_ action: UIAction, for events: UIControl.Event) -> Self {
        removeAction(action, for: events); return self
    }
    /// 根据 identifier 移除 UIAction
    @available(iOS 14.0, *)
    @discardableResult
    public func byRemoveAction(identifiedBy id: UIAction.Identifier, for events: UIControl.Event) -> Self {
        removeAction(identifiedBy: id, for: events); return self
    }
    /// 便捷：闭包形式 UIAction（建议你平时就用这个）
    @available(iOS 14.0, *)
    @discardableResult
    public func byOn(_ events: UIControl.Event,
                     id: UIAction.Identifier? = nil,
                     _ handler: @escaping (UIAction) -> Void) -> Self {
        addAction( UIAction(identifier: id, handler: handler), for: events)
        return self
    }
    /// 便捷：primaryActionTriggered
    @available(iOS 14.0, *)
    @discardableResult
    public func byOnPrimaryAction(id: UIAction.Identifier? = nil,
                                  _ handler: @escaping (UIAction) -> Void) -> Self {
        byOn(.primaryActionTriggered, id: id, handler)
    }
    // MARK: - Primary Action（iOS 17.4+）
    @available(iOS 17.4, *)
    @discardableResult
    public func byPerformPrimaryAction() -> Self {
        performPrimaryAction()
        return self
    }
}
