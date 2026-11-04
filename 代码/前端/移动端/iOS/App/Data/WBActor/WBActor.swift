//
//  WBActor.swift
//  RepairWorkbench
//
//  Created by Jobs on 2026年10月15日，星期四.
//

import Foundation

struct WBActor: Equatable, Sendable {
    let id: String
    let username: String
    let name: String
    let role: String
    let companyId: String
    let status: String
    let authVersion: Int

    static let roles = [
        "admin", "dispatcher", "engineer", "outsource", "warehouse", "qc", "finance", "customer", "supplier",
    ]

    var roleLabel: String {
        [
            "admin": "公司负责人", "dispatcher": "客服调度", "engineer": "工程师", "outsource": "一手外包", "warehouse": "仓库",
            "qc": "质检", "finance": "财务", "customer": "客户", "supplier": "供应商",
        ][role] ?? role
    }

    var isInternal: Bool {
        !["customer", "supplier", "outsource"].contains(role)
    }

    func matches(_ other: WBActor) -> Bool {
        id == other.id && role == other.role && companyId == other.companyId && authVersion == other.authVersion
            && status == "active" && other.status == "active"
    }
}
