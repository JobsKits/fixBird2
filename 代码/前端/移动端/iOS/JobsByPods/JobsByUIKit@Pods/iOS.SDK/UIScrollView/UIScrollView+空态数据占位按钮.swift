//
//  UIScrollView+空态数据占位按钮.swift
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
import JobsSwiftDSL
import JobsSwiftBaseDefines

// MARK: - UIScrollView层：统一的占位能力@按钮

#if canImport(SnapKit)
import SnapKit
public enum JobsEmptyAuto {
    public enum Config {
        /// 全局默认按钮提供器（你可在 App 任何位置重写）
        public static var defaultProvider: () -> UIButton = {
            UIButton.sys()
                .byTitle("暂无数据".tr, for: .normal)
                .bySubTitle("下拉刷新或点我试试".tr, for: .normal)
                .byTitleFont(JobsFont.systemFont(ofSize: 18, weight: .semibold))
                .bySubTitleFont(JobsFont.systemFont(ofSize: 13))
                .byTitleColor(JobsCor.label, for: .normal)
                .bySubTitleColor(JobsCor.secondaryLabel, for: .normal)
                .byImage("tray".sysImg, for: .normal)
                .byImagePlacement(.top)
        }
    }

    private static var once: Void = {
        // UITableView.reloadData
        _swizzle(
            UITableView.self,
            #selector(UITableView.reloadData),
            #selector(UITableView.jobs_swizzled_reloadData)
        )
        // UICollectionView.reloadData
        _swizzle(
            UICollectionView.self,
            #selector(UICollectionView.reloadData),
            #selector(UICollectionView.jobs_swizzled_reloadData)
        )
        // UICollectionView.performBatchUpdates(_:completion:)
        _swizzle(
            UICollectionView.self,
            #selector(UICollectionView.performBatchUpdates(_:completion:)),
            #selector(UICollectionView.jobs_swizzled_performBatchUpdates(_:completion:))
        )
    }()

    public static func enable() { _ = once }
    private static func _swizzle(
        _ cls: AnyClass,
        _ original: Selector,
        _ swizzled: Selector) {
        guard let m1 = class_getInstanceMethod(cls, original),
              let m2 = class_getInstanceMethod(cls, swizzled) else { return }
        method_exchangeImplementations(m1, m2)
    }
}

enum _JobsEmptyAutoBootstrap {
    static var ensure: Void = {
        JobsEmptyAuto.enable()
    }()
}

