//
//  UITableView+Register.swift
//  JobsByUIKit
//
//  Created by Jobs on 2026年5月13日，星期三.
//

#if os(OSX)
import AppKit
#elseif os(iOS) || os(tvOS)
import UIKit
#endif

// MARK: - 🍬语法糖@注册：UITableViewCell、HeaderFooterView、HeaderFooterView
extension UITableView {
    /// 通用注册@类名（类名自己为🆔）
    @discardableResult
    public func byRegister(cellClassType: UITableViewCell.Type) -> Self {
        self.register(
            cellClassType.classForCoder(),
            forCellReuseIdentifier: cellClassType.className
        );return self
    }
    /// 注册UITableViewCell@Nib
    @discardableResult
    public func byRegister(cellNibType: UITableViewCell.Type) -> Self {
        self.register(
            UINib(nibName: cellNibType.className, bundle: nil),
            forCellReuseIdentifier: cellNibType.className
        );return self
    }
    /// 注册UITableViewHeaderFooterView@类名
    @discardableResult
    public func byRegister(headerFooterViewClassType: UIView.Type) -> Self {
        self.register(
            headerFooterViewClassType.classForCoder(),
            forHeaderFooterViewReuseIdentifier: headerFooterViewClassType.className
        );return self
    }
    /// 注册UITableViewHeaderFooterView@Nib
    @discardableResult
    public func byRegister(headerFooterViewNibType: UIView.Type) -> Self {
        self.register(
            UINib(nibName: headerFooterViewNibType.className, bundle: nil),
            forHeaderFooterViewReuseIdentifier: headerFooterViewNibType.className
        );return self
    }
}
// MARK: - 🍬语法糖@注册：UITableViewCell
extension UITableView {
    /// 注册UITableViewCell@（类名自己为🆔）
    @discardableResult
    public func byRegisterCell<T: UITableViewCell>(_ cellClass: T.Type) -> Self {
        self.register(cellClass, forCellReuseIdentifier: String(describing: cellClass))
        return self
    }
    /// 注册UITableViewCell@类名和🆔
    @discardableResult
    public func byRegisterCellOnID<T: UITableViewCell>(CellCls cellClass: T.Type,ID id:String) -> Self {
        self.register(cellClass, forCellReuseIdentifier: id)
        return self
    }
}
