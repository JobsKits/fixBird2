//
//  UIImageView+DSL.swift
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

// MARK: - 直接赋值@单参数
extension UIImageView {
    // MARK: 图片
    @discardableResult
    public func byImage(_ img: UIImage?) -> Self {
        let slot = "UIImageView.image"
        if let key = img?.jobsThemeImageKey {
            JobsThemeCenter.shared.bind(self, slot: slot) { object, center in
                (object as? UIImageView)?.image = center.resolvedImage(key)
            }
        } else {
            JobsThemeCenter.shared.unbind(self, slot: slot)
            image = img
        }
        return self
    }
    // MARK: 高亮图片
    @discardableResult
    public func byHighlightedImage(_ image: UIImage?) -> Self {
        highlightedImage = image
        return self
    }
    // MARK: 是否可交互 UIView.byUserInteractionEnabled
    // MARK: 是否高亮
    @discardableResult
    public func byHighlighted(_ highlighted: Bool = true) -> Self {
        isHighlighted = highlighted
        return self
    }
    // MARK: 动画图片组
    @discardableResult
    public func byAnimationImages(_ images: [UIImage]?) -> Self {
        animationImages = images
        return self
    }
    // MARK: 高亮状态动画图片组
    @discardableResult
    public func byHighlightedAnimationImages(_ images: [UIImage]?) -> Self {
        highlightedAnimationImages = images
        return self
    }
    // MARK: 动画时长
    @discardableResult
    public func byAnimationDuration(_ duration: TimeInterval) -> Self {
        animationDuration = duration
        return self
    }
    // MARK: 动画重复次数
    @discardableResult
    public func byAnimationRepeatCount(_ count: Int) -> Self {
        animationRepeatCount = count
        return self
    }
    // MARK: iOS13+ Symbol 配置
    @available(iOS 13.0, *)
    @discardableResult
    public func bySymbolConfig(_ config: UIImage.SymbolConfiguration?) -> Self {
        preferredSymbolConfiguration = config
        return self
    }
    // MARK: - HDR 动态范围 (iOS17+)
    @available(iOS 17.0, *)
    @discardableResult
    public func byPreferredImageDynamicRange(_ range: UIImage.DynamicRange) -> Self {
        preferredImageDynamicRange = range
        return self
    }
    // MARK: - 启动动画
    @discardableResult
    public func startAnimation() -> Self {
        startAnimating()
        return self
    }
    // MARK: - 停止动画
    @discardableResult
    public func stopAnimation() -> Self {
        stopAnimating()
        return self
    }
}
// MARK: - 闭包重载@单参数
extension UIImageView {
    @discardableResult
    public func byImage(_ builder: () -> UIImage?) -> Self {
        byImage(builder())
    }

    @discardableResult
    public func byHighlightedImage(_ builder: () -> UIImage?) -> Self {
        self.highlightedImage = builder()
        return self
    }

    @discardableResult
    public func byHighlighted(_ builder: () -> Bool) -> Self {
        _byApplyValue(builder) { [weak self] highlighted in
            guard let self else { return }
            self.isHighlighted = highlighted
        }
    }

    @discardableResult
    public func byAnimationImages(_ builder: () -> [UIImage]?) -> Self {
        self.animationImages = builder()
        return self
    }

    @discardableResult
    public func byHighlightedAnimationImages(_ builder: () -> [UIImage]?) -> Self {
        self.highlightedAnimationImages = builder()
        return self
    }

    @discardableResult
    public func byAnimationDuration(_ builder: () -> TimeInterval) -> Self {
        _byApplyValue(builder) { [weak self] duration in
            guard let self else { return }
            self.animationDuration = duration
        }
    }

    @discardableResult
    public func byAnimationRepeatCount(_ builder: () -> Int) -> Self {
        _byApplyValue(builder) { [weak self] count in
            guard let self else { return }
            self.animationRepeatCount = count
        }
    }

    @available(iOS 13.0, *)
    @discardableResult
    public func bySymbolConfig(_ builder: () -> UIImage.SymbolConfiguration?) -> Self {
        self.preferredSymbolConfiguration = builder()
        return self
    }

    @available(iOS 17.0, *)
    @discardableResult
    public func byPreferredImageDynamicRange(_ builder: () -> UIImage.DynamicRange) -> Self {
        _byApplyValue(builder) { [weak self] range in
            guard let self else { return }
            self.preferredImageDynamicRange = range
        }
    }
}
