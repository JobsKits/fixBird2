//
//  WBPart.swift
//  RepairWorkbench
//
//  Created by Jobs on 2026年10月15日，星期四.
//

import Foundation

struct WBPart: Equatable, Sendable {
    let id: String
    let name: String
    let sku: String
    var available: Int
    var quarantine: Int
}
