//
//  WBRequest.swift
//  RepairWorkbench
//
//  Created by Jobs on 2026年10月15日，星期四.
//

import Foundation

struct WBRequest {
    let endpoint: String
    let path: String
    let method: String
    let headers: [String: String]
    let body: [String: Any]?
    let timeout: TimeInterval
}
