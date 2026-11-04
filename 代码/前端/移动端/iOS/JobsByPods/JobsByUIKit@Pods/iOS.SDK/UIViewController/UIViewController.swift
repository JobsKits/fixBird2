//
//  UIViewController.swift
//  JobsByUIKit
//
//  Created by Jobs on 2026年5月13日，星期三.
//

#if os(OSX)
import AppKit
#elseif os(iOS) || os(tvOS)
import UIKit
#endif

// MARK: - 尽最大努力找到一个可用的 UINavigationController（先向上，再向下）
extension UIViewController {
    public var jobs_findNavController: UINavigationController? {
        // 1) 自己就是 nav
        if let nav = self as? UINavigationController { return nav }
        // 2) 系统 navigationController
        if let nav = self.navigationController { return nav }
        // 3) TabBar 场景
        if let tab = self.tabBarController {
            if let nav = tab.selectedViewController as? UINavigationController { return nav }
            if let nav = tab.selectedViewController?.navigationController { return nav }
        }
        // 4) 向上找 parent 链（最符合“我从当前页面 push”）
        var p = self.parent
        while let cur = p {
            if let nav = cur as? UINavigationController { return nav }
            if let nav = cur.navigationController { return nav }
            p = cur.parent
        }
        // 5) 兜底：向下 DFS（适配自定义容器把 nav 藏在 child）
        for c in children {
            if let nav = c.jobs_findNavController { return nav }
        };return nil
    }
}
