//
//  JobsNavBarByUIKit.swift
//  JobsNavBar
//
//  Created by Jobs on 2026年5月13日，星期三.
//

#if os(OSX)
import AppKit
#elseif os(iOS) || os(tvOS)
import UIKit
#endif

import WebKit
import JobsSwiftBlock
import JobsSwiftDSL
import SnapKit
import SwiftMessages

extension UILabel {
    @discardableResult
    func byAttributedString(_ attributed: NSAttributedString?) -> Self {
        self.attributedText = attributed
        return self
    }
    @discardableResult
    func byNumberOfLines(_ lines: Int) -> Self {
        self.numberOfLines = lines
        return self
    }
    @discardableResult
    func byTextAlignment(_ alignment: NSTextAlignment) -> Self {
        self.textAlignment = alignment
        return self
    }
}

extension UIView {
    @discardableResult
    func byAddTo(_ superView: UIView,
                 _ closure: (_ v: UIView, _ make: ConstraintMaker) -> Void) -> Self {
        superView.addSubview(self)
        self.snp.makeConstraints { make in
            closure(self, make)
        };return self
    }

    @discardableResult
    func byHidden(_ hidden: Bool) -> Self {
        isHidden = hidden
        return self
    }

    @discardableResult
    func byAlpha(_ a: CGFloat) -> Self {
        alpha = a
        return self
    }
    /// 是否可见：true 显示；false 隐藏（折叠布局）
    @MainActor
    @discardableResult
    func byVisible(_ visible: Bool) -> Self {
        self
            .byHidden(!visible)
            .byAlpha(visible ? 1 : 0)
        return self
    }
}
private var actionKey: Void?
extension UIButton {
    @discardableResult
    private func _bindTapClosure(_ action: @escaping jobsByBtnBlock,
                                 for events: UIControl.Event = .touchUpInside) -> Self {
        objc_setAssociatedObject(self, &actionKey, action, .OBJC_ASSOCIATION_COPY_NONATOMIC)
        removeTarget(self, action: #selector(_jobsHandleAction(_:)), for: events)
        addTarget(self, action: #selector(_jobsHandleAction(_:)), for: events)
        return self
    }
    @discardableResult
    func jobs_addTapClosure(_ action: @escaping jobsByBtnBlock,
                            for events: UIControl.Event = .touchUpInside) -> Self {
        _bindTapClosure(action, for: events)
    }
    @objc private func _jobsHandleAction(_ sender: UIButton) {
        if let action = objc_getAssociatedObject(self, &actionKey) as? (UIButton) -> Void {
            action(sender)
        }
    }
    @discardableResult
    /// 点击方法@普通
    func onTap(_ handler: @escaping jobsByBtnBlock) -> Self {
        if #available(iOS 14.0, *) {
            (self as UIControl).addAction(UIAction { [weak self] _ in
                guard let s = self else { return }
                handler(s)
            }, for: .touchUpInside)
        } else {
            self.jobs_addTapClosure(handler)
        };return self
    }
}
