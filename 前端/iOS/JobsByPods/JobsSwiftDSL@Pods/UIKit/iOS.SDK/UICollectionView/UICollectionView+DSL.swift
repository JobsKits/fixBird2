//
//  UICollectionView+DSL.swift
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

// MARK: - 直接赋值@单参数
extension UICollectionView {
    @discardableResult
    public func byAllowsSelection(_ allow: Bool) -> Self {
        self.allowsSelection = allow
        return self
    }

    @discardableResult
    public func byAllowsMultipleSelection(_ allow: Bool) -> Self {
        self.allowsMultipleSelection = allow
        return self
    }
    /// 数据源 delegate
    @discardableResult
    public func byDelegate(_ delegate: UICollectionViewDelegate?) -> Self {
        self.delegate = delegate
        return self
    }
    /// 数据源 dataSource
    @discardableResult
    public func byDataSource(_ dataSource: UICollectionViewDataSource?) -> Self {
        self.dataSource = dataSource
        return self
    }
    /// 布局对象 UICollectionViewLayout
    @discardableResult
    func byCollectionViewLayout(_ layout: UICollectionViewLayout) -> Self {
        self.collectionViewLayout = layout
        return self
    }
    /// FlowLayout 的滚动方向
    @discardableResult
    public func byScrollDirection(_ direction: UICollectionView.ScrollDirection) -> Self {
        (self.collectionViewLayout as? UICollectionViewFlowLayout)?.scrollDirection = direction
        return self
    }
    /// iOS 14.0+ 编辑状态
    @available(iOS 14.0, *)
    @discardableResult
    public func byEditing(_ editing: Bool) -> Self {
        self.isEditing = editing
        return self
    }
    /// iOS 14.0+ 编辑时允许选择
    @available(iOS 14.0, *)
    @discardableResult
    public func byAllowsSelectionDuringEditing(_ allow: Bool) -> Self {
        self.allowsSelectionDuringEditing = allow
        return self
    }
    /// iOS 14.0+ 编辑时允许多选
    @available(iOS 14.0, *)
    @discardableResult
    public func byAllowsMultipleSelectionDuringEditing(_ allow: Bool) -> Self {
        self.allowsMultipleSelectionDuringEditing = allow
        return self
    }
    /// iOS 9.0+ 记住上次聚焦
    @available(iOS 9.0, *)
    @discardableResult
    public func byRemembersLastFocusedIndexPath(_ remember: Bool) -> Self {
        self.remembersLastFocusedIndexPath = remember
        return self
    }
    /// iOS 14.0+ 焦点移动自动选中
    @available(iOS 14.0, *)
    @discardableResult
    public func bySelectionFollowsFocus(_ enable: Bool) -> Self {
        self.selectionFollowsFocus = enable
        return self
    }
    /// iOS 15.0+ 允许聚焦
    @available(iOS 15.0, *)
    @discardableResult
    public func byAllowsFocus(_ allow: Bool) -> Self {
        self.allowsFocus = allow
        return self
    }
    /// iOS 15.0+ 编辑时允许聚焦
    @available(iOS 15.0, *)
    @discardableResult
    public func byAllowsFocusDuringEditing(_ allow: Bool) -> Self {
        self.allowsFocusDuringEditing = allow
        return self
    }
    /// iOS 10.0+ 预取数据源
    @available(iOS 10.0, *)
    @discardableResult
    public func byPrefetchDataSource(_ ds: UICollectionViewDataSourcePrefetching?) -> Self {
        self.prefetchDataSource = ds
        return self
    }
    /// iOS 10.0+ 是否启用预取
    @available(iOS 10.0, *)
    @discardableResult
    public func byPrefetchingEnabled(_ enabled: Bool) -> Self {
        self.isPrefetchingEnabled = enabled
        return self
    }
    /// iOS 11.0+ 拖拽代理
    @available(iOS 11.0, *)
    @discardableResult
    public func byDragDelegate(_ delegate: UICollectionViewDragDelegate?) -> Self {
        self.dragDelegate = delegate
        return self
    }
    /// iOS 11.0+ 放置代理
    @available(iOS 11.0, *)
    @discardableResult
    public func byDropDelegate(_ delegate: UICollectionViewDropDelegate?) -> Self {
        self.dropDelegate = delegate
        return self
    }
    /// iOS 11.0+ 是否启用拖拽交互
    @available(iOS 11.0, *)
    @discardableResult
    public func byDragInteractionEnabled(_ enabled: Bool) -> Self {
        self.dragInteractionEnabled = enabled
        return self
    }
    /// iOS 11.0+ 重排节奏
    @available(iOS 11.0, *)
    @discardableResult
    public func byReorderingCadence(_ cadence: UICollectionView.ReorderingCadence) -> Self {
        self.reorderingCadence = cadence
        return self
    }
    /// iOS 16.0+ 自适应失效策略
    @available(iOS 16.0, *)
    @discardableResult
    public func bySelfSizingInvalidation(_ value: UICollectionView.SelfSizingInvalidation) -> Self {
        self.selfSizingInvalidation = value
        return self
    }
    @discardableResult
    public func byBackgroundView(_ view: UIView?) -> Self {
        self.backgroundView = view
        return self
    }
}
// MARK: - 闭包重载@单参数
extension UICollectionView {
    @discardableResult
    public func byAllowsSelection(_ builder: () -> Bool) -> Self {
        self.allowsSelection = builder()
        return self
    }

