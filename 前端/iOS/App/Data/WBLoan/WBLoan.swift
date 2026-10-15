//
//  WBLoan.swift
//  RepairWorkbench
//
//  Created by Jobs on 2026年10月15日，星期四.
//

import Foundation

struct WBLoan: Equatable, Sendable {
    let id: String
    var version: Int
    let orderId: String
    let partId: String
    let partName: String
    let quantity: Int
    var returnedGood: Int
    var returnedQuarantine: Int
    var consumed: Int
    var disposed: Int
    var outstanding: Int
    let borrowerId: String
    let dueAt: String
    var transfers: [WBRecord]

    var blockingQuantity: Int {
        max(
            0,
            outstanding
                - transfers.reduce(0) {
                    $0 + Int($1.int("quantity"))
                }
        )
    }
}
