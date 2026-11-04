//
//  Notification.swift
//  JobsSwiftBaseDefines
//
//  Created by Jobs on 2026年5月13日，星期三.
//

#if os(OSX)
import AppKit
#elseif os(iOS) || os(tvOS)
import UIKit
#endif

/// 通知分类

extension Notification.Name {
    /// 用户登陆
    static let userDidLogin = Notification.Name("userDidLogin")
    /// 跳转在线客服通知
    static let pushOnlineCustomerService = Notification.Name("pushOnlineCustomerService")
}