    @discardableResult
    public func byAllowsMultipleSelection(_ builder: () -> Bool) -> Self {
        self.allowsMultipleSelection = builder()
        return self
    }
    @discardableResult
    public func byDelegate(_ builder: () -> UICollectionViewDelegate?) -> Self {
        self.delegate = builder()
        return self
    }
    @discardableResult
    public func byDataSource(_ builder: () -> UICollectionViewDataSource?) -> Self {
        self.dataSource = builder()
        return self
    }
    @discardableResult
    func byCollectionViewLayout(_ builder: () -> UICollectionViewLayout) -> Self {
        self.collectionViewLayout = builder()
        return self
    }
    @discardableResult
    public func byScrollDirection(_ builder: () -> UICollectionView.ScrollDirection) -> Self {
        (self.collectionViewLayout as? UICollectionViewFlowLayout)?.scrollDirection = builder()
        return self
    }
    @available(iOS 14.0, *)
    @discardableResult
    public func byEditing(_ builder: () -> Bool) -> Self {
        self.isEditing = builder()
        return self
    }
    @available(iOS 14.0, *)
    @discardableResult
    public func byAllowsSelectionDuringEditing(_ builder: () -> Bool) -> Self {
        self.allowsSelectionDuringEditing = builder()
        return self
    }
    @available(iOS 14.0, *)
    @discardableResult
    public func byAllowsMultipleSelectionDuringEditing(_ builder: () -> Bool) -> Self {
        self.allowsMultipleSelectionDuringEditing = builder()
        return self
    }
    @available(iOS 9.0, *)
    @discardableResult
    public func byRemembersLastFocusedIndexPath(_ builder: () -> Bool) -> Self {
        self.remembersLastFocusedIndexPath = builder()
        return self
    }
    @available(iOS 14.0, *)
    @discardableResult
    public func bySelectionFollowsFocus(_ builder: () -> Bool) -> Self {
        self.selectionFollowsFocus = builder()
        return self
    }
    @available(iOS 15.0, *)
    @discardableResult
    public func byAllowsFocus(_ builder: () -> Bool) -> Self {
        self.allowsFocus = builder()
        return self
    }
    @available(iOS 15.0, *)
    @discardableResult
    public func byAllowsFocusDuringEditing(_ builder: () -> Bool) -> Self {
        self.allowsFocusDuringEditing = builder()
        return self
    }
    @available(iOS 10.0, *)
    @discardableResult
    public func byPrefetchDataSource(_ builder: () -> UICollectionViewDataSourcePrefetching?) -> Self {
        self.prefetchDataSource = builder()
        return self
    }
    @available(iOS 10.0, *)
    @discardableResult
    public func byPrefetchingEnabled(_ builder: () -> Bool) -> Self {
        self.isPrefetchingEnabled = builder()
        return self
    }
    @available(iOS 11.0, *)
    @discardableResult
    public func byDragDelegate(_ builder: () -> UICollectionViewDragDelegate?) -> Self {
        self.dragDelegate = builder()
        return self
    }
    @available(iOS 11.0, *)
    @discardableResult
    public func byDropDelegate(_ builder: () -> UICollectionViewDropDelegate?) -> Self {
        self.dropDelegate = builder()
        return self
    }
    @available(iOS 11.0, *)
    @discardableResult
    public func byDragInteractionEnabled(_ builder: () -> Bool) -> Self {
        self.dragInteractionEnabled = builder()
        return self
    }
    @available(iOS 11.0, *)
    @discardableResult
    public func byReorderingCadence(_ builder: () -> UICollectionView.ReorderingCadence) -> Self {
        self.reorderingCadence = builder()
        return self
    }
    @available(iOS 16.0, *)
    @discardableResult
    public func bySelfSizingInvalidation(_ builder: () -> UICollectionView.SelfSizingInvalidation) -> Self {
        self.selfSizingInvalidation = builder()
        return self
    }
    @discardableResult
    public func byBackgroundView(_ builder: () -> UIView?) -> Self {
        self.backgroundView = builder()
        return self
    }
}

extension UICollectionView {
    // MARK: - 选择/取消选择
    @discardableResult
    public func bySelectItem(_ indexPath: IndexPath?,
                             animated: Bool = true,
                             scrollPosition: UICollectionView.ScrollPosition = []) -> Self {
        selectItem(at: indexPath, animated: animated, scrollPosition: scrollPosition)
        return self
    }

