//
//  WBRecord.swift
//  RepairWorkbench
//
//  Created by Jobs on 2026年10月15日，星期四.
//

import Foundation

struct WBRecord: Equatable, Sendable {
    let raw: [String: WBJSON]

    var id: String {
        string("id")
    }

    func string(_ key: String) -> String {
        raw[key]?.string ?? ""
    }

    func int(_ key: String) -> Int64 {
        raw[key]?.integer ?? 0
    }

    func bool(_ key: String) -> Bool {
        raw[key]?.boolean ?? false
    }

    func strings(_ key: String) -> [String] {
        raw[key]?.array?.compactMap {
            $0.string
        } ?? []
    }
}
