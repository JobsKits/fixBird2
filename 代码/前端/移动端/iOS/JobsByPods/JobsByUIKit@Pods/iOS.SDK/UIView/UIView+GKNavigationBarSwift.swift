//
//  UIView+GKNavigationBarSwift.swift
//  JobsByUIKit
//
//  Created by Jobs on 2026年5月13日，星期三.
//

#if os(OSX)
import AppKit
#elseif os(iOS) || os(tvOS)
import UIKit
#endif

#if canImport(SnapKit) && canImport(GKNavigationBarSwift)
import SnapKit
import GKNavigationBarSwift
@MainActor
extension UIView {
    /// 返回已存在的“导航栏类视图”（不触发懒加载），找不到返回 nil。
    /// 类型统一用 UIView?，外部无需依赖 GKNavigationBar 的符号。
    public func jobs_existingTopBar(deep: Bool = true) -> UIView? {
        #if canImport(GKNavigationBarSwift)
        if let nb = jobs_firstSubview(of: GKNavigationBar.self, deep: deep),
           !nb.isHidden, nb.alpha > 0.001 {
            return nb
        }
        #endif
        if let nb = jobs_firstSubview(of: UINavigationBar.self, deep: deep),
           !nb.isHidden, nb.alpha > 0.001 {
            return nb
        };return nil
    }
    // MARK: - 私有工具：按类型查找已存在的子视图（不会触发任何懒创建）
    private func jobs_firstSubview<T: UIView>(of type: T.Type, deep: Bool) -> T? {
        // 先一层
        if let hit = subviews.first(where: { $0 is T }) as? T { return hit }
        // 需要递归则继续
        guard deep else { return nil }
        for v in subviews {
            if let hit: T = v.jobs_firstSubview(of: type, deep: true) { return hit }
        };return nil
    }
}
#endif
