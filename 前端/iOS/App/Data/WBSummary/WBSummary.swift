//
//  WBSummary.swift
//  RepairWorkbench
//
//  Created by Jobs on 2026年10月15日，星期四.
//

import Foundation

struct WBSummary: Equatable, Sendable {
    var documentStatus = "待确认需求"
    var invoiceStatus = "待确认需求"
    var collectedCents: Int64 = 0
    var receivableCents: Int64 = 0
    var remainingCents: Int64 = 0
    var overpaidCents: Int64 = 0
    var pendingCashCents: Int64 = 0
    var invoiceCents: Int64 = 0
    var nextTask = "客服确认受理"
    var missing: [String] = []
    var warrantyLabel = "未起保"
}
