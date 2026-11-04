//
//  NumberFormatter.swift
//  JobsByUIKit
//
//  Created by Jobs on 2026年5月13日，星期三.
//

import Foundation
import JobsSwiftBlock
import JobsSwiftDSL

extension NumberFormatter {
    /// 统一入口：NumberFormatter.make { $0.byNumberStyle(...).byLocale(...) }
    public static func make(_ configure: jobsByNumberFormatterBlock) -> NumberFormatter {
        let formatter = NumberFormatter()
        configure(formatter)
        return formatter
    }
}
