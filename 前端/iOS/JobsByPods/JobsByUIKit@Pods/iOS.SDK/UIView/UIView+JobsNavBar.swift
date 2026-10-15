//
//  UIView+JobsNavBar.swift
//  JobsByUIKit
//
//  Created by Jobs on 2026年5月13日，星期三.
//

#if os(OSX)
import AppKit
#elseif os(iOS) || os(tvOS)
import UIKit
#endif

import JobsNavBar
import JobsSwiftBlock

// MARK: - 关联对象 Key（用 UInt8 的地址唯一标识）
private enum _JobsNavBarAO {
    static var bar:  UInt8 = 0
    static var conf: UInt8 = 0
}
// MARK: - 配置体（挂在 UIView 上，而不是某个具体子类）
#if canImport(SnapKit)
import SnapKit
extension UIView {
    public struct JobsNavBarConfig {
        public var enabled: Bool = false
        public var style: JobsNavBar.Style = .init()
        public var titleProvider: JobsRetAttributedString? = nil          // nil -> 隐藏标题；不设=由宿主决定
        public var backButtonProvider: JobsRetButtonBlock? = nil// nil -> 隐藏返回键
        public var onBack: jobsByVoidBlock? = nil                   // 未设置则由宿主兜底
        public var layout: ((JobsNavBar, ConstraintMaker, UIView) -> Void)? = nil // 自定义布局
        public var backButtonLayout: ((JobsNavBar, UIButton, ConstraintMaker) -> Void)? = nil
        public init() {}
    }
}
#endif
// MARK: - 公开：取到当前视图身上的 NavBar（只读）
extension UIView {
    public var jobsNavBar: JobsNavBar? {
        objc_getAssociatedObject(self, &_JobsNavBarAO.bar) as? JobsNavBar
    }
    /// 是否存在可见的“导航栏类视图”（优先 GKNavigationBar，其次 UINavigationBar）
    /// - Parameter deep: 是否递归遍历整棵子树（默认 true）
    public func jobs_hasVisibleTopBar(deep: Bool = true) -> Bool {
    #if canImport(GKNavigationBarSwift)
        return jobs_existingTopBar(deep: deep) != nil
    #else
        return false
    #endif
    }
}
// MARK: - 私有：配置读写 + 应用
@MainActor
extension UIView {
    private var _jobsNavBarConfig: JobsNavBarConfig {
        get { (objc_getAssociatedObject(self, &_JobsNavBarAO.conf) as? JobsNavBarConfig) ?? .init() }
        set {
            objc_setAssociatedObject(
                self,
                &_JobsNavBarAO.conf,
                newValue,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }

    private func _setJobsNavBar(_ bar: JobsNavBar?) {
        objc_setAssociatedObject(
            self,
            &_JobsNavBarAO.bar,
            bar,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
    }

    private func _applyNavBarConfig() {
        let cfg = _jobsNavBarConfig
        if cfg.enabled {
            let bar: JobsNavBar
            if let b = jobsNavBar {
                bar = b
                bar.style = cfg.style
            } else {
                bar = JobsNavBar(style: cfg.style)
                addSubview(bar)
                _setJobsNavBar(bar)
            }
            // 提供器（返回 nil -> 隐藏）
            bar.titleProvider = cfg.titleProvider
            bar.backButtonProvider = cfg.backButtonProvider
            // ✅ 透传外层 backButtonLayout（触发 didSet -> 只重排约束，不重复 add）
            bar.backButtonLayout = cfg.backButtonLayout
            // 返回行为
            if let onBack = cfg.onBack { bar.onBack = onBack }
            // 布局 NavBar 本体（与返回键无关）
            bar.snp.remakeConstraints { make in
                if let L = cfg.layout {
                    L(bar, make, self)
                } else {
                    make.top.equalTo(self.safeAreaLayoutGuide.snp.top)
                    make.left.right.equalToSuperview()
                }
            }
            (self as? JobsNavBarHost)?.jobsNavBarDidToggle(enabled: true, navBar: bar)
        } else {
            if let bar = jobsNavBar {
                bar.removeFromSuperview()
                _setJobsNavBar(nil)
                (self as? JobsNavBarHost)?.jobsNavBarDidToggle(enabled: false, navBar: bar)
            }
        }
    }
}
// MARK: - UIView 链式 DSL（任何 UIView 均可使用）
@MainActor
extension UIView {
    @discardableResult
    public func byNavBarEnabled(_ on: Bool = true) -> Self {
        var c = _jobsNavBarConfig
        c.enabled = on
        _jobsNavBarConfig = c
        _applyNavBarConfig()
        return self
    }

    @discardableResult
    public func byNavBarStyle(_ edit: (inout JobsNavBar.Style) -> Void) -> Self {
        var c = _jobsNavBarConfig
        edit(&c.style)
        _jobsNavBarConfig = c
        _applyNavBarConfig()
        return self
    }
    /// 自定义标题（返回 nil -> 隐藏；不设置则留给宿主绑定，例如绑定到 webView.title）
    @discardableResult
    public func byNavBarTitleProvider(_ p: @escaping JobsRetAttributedString) -> Self {
        var c = _jobsNavBarConfig
        c.titleProvider = p
        _jobsNavBarConfig = c
        _applyNavBarConfig()
        return self
    }
    /// 自定义返回键（返回 nil -> 隐藏）
    @discardableResult
    public func byNavBarBackButtonProvider(_ p: @escaping JobsRetButtonBlock) -> Self {
        var c = _jobsNavBarConfig
        c.backButtonProvider = p
        _jobsNavBarConfig = c
        _applyNavBarConfig()
        return self
    }
    /// 自定义返回键@约束
    @discardableResult
    public func byNavBarBackButtonLayout(_ layout: @escaping BackButtonLayout) -> Self {
        var c = _jobsNavBarConfig
        c.backButtonLayout = layout
        _jobsNavBarConfig = c
        _applyNavBarConfig()
        return self
    }
    /// 返回行为（比如“优先 webView.goBack，否则 pop”）
    @discardableResult
    public func byNavBarOnBack(_ h: @escaping jobsByVoidBlock) -> Self {
        var c = _jobsNavBarConfig
        c.onBack = h
        _jobsNavBarConfig = c
        _applyNavBarConfig()
        return self
    }
    /// 覆盖默认布局（默认：贴宿主 safeArea 顶，左右铺满）
    @discardableResult
    public func byNavBarLayout(_ layout: @escaping (JobsNavBar, ConstraintMaker, UIView) -> Void) -> Self {
        var c = _jobsNavBarConfig
        c.layout = layout
        _jobsNavBarConfig = c
        _applyNavBarConfig()
        return self
    }
}
