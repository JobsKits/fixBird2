//
//  WBContract.swift
//  RepairWorkbench
//
//  Created by Jobs on 2026年10月15日，星期四.
//

import Foundation

enum WBContract {
    static func object(_ value: WBJSON) throws -> [String: WBJSON] {
        guard let object = value.object else {
            throw WBError.invalidResponse("应为 JSON 对象")
        }
        return object
    }

    static func text(_ raw: [String: WBJSON], _ key: String, nonempty: Bool = false) throws -> String {
        guard let value = raw[key]?.string, !nonempty || !value.isEmpty else {
            throw WBError.invalidResponse(key + " 应为有效字符串")
        }
        return value
    }

    static func integer(_ raw: [String: WBJSON], _ key: String, minimum: Int64 = 0) throws -> Int64 {
        guard let value = raw[key]?.integer, value >= minimum, value <= 9_007_199_254_740_991 else {
            throw WBError.invalidResponse(key + " 应为安全整数")
        }
        return value
    }

    static func flag(_ raw: [String: WBJSON], _ key: String) throws -> Bool {
        guard let value = raw[key]?.boolean else {
            throw WBError.invalidResponse(key + " 应为布尔值")
        }
        return value
    }

    static func array(_ raw: [String: WBJSON], _ key: String, optional: Bool = false) throws -> [WBJSON] {
        guard let value = raw[key] else {
            if optional {
                return []
            }
            throw WBError.invalidResponse("缺少 " + key)
        }
        if case .null = value {
            return []
        }
        guard let items = value.array else {
            throw WBError.invalidResponse(key + " 应为数组")
        }
        return items
    }

    static func strings(_ raw: [String: WBJSON], _ key: String, allowNull: Bool = true) throws -> [String] {
        if !allowNull, raw[key]?.array == nil {
            throw WBError.invalidResponse(key + " 必须提供字符串数组")
        }
        return try array(raw, key).map { value in
            guard let text = value.string else {
                throw WBError.invalidResponse(key + " 包含非字符串")
            }
            return text
        }
    }

    static func actor(_ value: WBJSON) throws -> WBActor {
        let raw = try object(value)
        let role = try text(raw, "role", nonempty: true)
        let status = try text(raw, "status", nonempty: true)
        guard WBActor.roles.contains(role), status == "active" else {
            throw WBError.invalidResponse("账号角色或有效状态不正确")
        }
        return WBActor(
            id: try text(raw, "id", nonempty: true),
            username: try text(raw, "username", nonempty: true),
            name: try text(raw, "name", nonempty: true),
            role: role,
            companyId: try text(raw, "companyId", nonempty: true),
            status: status,
            authVersion: Int(try integer(raw, "authVersion", minimum: 1))
        )
    }

    static func quote(_ value: WBJSON) throws -> WBQuote {
        let raw = try object(value)
        let version = Int(try integer(raw, "version"))
        let months = Int(try integer(raw, "warrantyMonths"))
        let terms = try text(raw, "paymentTerms")
        guard version == 0 || (1...60).contains(months) && ["cash", "credit"].contains(terms) else {
            throw WBError.invalidResponse("已发布报价的质保或付款约定无效")
        }
        let validUntil = try text(raw, "validUntil")
        guard WBFoundation.validDate(validUntil) else {
            throw WBError.invalidResponse("报价截止时间无效")
        }
        let amount = try integer(raw, "amountCents")
        let prepayment = try integer(raw, "prepayCents")
        let requiresPrepayment =
            raw["startRequiresPrepayment"] == nil ? false : try flag(raw, "startRequiresPrepayment")
        guard prepayment <= amount, !requiresPrepayment || prepayment > 0 else {
            throw WBError.invalidResponse("约定预付款须在报价范围内，明确先款须为正数")
        }
        return WBQuote(
            version: version,
            amountCents: amount,
            description: try text(raw, "description"),
            warrantyMonths: months,
            paymentTerms: terms,
            prepayCents: prepayment,
            startRequiresPrepayment: requiresPrepayment,
            validUntil: validUntil,
            approved: try flag(raw, "approved"),
            signed: try flag(raw, "signed"),
            autoAccept: try flag(raw, "autoAccept")
        )
    }

