//
//  WBMetrics.swift
//  RepairWorkbench
//
//  Created by Jobs on 2026年10月15日，星期四.
//

import Foundation

struct WBMetrics: Equatable, Sendable {
    var openCount = 0
    var settlingCount = 0
    var remainingCents: Int64 = 0
    var readyCount = 0
    var tasksCount = 0
    var blockedCount = 0
}
