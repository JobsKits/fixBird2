//
//  BinaryFloatingPoint.swift
//  JobsSwiftFoundation
//
//  Created by Jobs on 2026年5月13日，星期三.
//

import Foundation

extension BinaryFloatingPoint {
    /// 浮点数专用：指定保留几位小数
    public func toString(_ fractionDigits: Int) -> String {
        String(format: "%.\(fractionDigits)f", Double(self))
    }
}
