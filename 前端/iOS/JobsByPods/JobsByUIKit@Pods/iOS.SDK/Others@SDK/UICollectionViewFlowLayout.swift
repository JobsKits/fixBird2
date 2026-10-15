//
//  UICollectionViewFlowLayout.swift
//  JobsByUIKit
//
//  Created by Jobs on 2026年5月13日，星期三.
//

#if os(OSX)
import AppKit
#elseif os(iOS) || os(tvOS)
import UIKit
#endif

extension UICollectionViewFlowLayout {
    // MARK: - Spacing
    @discardableResult
    /// 设置 UICollectionViewFlowLayout 的 minimumLineSpacing（“行间距/主轴相邻组之间的间距”）
    ///
    /// - Important:
    ///   minimumLineSpacing 的方向取决于 scrollDirection：
    ///
    ///   1) scrollDirection = .vertical（默认：纵向滚动）
    ///      - “行”是水平排列的一行 items
    ///      - minimumLineSpacing 表示 **行与行之间的垂直间距（上下）**
    ///
    ///   2) scrollDirection = .horizontal（横向滚动）
    ///      - “行”可以理解为竖着的一列 items
    ///      - minimumLineSpacing 表示 **列与列之间的水平间距（左右）**
    ///
    /// - Parameter value: 间距值（points）
    /// - Returns: Self（便于链式调用）
    public func byMinimumLineSpacing(_ value: CGFloat) -> Self {
        self.minimumLineSpacing = value
        return self
    }

    @discardableResult
    /// 设置 UICollectionViewFlowLayout 的 minimumInteritemSpacing（“同一行/列内 item 之间的间距”）
    ///
    /// - Important:
    ///   minimumInteritemSpacing 的方向同样取决于 scrollDirection：
    ///
    ///   1) scrollDirection = .vertical（默认：纵向滚动）
    ///      - 表示 **同一行内 items 的水平间距（左右）**
    ///
    ///   2) scrollDirection = .horizontal（横向滚动）
    ///      - 表示 **同一列内 items 的垂直间距（上下）**
    ///
    /// - Parameter value: 间距值（points）
    /// - Returns: Self（便于链式调用）
    public func byMinimumInteritemSpacing(_ value: CGFloat) -> Self {
        self.minimumInteritemSpacing = value
        return self
    }
    // MARK: - Item Size
    @discardableResult
    public func byItemSize(_ size: CGSize) -> Self {
        self.itemSize = size
        return self
    }
    /// iOS 8+: 估算尺寸（配合 Auto Layout 自适应）
    @available(iOS 8.0, *)
    @discardableResult
    public func byEstimatedItemSize(_ size: CGSize) -> Self {
        self.estimatedItemSize = size
        return self
    }
    /// 快捷：开启 Auto Layout 自适应（estimatedItemSize = automaticSize）
    @available(iOS 8.0, *)
    @discardableResult
    public func byAutomaticEstimatedItemSize() -> Self {
        self.estimatedItemSize = UICollectionViewFlowLayout.automaticSize
        return self
    }
    // MARK: - Scroll Direction
    @discardableResult
    public func byScrollDirection(_ direction: UICollectionView.ScrollDirection) -> Self {
        self.scrollDirection = direction
        return self
    }
    // MARK: - Header / Footer
    @discardableResult
    public func byHeaderReferenceSize(_ size: CGSize) -> Self {
        self.headerReferenceSize = size
        return self
    }

    @discardableResult
    public func byFooterReferenceSize(_ size: CGSize) -> Self {
        self.footerReferenceSize = size
        return self
    }
    // MARK: - Section Insets
    @discardableResult
    public func bySectionInset(_ inset: UIEdgeInsets) -> Self {
        self.sectionInset = inset
        return self
    }
    /// iOS 11+: inset 参考系
    @available(iOS 11.0, *)
    @discardableResult
    public func bySectionInsetReference(_ ref: UICollectionViewFlowLayout.SectionInsetReference) -> Self {
        self.sectionInsetReference = ref
        return self
    }
    // MARK: - Pin to visible bounds
    /// iOS 9+: 头部吸顶
    @available(iOS 9.0, *)
    @discardableResult
    public func byHeadersPinToVisibleBounds(_ pin: Bool) -> Self {
        self.sectionHeadersPinToVisibleBounds = pin
        return self
    }
    /// iOS 9+: 尾部吸底
    @available(iOS 9.0, *)
    @discardableResult
    public func byFootersPinToVisibleBounds(_ pin: Bool) -> Self {
        self.sectionFootersPinToVisibleBounds = pin
        return self
    }
    // MARK: - Helpers
    /// 按列数计算 itemSize（竖向滚动常用）
    /// - Parameters:
    ///   - columns: 列数（>=1）
    ///   - containerWidth: 容器宽度（collectionView.bounds.width）
    ///   - height: 固定高度（或你算好的高度）
    ///   - extraHorizontalInset: 额外左右内边距（除去 sectionInset 外的，比如 contentInset 或你想预留的边距）
    @discardableResult
    public func byGrid(columns: Int,
                containerWidth: CGFloat,
                height: CGFloat,
                extraHorizontalInset: CGFloat = 0) -> Self {
        guard columns > 0 else { return self }
        let totalInset = sectionInset.left + sectionInset.right + extraHorizontalInset
        let totalSpacing = minimumInteritemSpacing * CGFloat(max(columns - 1, 0))
        let w = floor((containerWidth - totalInset - totalSpacing) / CGFloat(columns))
        self.itemSize = CGSize(width: w, height: height)
        return self
    }
    /// 快捷：常见的卡片列表预设
    /// - oneLineSpacing: 行间距；- interitemSpacing: 列间距；- inset: 分区内边距
    @discardableResult
    public func byPresetCardList(oneLineSpacing: CGFloat = 10,
                          interitemSpacing: CGFloat = 10,
                          inset: UIEdgeInsets = .init(top: 10, left: 12, bottom: 10, right: 12)) -> Self {
        self.minimumLineSpacing = oneLineSpacing
        self.minimumInteritemSpacing = interitemSpacing
        self.sectionInset = inset
        return self
    }
    /// 一键开启「列表样式 + Header 吸顶」
    @available(iOS 9.0, *)
    @discardableResult
    public func byListWithPinnedHeader(_ headerHeight: CGFloat) -> Self {
        self.scrollDirection = .vertical
        self.headerReferenceSize = .init(width: 0, height: headerHeight)
        self.sectionHeadersPinToVisibleBounds = true
        return self
    }
}
