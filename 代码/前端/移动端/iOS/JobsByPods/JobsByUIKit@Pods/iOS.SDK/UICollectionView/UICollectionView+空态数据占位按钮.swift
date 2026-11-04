//
//  UICollectionView+空态数据占位按钮.swift
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
import JobsSwiftDSL
import JobsSwiftBaseDefines

// MARK: - UICollectionView@空数据源占位图
/// 被交换的方法实现（调用原方法后自动评估空态）
extension UICollectionView {
    @objc dynamic
    public func jobs_swizzled_reloadData() {
        // 交换后，此处调用的是“原始 reloadData”
        jobs_swizzled_reloadData()
        onMainSync{ [weak self] in
            guard let self else { return }
            (self as UIScrollView).byReloadEmptyViewAuto()  // 你的评估逻辑
        }
    }

    @objc dynamic
    public func jobs_swizzled_performBatchUpdates(
        _ updates: (jobsByVoidBlock)?,
        completion: (jobsByBOOLBlock)?) {
        jobs_swizzled_performBatchUpdates(updates) { [weak self] finished in
            onMainSync { [weak self] in
                guard let self else { return }
                (self as UIScrollView).byReloadEmptyViewAuto()
            };completion?(finished)
        }
    }
}
