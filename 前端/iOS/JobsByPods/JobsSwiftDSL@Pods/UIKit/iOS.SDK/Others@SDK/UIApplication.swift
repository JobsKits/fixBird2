//
//  UIApplication.swift
//  JobsSwiftDSL
//
//  Created by Jobs on 2026年5月13日，星期三.
//

#if os(OSX)
import AppKit
#elseif os(iOS) || os(tvOS)
import UIKit
#endif

@_exported import JobsGetWindow

#if os(iOS)
@available(iOS 10.3, *)
public extension UIApplication {
    /// 是否支持通过公开 API 切换到工程内预置的备用 AppIcon。
    var jobsSupportsAlternateIcons: Bool {
        supportsAlternateIcons
    }

    /// 当前备用 AppIcon 名称；为 nil 时表示正在使用主图标。
    var jobsAlternateIconName: String? {
        alternateIconName
    }

    /// 切换到工程内已声明的备用 AppIcon；传 nil 恢复主图标。
    @discardableResult
    func byAlternateIconName(_ alternateIconName: String?,
                             completionHandler: ((Error?) -> Void)? = nil) -> Self {
        setAlternateIconName(alternateIconName, completionHandler: completionHandler)
        return self
    }
}
#endif
