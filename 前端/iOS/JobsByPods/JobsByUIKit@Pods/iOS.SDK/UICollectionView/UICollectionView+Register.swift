//
//  UICollectionView+Register.swift
//  JobsByUIKit
//
//  Created by Jobs on 2026年5月13日，星期三.
//

#if os(OSX)
import AppKit
#elseif os(iOS) || os(tvOS)
import UIKit
#endif

/// UICollectionView、UICollectionViewCell、UICollectionReusableView@注册

extension UICollectionView {
    // MARK: - register@Cell（Nib）
    /// 按类名从 Nib 注册 Cell
    /// - Parameter cellClass: `UICollectionViewCell` 子类
    /// - Returns: self（便于链式调用）
    @discardableResult
    public func byRegisterCellNib<T: UICollectionViewCell>(_ cellClass: T.Type) -> Self {
        register(
            UINib(nibName: String(describing: cellClass), bundle: nil),
            forCellWithReuseIdentifier: String(describing: cellClass)
        );return self
    }
    // MARK: - register@Cell（Class）
    /// 按类名注册 Cell（Class）
    /// - Parameter cellClass: `UICollectionViewCell` 子类
    /// - Returns: self
    @discardableResult
    public func byRegisterCell<T: UICollectionViewCell>(_ cellClass: T.Type) -> Self {
        register(cellClass, forCellWithReuseIdentifier: String(describing: cellClass))
        return self
    }
    // MARK: - register@Cell（Class with ID）
    /// 指定复用 ID 注册 Cell（Class）
    /// - Parameters:
    ///   - cellClass: `UICollectionViewCell` 子类
    ///   - reuseID: 自定义复用标识
    /// - Returns: self
    @discardableResult
    public func byRegisterCell<T: UICollectionViewCell>(_ cellClass: T.Type, reuseID: String) -> Self {
        register(cellClass, forCellWithReuseIdentifier: reuseID)
        return self
    }
    // MARK: - register@Cell（Nib with ID）
    /// 指定复用 ID 注册 Cell（Nib）
    /// - Parameters:
    ///   - cellClass: `UICollectionViewCell` 子类
    ///   - reuseID: 自定义复用标识
    /// - Returns: self
    @discardableResult
    public func byRegisterCellNib<T: UICollectionViewCell>(_ cellClass: T.Type, reuseID: String) -> Self {
        register(
            UINib(nibName: String(describing: cellClass), bundle: nil),
            forCellWithReuseIdentifier: reuseID
        );return self
    }
    // MARK: - register@Cell（Class）
    /// 按类名注册 Cell（Class）
    /// - Parameter cellClassType: `UICollectionViewCell` 子类类型
    @discardableResult
    public func byRegister(cellClassType: UICollectionViewCell.Type) -> Self {
        register(
            cellClassType.classForCoder(),
            forCellWithReuseIdentifier: cellClassType.className
        );return self
    }
    // MARK: - register@Cell（Nib）
    /// 按类名从 Nib 注册 Cell
    /// - Parameter cellNibType: `UICollectionViewCell` 子类类型
    @discardableResult
    public func byRegister(cellNibType: UICollectionViewCell.Type) -> Self {
        register(
            UINib(nibName: cellNibType.className, bundle: nil),
            forCellWithReuseIdentifier: cellNibType.className
        );return self
    }
    // MARK: - register@SupplementaryView（Class）
    /// 注册 SupplementaryView（Class）
    /// - Parameters:
    ///   - viewClass: `UICollectionReusableView` 子类
    ///   - kind: 视图类型（如 `UICollectionView.elementKindSectionHeader`）
    /// - Returns: self
    @discardableResult
    public func byRegisterSupplementaryView<T: UICollectionReusableView>(_ viewClass: T.Type, kind: String) -> Self {
        register(
            viewClass,
            forSupplementaryViewOfKind: kind,
            withReuseIdentifier: String(describing: viewClass)
        );return self
    }
    // MARK: - register@SupplementaryView（Nib）
    /// 注册 SupplementaryView（Nib）
    /// - Parameters:
    ///   - viewClass: `UICollectionReusableView` 子类
    ///   - kind: 视图类型（如 `UICollectionView.elementKindSectionHeader`）
    /// - Returns: self
    @discardableResult
    public func byRegisterSupplementaryNib<T: UICollectionReusableView>(_ viewClass: T.Type, kind: String) -> Self {
        register(
            UINib(nibName: String(describing: viewClass), bundle: nil),
            forSupplementaryViewOfKind: kind,
            withReuseIdentifier: String(describing: viewClass)
        );return self
    }
    // MARK: - register@Header（Class）
    /// py_ 注册 Header（Class）
    /// - Parameter headerViewClassType: `UICollectionReusableView` 子类
    @discardableResult
    public func byRegisterHeaderView(headerViewClassType: UICollectionReusableView.Type) -> Self {
        register(
            headerViewClassType.classForCoder(),
            forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
            withReuseIdentifier: headerViewClassType.className
        );return self
    }
    // MARK: - register@Header（Nib）
    /// 注册 Header（Nib）
    /// - Parameter headerViewNibType: `UICollectionReusableView` 子类
    @discardableResult
    public func byRegisterHeaderView(headerViewNibType: UICollectionReusableView.Type) -> Self {
        register(
            UINib(nibName: headerViewNibType.className, bundle: nil),
            forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
            withReuseIdentifier: headerViewNibType.className
        );return self
    }
    // MARK: - register@Footer（Class）
    /// 注册 Footer（Class）
    /// - Parameter footerViewClassType: `UICollectionReusableView` 子类
    @discardableResult
    public func byRegisterFooterView(footerViewClassType: UICollectionReusableView.Type) -> Self {
        register(
            footerViewClassType.classForCoder(),
            forSupplementaryViewOfKind: UICollectionView.elementKindSectionFooter,
            withReuseIdentifier:  footerViewClassType.className
        );return self
    }
    // MARK: - register@Footer（Nib）
    /// 注册 Footer（Nib）
    /// - Parameter footerViewNibType: `UICollectionReusableView` 子类
    @discardableResult
    public func byRegisterFooterView(footerViewNibType: UICollectionReusableView.Type) -> Self {
        register(
            UINib(nibName: footerViewNibType.className, bundle: nil),
            forSupplementaryViewOfKind: UICollectionView.elementKindSectionFooter,
            withReuseIdentifier: footerViewNibType.className
        );return self
    }
}
