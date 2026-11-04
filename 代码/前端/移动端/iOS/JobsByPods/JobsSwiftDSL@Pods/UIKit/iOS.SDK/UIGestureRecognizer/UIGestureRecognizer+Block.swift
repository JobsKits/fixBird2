//
//  UIGestureRecognizer+Block.swift
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

// ================================== 闭包容器 ==================================
private final class _GestureClosureBox {
    let block: (UIGestureRecognizer) -> Void
    init(_ block: @escaping (UIGestureRecognizer) -> Void) { self.block = block }
}
// ================================== UIGestureRecognizer 链式 block 初始化 ==================================
private var GestureBlockKey: UInt8 = 0
private var GestureInvokeInstalledKey: UInt8 = 0
extension UIGestureRecognizer {
    // MARK: - 通过闭包配置（替代 target/selector）——类方法（创建并绑定）
    public static func byConfig(_ block: @escaping (UIGestureRecognizer) -> Void) -> Self {
        let gesture = Self()
        gesture._setActionBlock(block)
        gesture._ensureInvokeTargetInstalled()
        return gesture
    }
    /// 允许：UIPanGestureRecognizer.byConfig { (gr: UIPanGestureRecognizer) in ... }
    public static func byConfig<T: UIGestureRecognizer>(_ block: @escaping (T) -> Void) -> Self {
        let gesture = Self()
        gesture._setActionBlock { sender in
            guard let typed = sender as? T else { return }
            block(typed)
        }
        gesture._ensureInvokeTargetInstalled()
        return gesture
    }
    // MARK: - 通过闭包配置（替代 target/selector）——实例方法（对已有手势绑定）
    @discardableResult
    public func byConfig(_ block: @escaping (UIGestureRecognizer) -> Void) -> Self {
        byAction(block)
    }
    /// 允许：UIPanGestureRecognizer().byConfig { (gr: UIPanGestureRecognizer) in ... }
    @discardableResult
    public func byConfig<T: UIGestureRecognizer>(_ block: @escaping (T) -> Void) -> Self {
        byAction(block)
    }
    // MARK: - 为已有手势添加 block（实例）
    @discardableResult
    public func byAction(_ block: @escaping (UIGestureRecognizer) -> Void) -> Self {
        _setActionBlock(block)
        _ensureInvokeTargetInstalled()
        return self
    }
    /// 强类型实例版：gr.byAction { (pan: UIPanGestureRecognizer) in ... }
    @discardableResult
    public func byAction<T: UIGestureRecognizer>(_ block: @escaping (T) -> Void) -> Self {
        _setActionBlock { sender in
            guard let typed = sender as? T else { return }
            block(typed)
        }
        _ensureInvokeTargetInstalled()
        return self
    }
    // MARK: - invoke
    @objc
    private func _gestureInvoke(_ sender: UIGestureRecognizer) {
        (objc_getAssociatedObject(self, &GestureBlockKey) as? _GestureClosureBox)?.block(sender)
    }

    private func _setActionBlock(_ block: @escaping (UIGestureRecognizer) -> Void) {
        objc_setAssociatedObject(
            self,
            &GestureBlockKey,
            _GestureClosureBox(block),
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
    }
    /// 防止重复 addTarget（多次 byAction/byConfig 不会重复触发）
    private func _ensureInvokeTargetInstalled() {
        let installed = (objc_getAssociatedObject(self, &GestureInvokeInstalledKey) as? Bool) ?? false
        guard !installed else { return }
        addTarget(self, action: #selector(_gestureInvoke(_:)))
        objc_setAssociatedObject(
            self,
            &GestureInvokeInstalledKey,
            true,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
    }
}
