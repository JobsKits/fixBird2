//
//  UICollectionViewCell.swift
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
import JobsSwiftBlock
import JobsSwiftDSL

// MARK: - 直接赋值@单参数
extension UICollectionViewCell {
    // MARK: - autoUpdate@Configuration (iOS 14+)
    /// iOS14+: 是否自动根据状态更新 contentConfiguration
    @available(iOS 14.0, *)
    @discardableResult
    public func byAutomaticallyUpdatesContentConfiguration(_ on: Bool) -> Self {
        self.automaticallyUpdatesContentConfiguration = on
        return self
    }
    /// iOS14+: 是否自动根据状态更新 backgroundConfiguration
    @available(iOS 14.0, *)
    @discardableResult
    public func byAutomaticallyUpdatesBackgroundConfiguration(_ on: Bool) -> Self {
        self.automaticallyUpdatesBackgroundConfiguration = on
        return self
    }
    // MARK: - backgroundView / selectedBackgroundView
    /// 普通背景视图
    @discardableResult
    public func byBackgroundView(_ view: UIView?) -> Self {
        self.backgroundView = view
        return self
    }
    /// 选中态背景视图
    @discardableResult
    public func bySelectedBackgroundView(_ view: UIView?) -> Self {
        self.selectedBackgroundView = view
        return self
    }
}
// MARK: - 闭包重载@单参数
extension UICollectionViewCell {
    @available(iOS 14.0, *)
    @discardableResult
    public func byAutomaticallyUpdatesContentConfiguration(_ builder: () -> Bool) -> Self {
        self.automaticallyUpdatesContentConfiguration = builder()
        return self
    }
    @available(iOS 14.0, *)
    @discardableResult
    public func byAutomaticallyUpdatesBackgroundConfiguration(_ builder: () -> Bool) -> Self {
        self.automaticallyUpdatesBackgroundConfiguration = builder()
        return self
    }
    @discardableResult
    public func byBackgroundView(_ builder: () -> UIView?) -> Self {
        self.backgroundView = builder()
        return self
    }
    @discardableResult
    public func bySelectedBackgroundView(_ builder: () -> UIView?) -> Self {
        self.selectedBackgroundView = builder()
        return self
    }
}

extension UICollectionViewCell {
    // MARK: - state@selected / highlighted
    /// 选中状态（可选动画）
    @discardableResult
    public func bySelected(_ selected: Bool, animated: Bool = false) -> Self {
        // 没有 setSelected(_:animated:) 接口，直接赋值 + 可选动画过渡
        if animated {
            UIView.transition(with: contentView,
                              duration: 0.2,
                              options: .transitionCrossDissolve) {
                self.isSelected = selected
            }
        } else {
            self.isSelected = selected
        };return self
    }
    /// 高亮状态（可选动画）
    @discardableResult
    public func byHighlighted(_ highlighted: Bool, animated: Bool = false) -> Self {
        if animated {
            UIView.transition(with: contentView,
                              duration: 0.15,
                              options: .transitionCrossDissolve) {
                self.isHighlighted = highlighted
            }
        } else {
            self.isHighlighted = highlighted
        };return self
    }
    // MARK: - autoUpdate@Configuration (iOS 14+)
    /// iOS14+: 主内容配置（UIListContentConfiguration）
    @available(iOS 14.0, *)
    @discardableResult
    public func byContentConfiguration(_ build: (inout UIListContentConfiguration) -> Void,
                                       automaticallyUpdates: Bool = false) -> Self {
        // UICollectionViewCell 没有 defaultContentConfiguration；
        // UICollectionViewListCell 才有。做个兜底：
        var cfg = (self as? UICollectionViewListCell)?.defaultContentConfiguration()
                  ?? UIListContentConfiguration.cell()      // ✅ 通用基准
        build(&cfg)
        self.automaticallyUpdatesContentConfiguration = automaticallyUpdates
        self.contentConfiguration = cfg
        return self
    }
    /// iOS14+: 背景配置（UIBackgroundConfiguration）
    @available(iOS 14.0, *)
    @discardableResult
    public func byBackgroundConfiguration(_ build: jobsByInoutBackgroundConfigurationBlock,
                                          automaticallyUpdates: Bool = false) -> Self {
        var bg = UIBackgroundConfiguration.listPlainCell()
        build(&bg)
        self.automaticallyUpdatesBackgroundConfiguration = automaticallyUpdates
        self.backgroundConfiguration = bg
        return self
    }
    // MARK: - dragState (iOS 11+)
    /// 手动触发拖拽状态 didChange（通常系统回调即可，很少需要手动）
    @available(iOS 11.0, *)
    @discardableResult
    public func byNotifyDragStateDidChange(_ state: UICollectionViewCell.DragState) -> Self {
        self.dragStateDidChange(state)
        return self
    }
    // MARK: - convenience@shortcuts (iOS 14+)
    /// iOS14+: 快捷设置文本 / 副标题 / 图片
    @available(iOS 14.0, *)
    @discardableResult
    public func byListContent(text: String? = nil,
                              secondaryText: String? = nil,
                              image: UIImage? = nil,
                              config: (jobsByInoutListContentConfigBlock)? = nil) -> Self {
        return byContentConfiguration { cfg in
            cfg.text = text
            cfg.secondaryText = secondaryText
            cfg.image = image
            config?(&cfg)
        }
    }
    /// iOS14+: 快捷设置背景色（普通 & 选中）
    @available(iOS 14.0, *)
    @discardableResult
    public func byListBackground(normal: UIColor? = nil,
                                 selected: UIColor? = nil) -> Self {
        if let normal {
            _ = byBackgroundConfiguration { bg in
                bg.backgroundColor = normal
            }
        }
        if let selected {
            self.selectedBackgroundView = UIView().byBackgroundColor(selected)
        };return self
    }
    // MARK: - invalidate@Configuration (iOS 14+)
    /// iOS14+: 请求按当前状态更新配置（系统会合并请求时机）
    @available(iOS 14.0, *)
    @discardableResult
    public func bySetNeedsUpdateConfiguration() -> Self {
        self.setNeedsUpdateConfiguration()
        return self
    }
}
