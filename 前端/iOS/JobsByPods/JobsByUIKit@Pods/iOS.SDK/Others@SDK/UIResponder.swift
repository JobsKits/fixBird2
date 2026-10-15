//
//  UIResponder.swift
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

// MARK: - 找当前第一响应者（常用黑魔法）
extension UIResponder {
    private static weak var _current: UIResponder?
    @objc private func _jobsTrapFindFirstResponder(_ sender: Any?) { UIResponder._current = self }
    public static func jobsCurrentFirstResponder() -> UIResponder? {
        _current = nil
        UIApplication.shared.sendAction(#selector(_jobsTrapFindFirstResponder(_:)),
                                        to: nil, from: nil, for: nil)
        return _current
    }
}
// MARK: - UIResponder → 最近的 VC（统一用 UIApplication 工具兜底）
extension UIResponder {
    /// 从任意 UIResponder（View / VC）向上找到最近的宿主 VC；若全程找不到则兜底到 keyWindow 的 root
    public func jobsNearestVC() -> UIViewController? {
        var r: UIResponder? = self
        while let cur = r {
            if let vc = cur as? UIViewController { return vc }
            r = cur.next
        };return UIApplication.jobsKeyWindow()?.rootViewController
    }
}
