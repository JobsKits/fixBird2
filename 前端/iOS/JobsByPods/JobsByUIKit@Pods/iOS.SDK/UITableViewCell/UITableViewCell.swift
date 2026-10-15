//
//  UITableViewCell.swift
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

// MARK: - 工厂：按样式创建（便于老系统 detailTextLabel 显示）
extension UITableViewCell {
    /// 便捷工厂：指定 CellStyle 与复用 ID
    public static func make(style: UITableViewCell.CellStyle = .default,
                            reuseIdentifier: String? = nil) -> UITableViewCell {
        UITableViewCell(style: style, reuseIdentifier: reuseIdentifier ?? String(describing: self))
    }
}

@available(iOS 14.0, tvOS 14.0, *)
extension UITableViewCell {
    /// 以链式闭包方式配置并设置 `contentConfiguration`
    @discardableResult
    public func byListConfig(_ builder: JobsRetByListContentConfigBlock) -> Self {
        let base = (contentConfiguration as? UIListContentConfiguration) ?? .cell()
        contentConfiguration = builder(base)
        return self
    }
}
