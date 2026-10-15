//
//  UIViewController+自定义进入方向.swift
//  JobsByUIKit
//
//  Created by Jobs on 2026年5月13日，星期三.
//

#if os(OSX)
import AppKit
#elseif os(iOS) || os(tvOS)
import UIKit
import JobsViewPush
#endif

import JobsSwiftBlock
import JobsSwiftDSL
import JobsSwiftBaseDefines

// MARK: - 内部：CATransition 的方向映射（含上下互换修正）
public extension JobsPushDirection {
    var _caSubtype: CATransitionSubtype {
        switch self {
        /// 合并处理 .system、.fromRight 分支
        case .system, .fromRight:
            return .fromRight            // 系统默认右进
        /// 处理 .fromLeft 分支
        case .fromLeft:
            return .fromLeft
        /// 处理 .fromTop 分支
        case .fromTop:
            return .fromBottom           // ✅ 修正：互换上下（视觉为“自上而下”进入）
        /// 处理 .fromBottom 分支
        case .fromBottom:
            return .fromTop              // ✅ 修正：互换上下（视觉为“自下而上”进入）
        }
    }
    // 反向用于 pop：与上面的 subtype 取互逆
    var _reverseCASubtype: CATransitionSubtype {
        switch self {
        /// 合并处理 .system、.fromRight 分支
        case .system, .fromRight: return .fromLeft
        /// 处理 .fromLeft 分支
        case .fromLeft:           return .fromRight
        /// push 用了 .fromBottom，pop 用 .fromTop
        case .fromTop:            return .fromTop
        /// push 用了 .fromTop，pop 用 .fromBottom
        case .fromBottom:         return .fromBottom
        }
    }
    var _debugKey: String {
        switch self {
        /// 处理 .system 分支
        case .system:     return "system"
        /// 处理 .fromLeft 分支
        case .fromLeft:   return "fromLeft"
        /// 处理 .fromRight 分支
        case .fromRight:  return "fromRight"
        /// 处理 .fromTop 分支
        case .fromTop:    return "fromTop"
        /// 处理 .fromBottom 分支
        case .fromBottom: return "fromBottom"
        }
    }
}
public var _jobsPushDirKey: UInt8 = 0
// ========= 新增：记录“进入方向/时长/节奏”，用于自动匹配 pop 反向动画 =========
public var _jobsEntryDirKey: UInt8 = 0
public var _jobsEntryDurKey: UInt8 = 0
public var _jobsEntryTimingKey: UInt8 = 0
extension UIViewController {
    public var _jobs_entryDirection: JobsPushDirection? {
        get {
            guard let n = objc_getAssociatedObject(self, &_jobsEntryDirKey) as? NSNumber else { return nil };return JobsPushDirection(rawValue: n.intValue)
        }
        set {
            if let d = newValue {
                objc_setAssociatedObject(self, &_jobsEntryDirKey, NSNumber(value: d.rawValue), .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            } else {
                objc_setAssociatedObject(self, &_jobsEntryDirKey, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            }
        }
    }
    public var _jobs_entryDuration: CFTimeInterval? {
        get { objc_getAssociatedObject(self, &_jobsEntryDurKey) as? CFTimeInterval }
        set { objc_setAssociatedObject(self, &_jobsEntryDurKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
    public var _jobs_entryTiming: CAMediaTimingFunctionName? {
        get { objc_getAssociatedObject(self, &_jobsEntryTimingKey) as? CAMediaTimingFunctionName }
        set { objc_setAssociatedObject(self, &_jobsEntryTimingKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
}
@MainActor
extension UIViewController {
    // ============================== 链式配置：进入方向 ===============================
    /// 设定下一次 push/present 的进入方向（不设即 .system → 系统默认右进左出）
    @discardableResult
    public func byDirection(_ dir: JobsPushDirection) -> Self {
        objc_setAssociatedObject(self, &_jobsPushDirKey, NSNumber(value: dir.rawValue), .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        return self
    }
    /// 清空已设置的方向（恢复默认）
    @discardableResult
    public func byDirectionReset() -> Self {
        objc_setAssociatedObject(self, &_jobsPushDirKey, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        return self
    }
    /// 读取后即清空；确保“只对下一次 push 生效”
    private func _consumeDirection() -> JobsPushDirection {
        defer { byDirectionReset() }
        if let n = objc_getAssociatedObject(self, &_jobsPushDirKey) as? NSNumber,
           let d = JobsPushDirection(rawValue: n.intValue) {
            return d
        };return .system
    }
}
// MARK: - byPush
extension UIViewController {
    @discardableResult
    public func byPush(_ from: UIResponder?, animated: Bool = true) -> Self {
        // 忽略旧的 animated 参数，统一交给新实现处理（含自定义方向 & 系统默认路径）
        return self.byPush(from, duration: 0.32, timing: .easeInEaseOut)
    }

    @discardableResult
    public func byPush(_ from: UIResponder?,
                       direction: JobsPushDirection,
                       duration: CFTimeInterval = 0.32,
                       CAMediaTimingFunctionName timing: CAMediaTimingFunctionName = .easeInEaseOut) -> Self {
        return self.byDirection(direction).byPush(from, duration: duration, timing: timing)
    }
    // ============================== 使用存储方向的 byPush ==============================
    /// 现用入口：`.byDirection(...).byPush(self)`；不设方向 → 系统默认
    /// - Note: 自定义方向使用 CATransition + 无动画 push；默认方向走系统动画。
    @discardableResult
    public func byPush(_ from: UIResponder?,
                       duration: CFTimeInterval = 0.32,
                       timing: CAMediaTimingFunctionName = .easeInEaseOut) -> Self{
        let dir = _consumeDirection()   // ← 只影响这一次
        guard let host = from?.jobsNearestVC() else {
            assertionFailure("❌ byPush: 未找到宿主 VC")
            return self
        }
        let useCustom = (dir != .system)
        /// 1、抽屉体系优先 mainNav（满屏 push）
        if let mainNav = host.jobs_findMainNavFromAncestors() {
            // 轻量防连点（沿用你现有策略）
            if mainNav._jobs_isPushingLocked { return self }
            mainNav._jobs_lockPushing(for: 0.2)
            if useCustom {
                let tr = CATransition()
                tr
                    .byType(.push)
                    .bySubtype(dir._caSubtype)
                tr.duration = duration
                tr.timingFunction = CAMediaTimingFunction(name: timing)
                mainNav.view.layer.add(tr, forKey: "jobs.push.main.\(dir._debugKey)")
                self._jobs_entryDirection = dir
                self._jobs_entryDuration = duration
                self._jobs_entryTiming = timing
                UINavigationController._jobs_installPopSwizzlesIfNeeded()
                mainNav.pushViewController(self, animated: false)
                #if canImport(GKNavigationBarSwift)
                self.jobsEnsureNavigationDefaults()
                #endif
                DispatchQueue.main.async { [weak self] in
                    self?.jobs_fireAppearCompletionIfNeeded(reason: "pushCATransition(mainNav)")
                };return self
            } else {
                self._jobs_entryDirection = nil
                mainNav.pushViewController(self, animated: true)
                #if canImport(GKNavigationBarSwift)
                self.jobsEnsureNavigationDefaults()
                #endif
                if let tc = mainNav.transitionCoordinator {
                    tc.animate(alongsideTransition: nil) { [weak self] _ in
                        self?.jobs_fireAppearCompletionIfNeeded(reason: "pushTransitionCoordinator(mainNav)")
                    }
                } else {
                    DispatchQueue.main.async { [weak self] in
                        self?.jobs_fireAppearCompletionIfNeeded(reason: "pushAsyncFallback(mainNav)")
                    }
                };return self
            }
        }
        /// 2、优先使用宿主导航栈
        if let nav = (host as? UINavigationController) ?? host.navigationController {
            // 轻量防连点
            if nav._jobs_isPushingLocked { return self }
            nav._jobs_lockPushing(for: 0.2)
            if useCustom {
                // 用 CATransition 模拟进入方向；push 本身必须设为非动画
                let tr = CATransition()
                tr
                    .byType(.push)
                    .bySubtype(dir._caSubtype)
                tr.duration = duration
                tr.timingFunction = CAMediaTimingFunction(name: timing)
                nav.view.layer.add(tr, forKey: "jobs.push.\(dir._debugKey)")
                // 记录“进入动画参数”，供 pop 反向使用
                self._jobs_entryDirection = dir
                self._jobs_entryDuration = duration
                self._jobs_entryTiming = timing
                // 安装 pop swizzle（一次性）
                UINavigationController._jobs_installPopSwizzlesIfNeeded()
                nav.pushViewController(self, animated: false)
                #if canImport(GKNavigationBarSwift)
                self.jobsEnsureNavigationDefaults()
                #endif
                // appear-jobsByVoidBlock 兜底
                DispatchQueue.main.async { [weak self] in
                    self?.jobs_fireAppearCompletionIfNeeded(reason: "pushCATransition")
                };return self
            } else {
                // 系统默认动画 → 不记录方向（保持系统默认 pop 行为）
                self._jobs_entryDirection = nil
                nav.pushViewController(self, animated: true)
                #if canImport(GKNavigationBarSwift)
                self.jobsEnsureNavigationDefaults()
                #endif
                if let tc = nav.transitionCoordinator {
                    tc.animate(alongsideTransition: nil) { [weak self] _ in
                        self?.jobs_fireAppearCompletionIfNeeded(reason: "pushTransitionCoordinator")
                    }
                } else {
                    DispatchQueue.main.async { [weak self] in
                        self?.jobs_fireAppearCompletionIfNeeded(reason: "pushAsyncFallback")
                    }
                };return self
            }
        }
        /// 3、没有导航栈：包一层 Nav 再 present（保持原有语义）
        let wrapped = self.jobsNavContainer
            .byNavigationBarHidden(true)
            .byModalPresentationStyle(.fullScreen)
        if useCustom {
            let layer = host.view.window?.layer ?? host.view.layer
            let tr = CATransition()
                .byType(.push)
                .bySubtype(dir._caSubtype)
                .byDuration(duration)
                .byTimingFunction(
                    CAMediaTimingFunction(name: timing)
                )
            layer.add(tr, forKey: "jobs.present.push.\(dir._debugKey)")
            // 记录进入参数（仅供需要时外部自定义 dismiss 使用；系统 dismiss 默认方向不改）
            self._jobs_entryDirection = dir
            self._jobs_entryDuration = duration
            self._jobs_entryTiming = timing
            host.present(wrapped, animated: false) { [weak self] in
                #if canImport(GKNavigationBarSwift)
                self?.jobsEnsureNavigationDefaults()
                #endif
                self?.jobs_fireAppearCompletionIfNeeded(reason: "presentWrappedForPushCATransition")
            }
        } else {
            self._jobs_entryDirection = nil
            host.present(wrapped, animated: true) { [weak self] in
                #if canImport(GKNavigationBarSwift)
                self?.jobsEnsureNavigationDefaults()
                #endif
                self?.jobs_fireAppearCompletionIfNeeded(reason: "presentWrappedForPush")
            }
        };return self
    }
}
// MARK: - byPresent
extension UIViewController {
    @discardableResult
    public func byPresent(_ from: UIResponder?,
                   animated: Bool = true,
                   policy: JobsPresentPolicy = .ignoreIfBusy,
                   jobsByVoidBlock: (jobsByVoidBlock)? = nil) -> Self {
        assert(Thread.isMainThread, "byPresent must be called on main thread")
        // 目标不能已挂载 / 正在展示
        guard self.parent == nil, self.presentingViewController == nil else {
            assertionFailure("❌ Trying to present a VC already mounted/presented: \(self)")
            return self
        }
        // 宿主选择
        guard var host = from?.jobsNearestVC() ?? UIWindow.wd.rootViewController else {
            assertionFailure("❌ byPresent: no host VC"); return self
        }
        if let top = UIApplication.jobsTopMostVC(from: host, ignoreAlert: true) { host = top }
        guard host.viewIfLoaded?.window != nil, host.isBeingDismissed == false else { return self }
        // 策略
        switch policy {
        /// 处理 .ignoreIfBusy 分支
        case .ignoreIfBusy:
            if let presented = host.presentedViewController, presented.isBeingDismissed == false {
                if jobs_isSameDestination(as: presented) { return self };return self
            }
        /// 处理 .presentOnTopMost 分支
        case .presentOnTopMost:
            while let top = UIApplication.jobsTopMostVC(from: host, ignoreAlert: true),
                  top.isBeingDismissed == false, top !== host { host = top }
        }
        // 防自己 present 自己
        guard host !== self else {
            assertionFailure("❌ Don't present self on self"); return self
        }
        // 系统 present；完成时触发一次（与 viewDidAppear 幂等）
        host.present(self, animated: animated) { [weak self] in
            jobsByVoidBlock?()
            self?.jobs_fireAppearCompletionIfNeeded(reason: "presentJobsVoidBlock")
        };return self
    }
}
