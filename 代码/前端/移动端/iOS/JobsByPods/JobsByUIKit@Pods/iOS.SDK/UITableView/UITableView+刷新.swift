//
//  UITableView+刷新.swift
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
import JobsSwiftBaseDefines

extension UITableView {
    // MARK: - 全量刷新
    @discardableResult
    public func reloadDatas() -> Self {
        /// 回调到主线程刷新
        onMainAsync { [weak self] in
            self?.reloadData()
        };return self
    }
    // MARK: - 刷新指定 IndexPath 的 cell（单个/多个）
    @discardableResult
    public func reloadCell(at indexPath: IndexPath,
                           animation: UITableView.RowAnimation = .none) -> Self {
        return reloadCells(at: [indexPath], animation: animation)
    }

    @discardableResult
    public func reloadCells(at indexPaths: [IndexPath],
                            animation: UITableView.RowAnimation = .none) -> Self {
        onMainAsync { [weak self] in
            guard let self else { return }
            guard !indexPaths.isEmpty else { return }
            // 防止越界导致崩溃
            let safe = indexPaths.filter {
                $0.section >= 0 && $0.section < self.numberOfSections &&
                $0.row >= 0 && $0.row < self.numberOfRows(inSection: $0.section)
            }
            guard !safe.isEmpty else { return }
            self.reloadRows(at: safe, with: animation)
        };return self
    }
    // MARK: - 传入 section:Int 刷新该 section 下的全部 cell
    @discardableResult
    public func reloadSection(_ section: Int,
                              animation: UITableView.RowAnimation = .none) -> Self {
        onMainAsync { [weak self] in
            guard let self else { return }
            guard section >= 0 && section < self.numberOfSections else { return }
            self.reloadSections(IndexSet(integer: section), with: animation)
        };return self
    }
    // MARK: - 刷新多个 sections
    @discardableResult
    public func reloadSections(_ sections: [Int],
                               animation: UITableView.RowAnimation = .none) -> Self {
        onMainAsync { [weak self] in
            guard let self else { return }
            guard !sections.isEmpty else { return }
            let safe = sections.filter { $0 >= 0 && $0 < self.numberOfSections }
            guard !safe.isEmpty else { return }
            self.reloadSections(IndexSet(safe), with: animation)
        };return self
    }
}