    static func summary(_ value: WBJSON) throws -> WBSummary {
        let raw = try object(value)
        return WBSummary(
            documentStatus: try text(raw, "documentStatus"),
            invoiceStatus: try text(raw, "invoiceStatus"),
            collectedCents: try integer(raw, "collectedCents", minimum: -9_007_199_254_740_991),
            receivableCents: try integer(raw, "receivableCents"),
            remainingCents: try integer(raw, "remainingCents"),
            overpaidCents: try integer(raw, "overpaidCents"),
            pendingCashCents: try integer(raw, "pendingCashCents"),
            invoiceCents: try integer(raw, "invoiceCents"),
            nextTask: try text(raw, "nextTask"),
            missing: try strings(raw, "missing", allowNull: false),
            warrantyLabel: try text(raw, "warrantyLabel")
        )
    }

    static func order(_ value: WBJSON, full: Bool = false) throws -> WBOrder {
        let raw = try object(value)
        for key in ["id", "number", "type", "status", "customerId", "companyId", "customer", "device"] {
            _ = try text(raw, key, nonempty: true)
        }
        for key in [
            "project", "description", "ownerId", "assigneeId", "remark", "customerNote", "outcome", "originalOrderId",
        ] {
            _ = try text(raw, key)
        }
        _ = try integer(raw, "version", minimum: 1)
        guard ["mail", "onsite", "sale"].contains(raw["type"]?.string ?? ""),
            WBOrder.statusLabels[raw["status"]?.string ?? ""] != nil
        else {
            throw WBError.invalidResponse("工单类型或阶段无效")
        }
        if full && raw["isSummary"]?.boolean == true {
            throw WBError.invalidResponse("摘要不能充当完整详情")
        }
        _ = try strings(raw, "allowedActions", allowNull: false)
        for key in ["createdAt", "updatedAt"] {
            guard WBFoundation.validDate(try text(raw, key, nonempty: true)) else {
                throw WBError.invalidResponse(key + " 时间无效")
            }
        }
        let documents = try object(raw["documents"] ?? .null)
        _ = try strings(documents, "files")
        for key in ["requirement", "reason", "recipient"] {
            _ = try text(documents, key)
        }
        _ = try flag(documents, "prepared")
        _ = try flag(documents, "sent")
        for key in [
            "cash", "invoices", "evidence", "events", "issues", "obligations", "visits", "outsource", "costs",
            "commissions",
        ] {
            for value in try array(raw, key) {
                let record = try object(value)
                _ = try text(record, "id", nonempty: true)
                if ["cash", "invoices", "costs", "commissions"].contains(key) {
                    _ = try integer(record, "amountCents", minimum: 1)
                }
                if key == "cash" {
                    guard ["receipt", "refund"].contains(try text(record, "kind")) else {
                        throw WBError.invalidResponse("现金方向无效")
                    }
                    _ = try flag(record, "verified")
                    _ = try flag(record, "handedOver")
                    for name in ["purpose", "receipt", "collector", "occurredAt"] {
                        _ = try text(record, name)
                    }
                }
                if ["issues", "obligations"].contains(key) {
                    _ = try flag(record, "resolved")
                }
                if key == "invoices" {
                    _ = try text(record, "number", nonempty: true)
                    _ = try strings(record, "files")
                    _ = try flag(record, "voided")
                }
                if key == "costs" {
                    _ = try flag(record, "approved")
                    for name in ["category", "note", "ownerId"] {
                        _ = try text(record, name)
                    }
                }
                if key == "commissions" {
                    _ = try flag(record, "settled")
                    _ = try text(record, "person", nonempty: true)
                    _ = try text(record, "note")
                }
            }
        }
        for value in try array(raw, "acceptanceRecords", optional: true) {
            let record = try object(value)
            _ = try text(record, "id", nonempty: true)
            _ = try text(record, "signature", nonempty: true)
            _ = try text(record, "signerId", nonempty: true)
            _ = try flag(record, "passed")
            _ = try integer(record, "quoteVersion", minimum: 1)
            _ = try integer(record, "orderVersion", minimum: 1)
        }
        return WBOrder(raw: raw, quote: try quote(raw["quote"] ?? .null), summary: try summary(raw["summary"] ?? .null))
    }

