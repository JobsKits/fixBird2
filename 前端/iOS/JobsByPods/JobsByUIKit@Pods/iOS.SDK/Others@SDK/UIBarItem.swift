//
//  UIBarItem.swift
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
import JobsSwiftDSL

// MARK: - 链式：通用属性
extension UIBarItem {
    @discardableResult
    public func byEnabled(_ value: Bool) -> Self {
        self.isEnabled = value
        return self
    }

    @discardableResult
    public func byTitle(_ value: String?) -> Self {
        self.title = value
        return self
    }

    @discardableResult
    public func byImage(_ value: UIImage?) -> Self {
        self.image = value
        return self
    }
    /// 支持 SF Symbols
    @available(iOS 13.0, *)
    @discardableResult
    public func byImage(systemName: String, configuration: UIImage.Configuration? = nil) -> Self {
        if let cfg = configuration {
            self.image = UIImage(systemName: systemName, withConfiguration: cfg)
        } else {
            self.image = systemName.sysImg
        };return self
    }

    @discardableResult
    public func byImageInsets(_ value: UIEdgeInsets) -> Self {
        self.imageInsets = value
        return self
    }

    @discardableResult
    public func byTag(_ value: Int) -> Self {
        self.tag = value
        return self
    }
}
// MARK: - 链式：iOS 5+ landscapeImagePhone / landscapeImagePhoneInsets
extension UIBarItem {
    @available(iOS 5.0, *)
    @discardableResult
    public func byLandscapeImagePhone(_ value: UIImage?) -> Self {
        self.landscapeImagePhone = value
        return self
    }

    @available(iOS 5.0, *)
    @discardableResult
    public func byLandscapeImagePhoneInsets(_ value: UIEdgeInsets) -> Self {
        self.landscapeImagePhoneInsets = value
        return self
    }
}
// MARK: - 链式：iOS 11+ large content image
extension UIBarItem {
    @available(iOS 11.0, *)
    @discardableResult
    public func byLargeContentSizeImage(_ value: UIImage?) -> Self {
        self.largeContentSizeImage = value
        return self
    }

    @available(iOS 11.0, *)
    @discardableResult
    public func byLargeContentSizeImageInsets(_ value: UIEdgeInsets) -> Self {
        self.largeContentSizeImageInsets = value
        return self
    }
}
// MARK: - 链式：Title Text Attributes（按状态）
extension UIBarItem {
    /// 直接设置 attributes
    @available(iOS 5.0, *)
    @discardableResult
    public func byTitleTextAttributes(_ attrs: [NSAttributedString.Key: Any]?,
                               for state: UIControl.State = .normal) -> Self {
        self.setTitleTextAttributes(attrs, for: state)
        return self
    }
    /// 便捷：仅设置字体
    @available(iOS 5.0, *)
    @discardableResult
    public func byTitleFont(_ font: UIFont, for state: UIControl.State = .normal) -> Self {
        var attrs = self.titleTextAttributes(for: state) ?? [:]
        attrs[.font] = font
        self.setTitleTextAttributes(attrs, for: state)
        return self
    }
    /// 便捷：仅设置颜色
    @available(iOS 5.0, *)
    @discardableResult
    public func byTitleColor(_ color: UIColor, for state: UIControl.State = .normal) -> Self {
        var attrs = self.titleTextAttributes(for: state) ?? [:]
        attrs[.foregroundColor] = color
        self.setTitleTextAttributes(attrs, for: state)
        return self
    }
    /// 便捷：合并 attributes（保留已有，新的覆盖同 key）
    @available(iOS 5.0, *)
    @discardableResult
    public func byMergeTitleTextAttributes(_ attrs: [NSAttributedString.Key: Any],
                                    for state: UIControl.State = .normal) -> Self {
        var merged = self.titleTextAttributes(for: state) ?? [:]
        attrs.forEach { merged[$0.key] = $0.value }
        self.setTitleTextAttributes(merged, for: state)
        return self
    }
    /// 批量复制某个状态的 attributes 到多个状态
    @available(iOS 5.0, *)
    @discardableResult
    public func byCopyTitleTextAttributes(from src: UIControl.State = .normal,
                                   to targets: [UIControl.State] = [.highlighted, .disabled, .focused, .selected]) -> Self {
        let attrs = self.titleTextAttributes(for: src)
        targets.forEach { self.setTitleTextAttributes(attrs, for: $0) };return self
    }
}
// MARK: - 使用示例
/*
let item1 = UIBarButtonItem(systemItem: .add)
    .byTitle("添加")
    .byEnabled(true)
    .byImage(systemName: "plus.circle")
    .byImageInsets(.init(top: 0, left: 4, bottom: 0, right: -4))
    .byTag(100)
    .byTitleFont(JobsFont.systemFont(ofSize: 15, weight: .medium))
    .byTitleColor(JobsCor.systemBlue)
    .byCopyTitleTextAttributes(from: .normal)

let tabItem = UITabBarItem(title: "首页",
                           image: UIImage(systemName: "house"),
                           selectedImage: UIImage(systemName: "house.fill"))
    .byTitleColor(.secondaryLabel, for: .normal)
    .byTitleColor(.label, for: .selected)

if #available(iOS 11.0, *) {
    _ = item1
        .byLargeContentSizeImage(UIImage(systemName: "plus.circle"))
        .byLargeContentSizeImageInsets(.init(top: 2, left: 2, bottom: 2, right: 2))
}

if #available(iOS 5.0, *) {
    _ = item1
        .byLandscapeImagePhone(UIImage(systemName: "plus"))
        .byLandscapeImagePhoneInsets(.zero)
}
*/
