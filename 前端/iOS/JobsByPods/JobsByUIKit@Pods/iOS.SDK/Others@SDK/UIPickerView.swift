//
//  UIPickerView.swift
//  JobsByUIKit
//
//  Created by Jobs on 2026年5月13日，星期三.
//

#if os(OSX)
import AppKit
#elseif os(iOS) || os(tvOS)
import UIKit
#endif

extension UIPickerView {
    @discardableResult
    public func byDelegate(_ delegate: UIPickerViewDelegate) -> Self {
        self.delegate = delegate
        return self
    }

    @discardableResult
    public func byDataSource(_ dataSource: UIPickerViewDataSource) -> Self {
        self.dataSource = dataSource
        return self
    }

    @discardableResult
    public func selectRowByAnimated(_ row: Int, inComponent component: Int) -> Self {
        self.selectRow(row, inComponent: component, animated: true)
        return self
    }

    @discardableResult
    public func reloadAllComponentsBy() -> Self {
        self.reloadAllComponents()
        return self
    }

    @discardableResult
    public func reloadComponentBy(_ component: Int) -> Self {
        self.reloadComponent(component)
        return self
    }
}