    static func metrics(_ value: WBJSON) throws -> WBMetrics {
        let raw = try object(value)
        return WBMetrics(
            openCount: Int(try integer(raw, "openCount")),
            settlingCount: Int(try integer(raw, "settlingCount")),
            remainingCents: try integer(raw, "remainingCents"),
            readyCount: Int(try integer(raw, "readyCount")),
            tasksCount: Int(try integer(raw, "tasksCount")),
            blockedCount: Int(try integer(raw, "blockedCount"))
        )
    }

    static func part(_ value: WBJSON) throws -> WBPart {
        let raw = try object(value)
        return WBPart(
            id: try text(raw, "id", nonempty: true),
            name: try text(raw, "name", nonempty: true),
            sku: try text(raw, "sku"),
            available: Int(try integer(raw, "available")),
            quarantine: Int(try integer(raw, "quarantine"))
        )
    }

    static func loan(_ value: WBJSON) throws -> WBLoan {
        let raw = try object(value)
        let transfers = try array(raw, "transfers").map { value -> WBRecord in
            let transfer = try object(value)
            _ = try integer(transfer, "quantity", minimum: 1)
            for key in ["ownerId", "dueAt", "reason", "at"] {
                _ = try text(transfer, key, nonempty: true)
            }
            return WBRecord(raw: transfer)
        }
        let quantity = Int(try integer(raw, "quantity", minimum: 1))
        let good = Int(try integer(raw, "returnedGood"))
        let quarantine = Int(try integer(raw, "returnedQuarantine"))
        let consumed = Int(try integer(raw, "consumed"))
        let disposed = Int(try integer(raw, "disposed"))
        let outstanding = Int(try integer(raw, "outstanding"))
        guard good + quarantine + consumed + disposed + outstanding == quantity else {
            throw WBError.invalidResponse("借用数量不守恒")
        }
        var remainingTransferable = outstanding
        for transfer in transfers {
            let count = Int(transfer.int("quantity"))
            guard count <= remainingTransferable else {
                throw WBError.invalidResponse("借用转出数量超过未归还数量")
            }
            remainingTransferable -= count
        }
        return WBLoan(
            id: try text(raw, "id", nonempty: true),
            version: Int(try integer(raw, "version", minimum: 1)),
            orderId: try text(raw, "orderId"),
            partId: try text(raw, "partId", nonempty: true),
            partName: try text(raw, "partName"),
            quantity: quantity,
            returnedGood: good,
            returnedQuarantine: quarantine,
            consumed: consumed,
            disposed: disposed,
            outstanding: outstanding,
            borrowerId: try text(raw, "borrowerId", nonempty: true),
            dueAt: try text(raw, "dueAt"),
            transfers: transfers
        )
    }

    static func settings(_ value: WBJSON) throws -> WBSettings {
        let raw = try object(value)
        return WBSettings(
            companyAddress: try text(raw, "companyAddress", nonempty: true),
            companyReceiver: try text(raw, "companyReceiver", nonempty: true),
            companyPhone: try text(raw, "companyPhone", nonempty: true),
            reminderHours: Int(try integer(raw, "reminderHours", minimum: 1)),
            remarkLimit: Int(try integer(raw, "remarkLimit", minimum: 1)),
            demo: try flag(raw, "demo")
        )
    }
}
