//
//  String+多语言国际化.swift
//  JobsByUIKit
//
//  Created by Jobs on 2026年5月13日，星期三.
//

#if os(OSX)
import AppKit
#elseif os(iOS) || os(tvOS)
import UIKit
#endif

import Jobsl10n

extension String {
    /// 多语言@唯一入口（支持自动刷新）
    public var tr: String {
        // ⭐️ 关键：把 key 注册进线程标记
        return TRAutoRefresh.Marker.pack(
            translated: NSLocalizedString(
                self,
                tableName: nil,
                bundle: TRLang.bundle(),
                value: self,
                comment: ""
            ),
            key: self,
            table: nil
        )
    }
    // 多语言@带参数版本
    public func tr(_ args: CVarArg...) -> String {
        String(format: self.tr, arguments: args)
    }
}
