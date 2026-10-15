//
//  UIButton.swift
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

//  说明（本版仅“计时器”相关做了统一改造，UI 链式等其余原样保留）：
//  -----------------------------------------------------------------------------
//  - 外部只需一个“是否传 total”的参数差异，即可决定【正计时】（不传）或【倒计时】（传）。
//  - 计时器实例统一挂在按钮上：`button.timer`（不再使用 jobsTimer）。
//  - 统一链式事件（与 onTap 同级）：
//      `onTimerTick { btn, current, total?, kind in ... }`
//      `onTimerFinish { btn, kind in ... }`
//    语义化别名（倒计时专用）：`onCountdownTick` / `onCountdownFinish`。
//  - 统一控制 API：
//      `startTimer(total: Int? = nil, interval: TimeInterval = 1.0, kind: JobsTimerKind = .gcd)`
//      `pauseTimer()` / `resumeTimer()` / `fireTimerOnce()` / `stopTimer()`
//    并保留兼容封装：`startJobsTimer(...)` 等（内部转调新 API）。
//  - 内建按钮级状态机：`timerState`（idle / running / paused / stopped），可用
//      `onTimerStateChange { btn, old, new in ... }` 订阅；
//    默认的 UI 变化已内置（想自己接管就设置 onTimerStateChange 覆盖）。
//
private var _jobsBGURLKey:   UInt8 = 0   // URL?
private var _jobsBGStateKey: UInt8 = 0   // UIControl.State.RawValue
private var _jobsIsCloneKey: UInt8 = 0   // Bool
public extension UIButton {
    /// 最近一次设置“背景图”的 URL（供克隆或复用）
    var jobs_bgURL: URL? {
        get { objc_getAssociatedObject(self, &_jobsBGURLKey) as? URL }
        set {
            objc_setAssociatedObject(
                self,
                &_jobsBGURLKey,
                newValue,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
        }
    }
    /// 最近一次设置背景图时使用的 state
    var jobs_bgState: UIControl.State {
        get { UIControl.State(rawValue: (objc_getAssociatedObject(self, &_jobsBGStateKey) as? UInt) ?? UIControl.State.normal.rawValue) }
        set {
            objc_setAssociatedObject(
                self,
                &_jobsBGStateKey,
                newValue.rawValue,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
    /// 是否“克隆按钮”：克隆时禁用过渡动画、优先现成位图/缓存
    var jobs_isClone: Bool {
        get { (objc_getAssociatedObject(self, &_jobsIsCloneKey) as? Bool) ?? false }
        set {
            objc_setAssociatedObject(
                self,
                &_jobsIsCloneKey,
                newValue,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
}
