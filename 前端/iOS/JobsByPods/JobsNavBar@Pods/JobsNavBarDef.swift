//
//  JobsNavBarDef.swift
//  JobsNavBar
//
//  Created by Jobs on 2026年5月13日，星期三.
//

#if os(OSX)
import AppKit
#elseif os(iOS) || os(tvOS)
import UIKit
#endif

import SnapKit

public typealias BackButtonLayout = (JobsNavBar, UIButton, ConstraintMaker) -> Void
// MARK: - 回调协议：任何宿主视图（含 BaseWebView）都可感知 NavBar 显隐变化并自行调整内部布局
@MainActor
public protocol JobsNavBarHost: AnyObject {
    /// enabled: true=已安装；false=已移除
    func jobsNavBarDidToggle(enabled: Bool, navBar: JobsNavBar)
}
