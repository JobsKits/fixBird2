//
//  UITableView+DequeueReusable.swift
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
import JobsSwiftDSL

// MARK: - 🍬语法糖@复用
private var st_registeredCellIdsKey: UInt8 = 0
private var st_registeredHeaderFooterIdsKey: UInt8 = 0
extension UITableView {
    private var st_registeredCellIds: Set<String> {
        get { (objc_getAssociatedObject(self, &st_registeredCellIdsKey) as? Set<String>) ?? [] }
        set {
            objc_setAssociatedObject(
                self,
                &st_registeredCellIdsKey,
                newValue,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
        }
    }

    private var st_registeredHeaderFooterIds: Set<String> {
        get { (objc_getAssociatedObject(self, &st_registeredHeaderFooterIdsKey) as? Set<String>) ?? [] }
        set {
            objc_setAssociatedObject(
                self,
                &st_registeredHeaderFooterIdsKey,
                newValue,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
        }
    }
}

extension UITableView {
    /// 快捷复用@UITableViewCell
    @discardableResult
    public func byDequeueReusableCell<T: UITableViewCell>(withType cellType: T.Type, for indexPath: IndexPath) -> T {
        let reuseId = cellType.className
        if !st_registeredCellIds.contains(reuseId) {
            byRegisterCell(cellType)
            st_registeredCellIds.insert(reuseId)
        };return self.dequeueReusableCell(withIdentifier: reuseId, for: indexPath) as! T
    }
    /// 快捷复用@UITableViewHeaderFooterView
    ///
    /// ⚠️ 重要说明：
    /// `dequeueReusableHeaderFooterView(withIdentifier:) == nil`
    ///
    /// 并不代表没有 register。
    ///
    /// 它只代表：
    /// 当前复用池中没有“闲置”的可复用实例。
    ///
    /// 即使已经 register，只要：
    /// - 当前没有可复用对象
    /// - 或首次使用
    /// - 或复用池为空
    ///
    /// 仍然会返回 nil。
    ///
    /// 因此：
    /// ❌ 绝对不要用 dequeue == nil 来判断是否 register
    /// 否则会破坏复用机制，导致重复创建 view。
    ///
    /// 正确做法是：
    /// 自行记录 register 状态，而不是探测 dequeue。
    ///
    /// Apple 文档行为设计如此，并非 bug。
    @discardableResult
    public func byDequeueReusableHeaderFooterView<T: UITableViewHeaderFooterView>(
        headerFooterViewWithType type: T.Type
    ) -> T {
        let reuseId = type.className
        guard st_registeredHeaderFooterIds.contains(reuseId) else {
            byRegister(headerFooterViewClassType: type)
            st_registeredHeaderFooterIds.insert(reuseId)
            // 注册完直接 dequeue
            guard let view = dequeueReusableHeaderFooterView(withIdentifier: reuseId) as? T else {
                fatalError("❌ dequeueReusableHeaderFooterView failed after register: \(reuseId)")
            };return view
        }
        guard let view = dequeueReusableHeaderFooterView(withIdentifier: reuseId) as? T else {
            fatalError("❌ dequeueReusableHeaderFooterView failed: \(reuseId)")
        };return view
    }
}
