//
//  UIView+统一点击事件.swift
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
import JobsSwiftBlock

// MARK: - UIView / UIControl 统一事件 DSL
extension UIView {
    // 用一个 key 挂一整张表：[eventRawValue : wrapper]
    private struct JobsAssociatedKeys {
        static var handlersKey: UInt8 = 0
        static var tapGestureKey: UInt8 = 0
    }

    private var jobsHandlers: [UInt: _JobsClosureWrapper] {
        get {
            (objc_getAssociatedObject(self, &JobsAssociatedKeys.handlersKey) as? [UInt: _JobsClosureWrapper]) ?? [:]
        }
        set {
            objc_setAssociatedObject(
                self,
                &JobsAssociatedKeys.handlersKey,
                newValue,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
        }
    }
    // MARK: - 通用 Tap 事件（对 UIView -> 手势，对 UIControl -> touchUpInside）
    @discardableResult
    public func onJobsTap<T: UIView>(_ handler: @escaping jobsByNonNullTypeBlock<T>) -> Self {
        addJobsAction(for: .touchUpInside, handler)
        return self
    }
    // MARK: - 通用 ValueChanged（仅对 UIControl 有意义）
    @discardableResult
    public func onJobsChange<T: UIView>(_ handler: @escaping jobsByNonNullTypeBlock<T>) -> Self {
        addJobsAction(for: .valueChanged, handler)
        return self
    }
    // MARK: - 通用事件绑定（仅对 UIControl 有意义）
    @discardableResult
    public func onJobsEvent<T: UIControl>(_ event: UIControl.Event,
                                          _ handler: @escaping jobsByNonNullTypeBlock<T>) -> Self {
        addJobsAction(for: event, handler)
        return self
    }
    // MARK: - 内部统一注册函数（分流：UIControl 用 addTarget；UIView 用手势）
    private func addJobsAction<T: UIView>(for event: UIControl.Event,
                                          _ handler: @escaping jobsByNonNullTypeBlock<T>) {
        let box = _JobsClosureWrapper { [weak self] in
            guard let self else { return }
            if let specific = self as? T {
                handler(specific)
            }
        }
        // 按事件存起来，避免不同事件互相覆盖
        var dict = jobsHandlers
        dict[event.rawValue] = box
        jobsHandlers = dict
        // 1) 如果是 UIControl，走系统 addTarget
        if let control = self as? UIControl {
            control.addTarget(box, action: #selector(_JobsClosureWrapper.invoke), for: event)
            return
        }
        // 2) 纯 UIView：目前只支持“点击”等价于 touchUpInside
        if event == .touchUpInside {
            isUserInteractionEnabled = true
            // 防止重复加手势：只加一次
            if objc_getAssociatedObject(self, &JobsAssociatedKeys.tapGestureKey) as? UITapGestureRecognizer == nil {
                let tap = UITapGestureRecognizer(target: self, action: #selector(_jobs_handleViewTap))
                addGestureRecognizer(tap)
                objc_setAssociatedObject(self, &JobsAssociatedKeys.tapGestureKey, tap, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            };return
        }
        // 3) 其它事件对 UIView 没意义
        assertionFailure("UIView 不支持 UIControl.Event=\(event)。如果需要，请把视图改成 UIControl/UIButton，或为 UIView 实现对应手势/机制。")
    }
    @objc private func _jobs_handleViewTap() {
        // touchUpInside 的 rawValue
        let key = UIControl.Event.touchUpInside.rawValue
        jobsHandlers[key]?.invoke()
    }
}
