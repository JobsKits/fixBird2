//
//  UIButton+锁定TintColor.swift
//  JobsByUIKit
//
//  Created by Jobs on 2026年5月13日，星期三.
//

#if os(OSX)
import AppKit
#elseif os(iOS) || os(tvOS)
import UIKit
#endif

import JobsSwiftBaseDefines
import JobsSwiftDSL

extension UIButton {
    // MARK: - 锁死标题颜色：任何 state 都保持同一种颜色，不跟 tint / 系统态自动变化
    public func byLockTitleColor(_ color: UIColor) -> Self {
        // 1) 锁死所有状态的 titleColor
        let states: [UIControl.State] = [.normal, .highlighted, .selected, .disabled]
        states.forEach { self.setTitleColor(color, for: $0) }
        // 2) 防 iOS 15+ configuration 覆盖（如果你有用到 configuration）
        if #available(iOS 15.0, *) {
            if var c = self.configuration {
                c.baseForegroundColor = color
                self.configuration = c
            };byUpdateConfig()
        }
        // 3) 避免 tint 影响（尤其是 system button）
        byTintColor(JobsCor.clear)
        // 4) 禁止 UIButton 自动“变暗/变亮”之类的调整（有时会影响观感）
        self.adjustsImageWhenHighlighted = false
        self.adjustsImageWhenDisabled = false
        return self
    }
    // MARK: - 只锁 Image（图片不随 tint / 状态变）
    /// 强制图片保持原色（完全不吃 tint）
    @discardableResult
    public func byLockImageRenderingOriginal() -> Self {
        let states: [UIControl.State] = [.normal, .highlighted, .selected, .disabled]
        for st in states {
            if let img = image(for: st) {
                setImage(img.withRenderingMode(.alwaysOriginal), for: st)
            }
            if let bg = backgroundImage(for: st) {
                setBackgroundImage(bg.withRenderingMode(.alwaysOriginal), for: st)
            }
        }
        // 避免系统按压/禁用自动“变暗”
        adjustsImageWhenHighlighted = false
        adjustsImageWhenDisabled = false
        return self
    }
    /// 图片吃 tint，但 tint 锁死为某个颜色
    @discardableResult
    public func byLockTintColor(_ color: UIColor) -> Self {
        tintColor = color
        if #available(iOS 15.0, *) {
            ensureConfigUpdateHandler { btn in
                btn.tintColor = color
                // 如果走 configuration.image，并且系统会在不同 state 下改前景，强行固定
                if btn.configuration != nil {
                    var c = btn.configuration!
                    c.imageColorTransformer = UIConfigurationColorTransformer { _ in color }
                    btn.configuration = c
                }
            };byUpdateConfig()
        };return self
    }
    // MARK: - 只锁 Background（背景色不随状态变）
    @discardableResult
    public func byLockBackgroundColor(_ color: UIColor) -> Self {
        if #available(iOS 15.0, *) {
            ensureConfigUpdateHandler { btn in
                var c = btn.configuration ?? .plain()
                c.baseBackgroundColor = color
                c.background.backgroundColor = color
                c.background.strokeColor = JobsCor.clear
                c.background.strokeWidth = 0
                // 3) 干掉系统的“按状态变色” transformer（关键）
                c.background.backgroundColorTransformer = UIConfigurationColorTransformer { _ in
                    color
                }
                btn.configuration = c
            };byUpdateConfig()
        } else {
            byBackgroundColor(color)
        };return self
    }
    // MARK: - 只锁 Border（边框色不随状态变，iOS 15+）
    @discardableResult
    public func byLockBorderColor(_ color: UIColor, width: CGFloat? = nil) -> Self {
        if let width { layer.borderWidth = width }
        layer.borderColor = color.cgColor
        if #available(iOS 15.0, *) {
            ensureConfigUpdateHandler { btn in
                btn.configuration = (btn.configuration ?? .plain())
                    .byBackgroundPatch { bg in
                        bg.strokeColor = color
                        if let width { bg.strokeWidth = width }
                    }
                // 同步 layer（有时候没用 configuration.background，也能看到边框）
                btn.layer.borderColor = color.cgColor
                if let width { btn.layer.borderWidth = width }
            };byUpdateConfig()
        };return self
    }
    // MARK: - 一个“不会互相覆盖”的 handler 合并器
    @available(iOS 15.0, *)
    private func ensureConfigUpdateHandler(_ adding: @escaping (UIButton) -> Void) {
        let previous = self.configurationUpdateHandler
        self.configurationUpdateHandler = { btn in
            previous?(btn)
            adding(btn)
        }
    }
}
