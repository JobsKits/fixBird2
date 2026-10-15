//
//  UITableView+校验.swift
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

//let cell = tableView[section: 0, row: 3]
extension UITableView {
    /// 校验 IndexPath 是否在当前 tableView 的有效范围内
    private func isValid(indexPath: IndexPath) -> Bool {
        let section = indexPath.section
        let row = indexPath.row
        guard section >= 0, row >= 0 else { return false }
        guard section < numberOfSections else { return false }
        guard row < numberOfRows(inSection: section) else { return false };return true
    }
    /// 通过 IndexPath 安全获取 cell：越界 / 不存在 返回 nil
    public subscript(safe indexPath: IndexPath) -> UITableViewCell? {
        guard isValid(indexPath: indexPath) else { return nil };return cellForRow(at: indexPath)
    }
    /// 通过 section / row 安全获取 cell：越界 / 不存在 返回 nil
    public subscript(section s: Int, row r: Int) -> UITableViewCell? {
        let indexPath = IndexPath(row: r, section: s)
        return self[safe: indexPath]
    }
}
