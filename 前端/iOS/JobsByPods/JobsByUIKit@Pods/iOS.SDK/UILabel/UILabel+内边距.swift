//
//  UILabel+内边距.swift
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

// MARK: - 文本内边距（不改类，关联对象 + 方法交换）
private var _jobsInsetsKey: UInt8 = 0
private var _jobsInsetsInstalledKey: UInt8 = 0
extension UILabel {
    /// 给 UILabel 增加 contentInsets 能力（无需自定义子类）
    public var jobs_contentInsets: UIEdgeInsets {
        get { (objc_getAssociatedObject(self, &_jobsInsetsKey) as? NSValue)?.uiEdgeInsetsValue ?? .zero }
        set {
            objc_setAssociatedObject(self, &_jobsInsetsKey, NSValue(uiEdgeInsets: newValue), .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            _jobs_installInsetsSwizzleIfNeeded()
            setNeedsDisplay()
            invalidateIntrinsicContentSize()
        }
    }

    @discardableResult
    public func byLabContentInsets(_ insets: UIEdgeInsets) -> Self {
        self.jobs_contentInsets = insets
        return self
    }
}

extension UILabel {
    private static let _once: Void = {
        let cls = UILabel.self
        // drawText(in:)
        _jobs_swizzle(cls, #selector(drawText(in:)), #selector(_jobs_drawText(in:)))
        // textRect(forBounds:limitedToNumberOfLines:)
        _jobs_swizzle(cls,
                      #selector(textRect(forBounds:limitedToNumberOfLines:)),
                      #selector(_jobs_textRect(forBounds:limitedToNumberOfLines:)))
        // intrinsicContentSize
        _jobs_swizzle(cls, #selector(getter: intrinsicContentSize), #selector(getter: _jobs_intrinsicContentSize))
    }()

    private func _jobs_installInsetsSwizzleIfNeeded() {
        let installed = (objc_getAssociatedObject(UILabel.self, &_jobsInsetsInstalledKey) as? Bool) ?? false
        if !installed {
            _ = UILabel._once
            objc_setAssociatedObject(
                UILabel.self,
                &_jobsInsetsInstalledKey,
                true,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
        }
    }

    @objc
    private func _jobs_drawText(in rect: CGRect) {
        let inset = jobs_contentInsets
        let r = rect.inset(by: inset)
        _jobs_drawText(in: r)
    }

    @objc
    private func _jobs_textRect(forBounds bounds: CGRect, limitedToNumberOfLines numberOfLines: Int) -> CGRect {
        let inset = jobs_contentInsets
        let b = bounds.inset(by: inset)
        let rect = _jobs_textRect(forBounds: b, limitedToNumberOfLines: numberOfLines)
        // 反向把 inset 加回去，保持 UILabel 外观尺寸一致
        return CGRect(x: rect.origin.x - inset.left,
                      y: rect.origin.y - inset.top,
                      width: rect.width + inset.left + inset.right,
                      height: rect.height + inset.top + inset.bottom)
    }

    @objc
    private var _jobs_intrinsicContentSize: CGSize {
        let base = self._jobs_intrinsicContentSize
        let inset = jobs_contentInsets
        return CGSize(width: base.width + inset.left + inset.right,
                      height: base.height + inset.top + inset.bottom)
    }
}
// MARK: - 轻量方法交换
private func _jobs_swizzle(_ cls: AnyClass,
                           _ orig: Selector,
                           _ repl: Selector) {
    guard let m1 = class_getInstanceMethod(cls, orig),
          let m2 = class_getInstanceMethod(cls, repl) else { return }
    method_exchangeImplementations(m1, m2)
}
