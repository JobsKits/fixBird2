//
//  WBQuote.swift
//  RepairWorkbench
//
//  Created by Jobs on 2026年10月15日，星期四.
//

import Foundation

struct WBQuote: Equatable, Sendable {
    var version = 0
    var amountCents: Int64 = 0
    var description = ""
    var warrantyMonths = 0
    var paymentTerms = ""
    var prepayCents: Int64 = 0
    var startRequiresPrepayment = false
    var validUntil = ""
    var approved = false
    var signed = false
    var autoAccept = false
}