    @discardableResult
    public func byDeselectItem(_ indexPath: IndexPath, animated: Bool = true) -> Self {
        deselectItem(at: indexPath, animated: animated)
        return self
    }
}
/// UICollectionView@UICollectionViewLayout
extension UICollectionView {
    // MARK: - 切换布局（动画）
    @discardableResult
    public func bySetLayout(_ layout: UICollectionViewLayout, animated: Bool) -> Self {
        setCollectionViewLayout(layout, animated: animated)
        return self
    }
    // MARK: - iOS 7.0+ 切换布局（动画 + 完成回调）
    @available(iOS 7.0, *)
    @discardableResult
    public func bySetLayout(_ layout: UICollectionViewLayout,
                            animated: Bool,
                            completion: (jobsByBoolBlock)?) -> Self {
        setCollectionViewLayout(layout,
                                animated: animated,
                                completion: completion)
        return self
    }
}
/// 背景、Context_Menu@UICollectionView
extension UICollectionView {
    // MARK: - iOS 13.2+ ContextMenuInteraction 配置闭包
    @available(iOS 13.2, *)
    @discardableResult
    public func byContextMenuInteraction(_ config: (UIContextMenuInteraction) -> Void) -> Self {
        if let interaction = contextMenuInteraction {
            config(interaction)
        };return self
    }
}
/// 滚动、可视区域@UICollectionView
extension UICollectionView {
    @discardableResult
    public func byScrollToItem(_ indexPath: IndexPath,
                               at position: UICollectionView.ScrollPosition,
                               animated: Bool = true) -> Self {
        scrollToItem(at: indexPath, at: position, animated: animated)
        return self
    }
}
/// 更新、批量操作、交互式过渡_移动@UICollectionView
extension UICollectionView {
    @discardableResult
    public func byReloadData() -> Self {
        reloadData()
        return self
    }

    @discardableResult
    public func byPerformBatchUpdates(_ updates: (jobsByVoidBlock)?,
                                      completion: (jobsByBoolBlock)? = nil) -> Self {
        performBatchUpdates(updates, completion: completion)
        return self
    }
    // MARK: - Sections
    @discardableResult
    public func byInsertSections(_ sections: IndexSet) -> Self {
        insertSections(sections)
        return self
    }

    @discardableResult
    public func byDeleteSections(_ sections: IndexSet) -> Self {
        deleteSections(sections)
        return self
    }

    @discardableResult
    public func byMoveSection(_ from: Int, to: Int) -> Self {
        moveSection(from, toSection: to)
        return self
    }

    @discardableResult
    public func byReloadSections(_ sections: IndexSet) -> Self {
        reloadSections(sections)
        return self
    }
    // MARK: - Items
    @discardableResult
    public func byInsertItems(at indexPaths: [IndexPath]) -> Self {
        insertItems(at: indexPaths)
        return self
    }

    @discardableResult
    public func byDeleteItems(at indexPaths: [IndexPath]) -> Self {
        deleteItems(at: indexPaths)
        return self
    }

    @discardableResult
    public func byMoveItem(from: IndexPath, to: IndexPath) -> Self {
        moveItem(at: from, to: to)
        return self
    }

    @discardableResult
    public func byReloadItems(at indexPaths: [IndexPath]) -> Self {
        reloadItems(at: indexPaths)
        return self
    }
    // MARK: - iOS 15.0+ 重新配置（不重载）
    @available(iOS 15.0, *)
    @discardableResult
    public func byReconfigureItems(at indexPaths: [IndexPath]) -> Self {
        reconfigureItems(at: indexPaths)
        return self
    }
    // MARK: - iOS 7.0+ 交互式布局过渡
    @available(iOS 7.0, *)
    @discardableResult
    public func byStartInteractiveTransition(to layout: UICollectionViewLayout,
                                             completion: UICollectionView.LayoutInteractiveTransitionCompletion? = nil)
    -> UICollectionViewTransitionLayout {
        return startInteractiveTransition(to: layout, completion: completion)
    }
    // MARK: - iOS 7.0+ 完成交互式过渡
    @available(iOS 7.0, *)
    @discardableResult
    public func byFinishInteractiveTransition() -> Self {
        finishInteractiveTransition()
        return self
    }
    // MARK: - iOS 7.0+ 取消交互式过渡
    @available(iOS 7.0, *)
    @discardableResult
    public func byCancelInteractiveTransition() -> Self {
        cancelInteractiveTransition()
        return self
    }
    // MARK: - iOS 9.0+ 交互式移动（开始/更新/结束/取消）
    @available(iOS 9.0, *)
    @discardableResult
    public func byBeginInteractiveMovement(for indexPath: IndexPath) -> Bool {
        return beginInteractiveMovementForItem(at: indexPath)
    }

    @available(iOS 9.0, *)
    @discardableResult
    public func byUpdateInteractiveMovementTargetPosition(_ position: CGPoint) -> Self {
        updateInteractiveMovementTargetPosition(position)
        return self
    }

    @available(iOS 9.0, *)
    @discardableResult
    public func byEndInteractiveMovement() -> Self {
        endInteractiveMovement()
        return self
    }

    @available(iOS 9.0, *)
    @discardableResult
    public func byCancelInteractiveMovement() -> Self {
        cancelInteractiveMovement()
        return self
    }
}
