//
//  UILabel+点击事件.swift
//  JobsByUIKit
//
//  Created by Jobs on 2026年5月13日，星期三.
//

#if os(OSX)
import AppKit
#elseif os(iOS) || os(tvOS)
import UIKit
#endif

import JobsSwiftDSL

extension UILabel {
    /// 点语法：给 UILabel 加点击事件，返回自己
    @discardableResult
    public func onTap(
        taps: Int = 1,
        touches: Int = 1,
        cancelsTouchesInView: Bool = true,
        isEnabled: Bool = true,
        name: String? = nil,
        _ handler: @escaping (UILabel) -> Void
    ) -> Self {
        isUserInteractionEnabled = true     // UIImageView 默认是 false，必须开
        let tapGR = UITapGestureRecognizer
            .byConfig { [weak self] gr in
                guard let self = self else { return }
                handler(self)               // 对外只暴露 UIImageView
            }
            .byTaps(taps)
            .byTouches(touches)
            .byCancelsTouchesInView(cancelsTouchesInView)
            .byEnabled(isEnabled)
            .byName(name)
        self.jobs_addGesture(tapGR)
        return self
    }
    /// 长按手势：返回 self，支持链式调用
    @discardableResult
    public func onLongPress(
        minDuration: TimeInterval = 0.8,     // 最小按压时长
        movement: CGFloat = 12,              // 允许移动距离
        touches: Int = 1,                    // 手指数量
        cancelsTouchesInView: Bool = true,
        isEnabled: Bool = true,
        name: String? = nil,
        _ handler: @escaping (UILabel, UILongPressGestureRecognizer) -> Void
    ) -> Self {
        isUserInteractionEnabled = true
        self.jobs_addGesture(UILongPressGestureRecognizer
            .byConfig { [weak self] gr in
                guard let self = self,
                      let lp = gr as? UILongPressGestureRecognizer else { return }
                handler(self, lp)           // 对外只暴露 UILabel + LongPress
            }
            .byMinDuration(minDuration)
            .byMovement(movement)
            .byTouches(touches)
            .byCancelsTouchesInView(cancelsTouchesInView)
            .byEnabled(isEnabled)
            .byName(name))
        return self
    }
}
