//
//  WBOrder.swift
//  RepairWorkbench
//
//  Created by Jobs on 2026年10月15日，星期四.
//

import Foundation

struct WBOrder: Equatable, Sendable {
    var raw: [String: WBJSON]
    var quote: WBQuote
    var summary: WBSummary

    var id: String {
        text("id")
    }
    var number: String {
        text("number")
    }
    var version: Int {
        Int(raw["version"]?.integer ?? 0)
    }
    var type: String {
        text("type")
    }
    var status: String {
        text("status")
    }
    var outcome: String {
        text("outcome")
    }
    var customer: String {
        text("customer")
    }
    var customerId: String {
        text("customerId")
    }
    var companyId: String {
        text("companyId")
    }
    var project: String {
        text("project")
    }
    var device: String {
        text("device")
    }
    var description: String {
        text("description")
    }
    var ownerId: String {
        text("ownerId")
    }
    var assigneeId: String {
        text("assigneeId")
    }
    var remark: String {
        text("remark")
    }
    var customerNote: String {
        text("customerNote")
    }
    var documents: WBRecord {
        WBRecord(raw: raw["documents"]?.object ?? [:])
    }
    var cash: [WBRecord] {
        records("cash")
    }
    var invoices: [WBRecord] {
        records("invoices")
    }
    var evidence: [WBRecord] {
        records("evidence")
    }
    var events: [WBRecord] {
        records("events")
    }
    var issues: [WBRecord] {
        records("issues")
    }
    var obligations: [WBRecord] {
        records("obligations")
    }
    var visits: [WBRecord] {
        records("visits")
    }
    var costs: [WBRecord] {
        records("costs")
    }
    var commissions: [WBRecord] {
        records("commissions")
    }
    var acceptanceRecords: [WBRecord] {
        records("acceptanceRecords")
    }
    var allowedActions: [String] {
        raw["allowedActions"]?.array?.compactMap {
            $0.string
        } ?? []
    }
    var isSummary: Bool {
        raw["isSummary"]?.boolean ?? false
    }

    static let statusLabels = [
        "pending_intake": "待受理", "pending_arrangement": "待安排", "diagnosis_quotation": "检测／报价中",
        "pending_customer_confirmation": "待客户确认", "pending_execution": "待执行", "repairing": "维修中",
        "pending_quality_check": "待质检", "pending_delivery": "待交付", "pending_acceptance": "待验收", "settling": "结算中",
        "pending_completion": "待完结确认", "completed": "已完结",
    ]

    var statusLabel: String {
        Self.statusLabels[status] ?? status
    }

    var typeLabel: String {
        ["mail": "寄修", "onsite": "上门", "sale": "销售"][type] ?? type
    }

    func can(_ action: String) -> Bool {
        allowedActions.contains(action)
    }

    func text(_ key: String) -> String {
        raw[key]?.string ?? ""
    }

    func records(_ key: String) -> [WBRecord] {
        raw[key]?.array?.compactMap {
            $0.object
        }.map {
            WBRecord(raw: $0)
        } ?? []
    }
}
