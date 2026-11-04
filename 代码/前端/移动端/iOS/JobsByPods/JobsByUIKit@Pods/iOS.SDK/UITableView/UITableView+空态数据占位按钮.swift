//
//  UITableView+空态数据占位按钮.swift
//  JobsByUIKit
//
//  Created by Jobs on 2026年5月13日，星期三.
//

#if os(OSX)
import AppKit
#elseif os(iOS) || os(tvOS)
import UIKit
#endif

import JobsSwiftBaseDefines

// MARK: - UITableView@空数据源占位图
/// 被交换的方法实现（调用原方法后自动评估空态）
extension UITableView {
    @objc dynamic
    public func jobs_swizzled_reloadData() {
        self.jobs_swizzled_reloadData()        // 原始实现
        onMainAsync { [weak self] in
            guard let self else { return }
            (self as UIScrollView)._jobs_autoEnsureEmptyButtonThenEval()
        }
    }
}
