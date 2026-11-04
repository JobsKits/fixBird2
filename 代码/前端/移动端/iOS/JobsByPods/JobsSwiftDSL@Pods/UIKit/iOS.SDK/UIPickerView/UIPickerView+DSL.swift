//
//  UIPickerView+DSL.swift
//  JobsSwiftDSL
//
//  Created by Jobs on 2026年8月3日，星期一.
//

#if os(OSX)
import AppKit
#elseif os(iOS) || os(tvOS)
import UIKit
#endif

#if os(iOS) || os(tvOS)
extension UIPickerView {
    @discardableResult
    public func byDelegate(_ delegate: UIPickerViewDelegate?) -> Self {
        self.delegate = delegate
        return self
    }

    @discardableResult
    public func byDataSource(_ dataSource: UIPickerViewDataSource?) -> Self {
        self.dataSource = dataSource
        return self
    }

    @discardableResult
    public func byShowsSelectionIndicator(_ shows: Bool) -> Self {
        showsSelectionIndicator = shows
        return self
    }

    @discardableResult
    public func bySelectRow(_ row: Int, inComponent component: Int, animated: Bool) -> Self {
        selectRow(row, inComponent: component, animated: animated)
        return self
    }

    @discardableResult
    public func byReloadAllComponents() -> Self {
        reloadAllComponents()
        return self
    }

    @discardableResult
    public func byReloadComponent(_ component: Int) -> Self {
        reloadComponent(component)
        return self
    }
}
#endif