var _jobsEmptyBtnKey: UInt8 = 0
var _jobsEmptyProviderKey: UInt8 = 0
var _jobsEmptyDisabledKey: UInt8 = 0
extension UIScrollView {
    // MARK: - 存取：全局/局部 Provider
    /// 链式：设置“本视图”的局部空态按钮提供器
    @discardableResult
    public func byEmptyButtonProvider(_ provider: @escaping () -> UIButton) -> Self {
        _JobsEmptyAutoBootstrap.ensure
        objc_setAssociatedObject(
            self,
            &_jobsEmptyProviderKey,
            provider,
            .OBJC_ASSOCIATION_COPY_NONATOMIC
        )
        // 切换 provider 时，丢弃旧按钮，下一次自动重建
        if let btn = jobs_emptyButton {
            btn.removeFromSuperview()
            objc_setAssociatedObject(
                self,
                &_jobsEmptyBtnKey,
                nil,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
        }
        // 若当前挂着自定义空态 View，也移除，避免并存
        if let view = jobs_emptyView {
            view.removeFromSuperview()
            objc_setAssociatedObject(
                self,
                &_jobsEmptyViewKey,
                nil,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
        };return self
    }
    /// 清除“本视图”的局部 Provider（回退到全局默认）
    @discardableResult
    public func byClearEmptyButtonProvider() -> Self {
        let _ = _JobsEmptyAutoBootstrap.ensure
        objc_setAssociatedObject(
            self,
            &_jobsEmptyProviderKey,
            nil,
            .OBJC_ASSOCIATION_COPY_NONATOMIC
        );return self
    }
    /// 内部读取：局部 Provider
    var _jobs_localProvider: (() -> UIButton)? {
        objc_getAssociatedObject(self, &_jobsEmptyProviderKey) as? (() -> UIButton)
    }
    // MARK: - 按钮布局
    /// 按钮专属布局（保留旧 API）
    @discardableResult
    public func byEmptyButtonLayout(_ layout: @escaping JobsEmptyButtonLayout) -> Self {
        _JobsEmptyAutoBootstrap.ensure
        objc_setAssociatedObject(
            self,
            &_jobsEmptyLayoutKey,
            layout,
            .OBJC_ASSOCIATION_COPY_NONATOMIC
        )
        if let btn = jobs_emptyButton {
            btn._jobsEmptyLayout = layout
            btn.snp.remakeConstraints { [unowned self] make in
                layout(btn, make, self)
            }
        };return self
    }

    @discardableResult
    public func byClearEmptyButtonLayout() -> Self {
        objc_setAssociatedObject(
            self,
            &_jobsEmptyLayoutKey,
            nil,
            .OBJC_ASSOCIATION_COPY_NONATOMIC
        )
        if let btn = jobs_emptyButton {
            btn._jobsEmptyLayout = nil
            _jobs_defaultEmptyButtonConstraints(btn)
        };return self
    }
    // MARK: - 状态：当前按钮 & 开关
    /// 当前挂载的空态按钮（只读）
    public var jobs_emptyButton: UIButton? {
        objc_getAssociatedObject(self, &_jobsEmptyBtnKey) as? UIButton
    }
    /// 关闭本视图的“自动空态”（默认 false）
    public var jobs_emptyAutoDisabled: Bool {
        get {
            (objc_getAssociatedObject(self, &_jobsEmptyDisabledKey) as? Bool) ?? false
        }
        set {
            objc_setAssociatedObject(
                self,
                &_jobsEmptyDisabledKey,
                newValue,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
        }
    }
    // MARK: - 显隐控制（保留原手动/自动 API）
    /// 手动显隐：业务自己判断 empty -> true/false
    @discardableResult
    public func byReloadEmptyViewManual(isEmpty: Bool) -> Self {
        let _ = _JobsEmptyAutoBootstrap.ensure
        _jobs_currentEmptyDisplayView?.isHidden = !isEmpty
        return self
    }
    /// 自动判断（支持 UITableView / UICollectionView）
    @discardableResult
    public func byReloadEmptyViewAuto(animated: Bool = true) -> Self {
        _JobsEmptyAutoBootstrap.ensure
        _jobs_ensureEmptyButtonIfNeeded()
        // 仅表格/集合视图需要自动显隐
        let isEmpty: Bool
        if let tableView = self as? UITableView {
            isEmpty = _jobs_isEmpty(for: tableView)
        } else if let collectionView = self as? UICollectionView {
            isEmpty = _jobs_isEmpty(for: collectionView)
        } else {
            return self
        }
        guard let displayView = _jobs_currentEmptyDisplayView else { return self }
        // 切显隐（带轻动画）；显示时放到最上层
        if animated {
            if isEmpty {
                if displayView.isHidden {
                    displayView
                        .byAlpha(0)
                        .byHidden(false)
                }
                bringSubviewToFront(displayView)
                UIView.animate(withDuration: 0.15) {
                    displayView.byAlpha(1)
                }
            } else {
                UIView.animate(withDuration: 0.15, animations: {
                    displayView.alpha = 0
                }) { _ in
                    displayView.byHidden(true)
                }
            }
        } else {
            displayView.byVisible(isEmpty)
        }
        displayView.byUserInteractionEnabled(isEmpty)
        return self
    }
    // MARK: - 懒创建空态按钮 & 约束
    private func _jobs_ensureEmptyButtonIfNeeded() {
        // 已有占位内容 -> 不创建
        guard _jobs_currentEmptyDisplayView == nil else { return }
        // 尽量保持原来的创建时机：
        // 1. 局部 View Provider
        // 2. 局部 Button Provider
        // 3. 不主动创建全局默认（与旧逻辑尽量一致）
        if let viewProvider = _jobs_localEmptyViewProvider {
            let view = viewProvider().byVisible(NO)
            _jobs_attachEmptyView(view)
            return
        }
        guard let buttonProvider = objc_getAssociatedObject(self, &_jobsEmptyProviderKey) as? () -> UIButton else { return }
        let button = buttonProvider().byVisible(NO).byAddTo(self)
        objc_setAssociatedObject(
            self,
            &_jobsEmptyBtnKey,
            button,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
        // 若外部提供了按钮自定义布局闭包，优先使用；否则走默认约束
        if let anyLayout = objc_getAssociatedObject(self, &_jobsEmptyLayoutKey) {
            if let layout = anyLayout as? JobsEmptyButtonLayout {
                button._jobsEmptyLayout = layout
                button.snp.remakeConstraints { [unowned self] make in
                    layout(button, make, self)
                }
            } else {
                _jobs_defaultEmptyButtonConstraints(button)
            }
        } else {
            _jobs_defaultEmptyButtonConstraints(button)
        }
    }

    private func _jobs_defaultEmptyButtonConstraints(_ btn: UIButton) {
        btn.byMakeConstraints { make in
            make.centerX.equalToSuperview()
            make.centerY.equalToSuperview().offset(-20)
            make.leading.greaterThanOrEqualToSuperview().offset(16)
            make.trailing.lessThanOrEqualToSuperview().offset(-16)
        }
    }
    // MARK: - 创建/挂载/评估
    /// 若无按钮则按“局部View > 局部Button > 全局View > 全局Button”创建并挂载；随后评估显隐
    /// 这里保留旧方法名，兼容你原来 swizzle 回调路径
    public func _jobs_autoEnsureEmptyButtonThenEval() {
        _JobsEmptyAutoBootstrap.ensure
        guard !jobs_emptyAutoDisabled else { return }
        if _jobs_currentEmptyDisplayView == nil {
            if let viewProvider = _jobs_localEmptyViewProvider {
                let view = viewProvider()
                _jobs_attachEmptyView(view)
            } else if let buttonProvider = _jobs_localProvider {
                let button = buttonProvider()
                _jobs_attachEmptyButton(button)
            } else if let globalViewProvider = JobsEmptyViewAuto.Config.defaultProvider {
                let view = globalViewProvider()
                _jobs_attachEmptyView(view)
            } else {
                let button = JobsEmptyAuto.Config.defaultProvider()
                _jobs_attachEmptyButton(button)
            }
        }
        byReloadEmptyViewAuto()
    }
    /// 把按钮挂载到当前 ScrollView 上（会清旧的）
    func _jobs_attachEmptyButton(_ btn: UIButton) {
        // 若按钮原本挂在别处，先摘
        if let superview = btn.superview, superview !== self {
            btn.removeFromSuperview()
        }
        // 清旧约束
        btn.snp.removeConstraints()
        // 移除旧按钮
        if let old = jobs_emptyButton {
            old.removeFromSuperview()
        }
        // 移除旧 View
        if let oldView = jobs_emptyView {
            oldView.removeFromSuperview()
            objc_setAssociatedObject(
                self,
                &_jobsEmptyViewKey,
                nil,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
        }
        // 读取按钮布局
        let buttonLayout = objc_getAssociatedObject(self, &_jobsEmptyLayoutKey) as? JobsEmptyButtonLayout
        btn._jobsEmptyLayout = buttonLayout
        // 自定义布局优先；否则使用默认居中 + 宽度<=90% + 左右不贴边
        btn
            .byAddTo(self) { [unowned self] make in
                if let layout = btn._jobsEmptyLayout {
                    layout(btn, make, self)
                } else {
                    // 默认布局：居中显示，但在超窄容器下允许约束让步
                    make.centerY.equalToSuperview()
                    make.centerX.equalToSuperview().priority(.low)
                    make.width.lessThanOrEqualToSuperview().multipliedBy(0.9)
                    make.leading.greaterThanOrEqualToSuperview().offset(16).priority(.high)
                    make.trailing.lessThanOrEqualToSuperview().inset(16).priority(.high)
                }
            }
            .byBringToFront(self)
        objc_setAssociatedObject(
            self,
            &_jobsEmptyBtnKey,
            btn,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
    }
    /// 判空：UITableView
    func _jobs_isEmpty(for table: UITableView) -> Bool {
        guard let dataSource = table.dataSource else { return true }
        let sections = dataSource.numberOfSections?(in: table) ?? 1
        if sections == 0 { return true }
        var rows = 0
        for section in 0..<sections {
            rows += dataSource.tableView(table, numberOfRowsInSection: section)
            if rows > 0 { return false }
        };return true
    }
    /// 判空：UICollectionView
    func _jobs_isEmpty(for collection: UICollectionView) -> Bool {
        guard let dataSource = collection.dataSource else { return true }
        let sections = dataSource.numberOfSections?(in: collection) ?? 1
        if sections == 0 { return true }
        var items = 0
        for section in 0..<sections {
            items += dataSource.collectionView(collection, numberOfItemsInSection: section)
            if items > 0 { return false }
        };return true
    }
}
#endif
