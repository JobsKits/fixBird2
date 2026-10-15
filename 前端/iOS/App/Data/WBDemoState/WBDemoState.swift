//
//  WBDemoState.swift
//  RepairWorkbench
//
//  Created by Jobs on 2026年10月15日，星期四.
//

import Foundation

final class WBDemoState {
    var actor: WBActor
    var orders: [WBOrder] = []
    var parts = [WBPart(id: "ios-demo-part", name: "合成控制主板", sku: "DEMO-PCB", available: 8, quarantine: 1)]
    var loans: [WBLoan] = []
    var settings = WBSettings()

    init(username: String) {
        let role = ["customer-peer", "customer-b"].contains(username) ? "customer" : username
        let safeRole = WBActor.roles.contains(role) ? role : "customer"
        actor = WBActor(
            id: "ios-demo-" + username,
            username: username,
            name: "合成演示 · " + safeRole,
            role: safeRole,
            companyId: username == "customer-b" ? "ios-demo-company-b" : "ios-demo-company-a",
            status: "active",
            authVersion: 1
        )
        if safeRole != "supplier" {
            orders = [
                makeOrder(id: "ios-demo-intake", status: "pending_intake", device: "变频水泵控制柜", price: 0),
                makeOrder(
                    id: "ios-demo-confirm",
                    status: "pending_customer_confirmation",
                    device: "工业控制主板",
                    price: 128000
                ), makeOrder(id: "ios-demo-repair", status: "pending_execution", device: "门禁控制板", price: 50000),
            ]
            loans = [
                WBLoan(
                    id: "ios-demo-loan",
                    version: 1,
                    orderId: "ios-demo-repair",
                    partId: parts[0].id,
                    partName: parts[0].name,
                    quantity: 2,
                    returnedGood: 1,
                    returnedQuarantine: 0,
                    consumed: 0,
                    disposed: 0,
                    outstanding: 1,
                    borrowerId: "ios-demo-engineer",
                    dueAt: "2099-12-31T15:59:59Z",
                    transfers: []
                )
            ]
            if !["admin", "warehouse", "dispatcher", "engineer"].contains(safeRole) {
                loans.removeAll()
            }
            refresh()
        }
        if !actor.isInternal {
            parts.removeAll()
        }
    }

    var metrics: WBMetrics {
        WBMetrics(
            openCount: orders.filter {
                $0.status != "completed"
            }.count,
            settlingCount: orders.filter {
                $0.status == "settling"
            }.count,
            remainingCents: orders.reduce(0) {
                $0 + $1.summary.remainingCents
            },
            readyCount: orders.filter {
                $0.status == "pending_completion"
            }.count,
            tasksCount: orders.filter {
                $0.status != "completed"
            }.count,
            blockedCount: orders.filter {
                $0.issues.contains {
                    !$0.bool("resolved")
                }
            }.count
        )
    }

    private func makeOrder(id: String, status: String, device: String, price: Int64) -> WBOrder {
        let customerId = actor.role == "customer" ? actor.id : "ios-demo-customer"
        var raw: [String: Any] = [
            "id": id, "number": "DEMO-" + String(id.suffix(7)), "version": 1, "type": "mail", "customer": "海棠物业（独立合成）",
            "customerId": customerId, "companyId": actor.companyId, "project": "合成演示项目", "device": device,
            "description": "仅用于本地演示，不代表真实履约", "status": status, "outcome": "", "ownerId": "ios-demo-dispatcher",
            "assigneeId": actor.role == "outsource" ? actor.id : "ios-demo-engineer", "createdAt": WBFoundation.now(),
            "updatedAt": WBFoundation.now(), "remark": "合成内部交接", "customerNote": "合成资料，不得提交真实附件", "originalOrderId": "",
            "invoiceRequirement": "unknown", "invoiceReason": "", "invoiceDueCents": 0, "receivableCents": price,
            "restartReview": false, "allowedActions": [String](),
        ]
        for key in [
            "quoteHistory", "invoices", "cash", "evidence", "events", "visits", "outsource", "costs", "commissions",
            "issues", "obligations", "completionChecks",
        ] {
            raw[key] = [Any]()
        }
        raw["quote"] = [
            "version": price > 0 ? 1 : 0, "amountCents": price, "description": price > 0 ? "合成维修及测试范围" : "",
            "warrantyMonths": price > 0 ? 3 : 0, "paymentTerms": price > 0 ? "credit" : "", "prepayCents": 0,
            "startRequiresPrepayment": false, "validUntil": price > 0 ? "2099-12-31T15:59:59Z" : "",
            "approved": price > 0, "signed": status == "pending_execution", "autoAccept": false,
        ]
        raw["documents"] = [
            "requirement": "unknown", "reason": "", "version": 1, "prepared": false, "sent": false, "recipient": "",
            "files": [String](),
        ]
        raw["warranty"] = ["startsAt": "", "endsAt": ""]
        raw["summary"] = [
            "documentStatus": "待确认需求", "invoiceStatus": "待确认需求", "collectedCents": 0, "receivableCents": price,
            "remainingCents": price, "overpaidCents": 0, "pendingCashCents": 0, "invoiceCents": 0, "nextTask": "合成办理",
            "missing": [String](), "warrantyLabel": "未起保",
        ]
        do {
            return try WBContract.order(WBFoundation.json(raw))
        } catch {
            preconditionFailure("开发合成样例合同错误：\(error)")
        }
    }

    func create(_ input: WBOrderInput) throws -> WBOrder {
        guard ["admin", "dispatcher", "customer"].contains(actor.role),
            !input.device.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            !input.description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            ["mail", "onsite", "sale"].contains(input.type)
        else {
            throw WBError.unavailable("请填写设备、需求，并由授权角色录单")
        }
        var result = makeOrder(
            id: "ios-demo-" + UUID().uuidString,
            status: "pending_intake",
            device: input.device,
            price: 0
        )
        result.raw["type"] = .string(input.type)
        result.raw["description"] = .string(input.description)
        result.raw["project"] = .string(input.project)
        if !input.customer.isEmpty {
            result.raw["customer"] = .string(input.customer + "（合成）")
        }
        orders.insert(result, at: 0)
        refresh()
        return orders[0]
    }

    func perform(id: String, action: String, payload: [String: Any]) throws -> WBOrder {
        guard
            let position = orders.firstIndex(where: {
                $0.id == id
            }), orders[position].can(action)
        else {
            throw WBError.unavailable("当前角色或阶段不能在独立演示办理此动作")
        }
        var result = orders[position]
        let p = try WBContract.object(WBFoundation.json(payload))
        let note = p["note"]?.string ?? ""
        func requireNote() throws {
            guard !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw WBError.unavailable("请填写实际依据")
            }
        }
        switch action {
        /// 常用主线仅改变独立合成记录。
        case "intake":
            result.raw["ownerId"] = .string("ios-demo-dispatcher")
            result.raw["assigneeId"] = .string("ios-demo-engineer")
            result.raw["status"] = .string("pending_arrangement")
        /// 合成检测只推进独立工单。
        case "diagnose":
            result.raw["status"] = .string("diagnosis_quotation")
        /// 报价金额和约定须完整有效。
        case "quote":
            let amount = try WBContract.integer(p, "amountCents", minimum: 1)
            let prepay = try WBContract.integer(p, "prepayCents")
            let months = try WBContract.integer(p, "warrantyMonths", minimum: 1)
            guard prepay <= amount, months <= 60, ["cash", "credit"].contains(p["paymentTerms"]?.string ?? ""),
                p["description"]?.string?.isEmpty == false
            else {
                throw WBError.unavailable("请核对报价、预付上限、方案和质保")
            }
            let requires = p["startRequiresPrepayment"]?.boolean ?? false
            guard !requires || prepay > 0 else {
                throw WBError.unavailable("明确先款须约定正数预付款")
            }
            var quote = p
            quote["version"] = .integer(Int64(result.quote.version + 1))
            quote["approved"] = .boolean(false)
            quote["signed"] = .boolean(false)
            result.raw["quote"] = .object(quote)
            result.raw["receivableCents"] = .integer(amount)
            result.raw["status"] = .string("diagnosis_quotation")
        /// 过期报价不能进入确认阶段。
        case "approve_quote":
            guard result.quote.version > 0, result.quote.validUntil > WBFoundation.now() else {
                throw WBError.unavailable("报价不存在或已到接受期限")
            }
            var quote = result.raw["quote"]?.object ?? [:]
            quote["approved"] = .boolean(true)
            result.raw["quote"] = .object(quote)
            result.raw["status"] = .string("pending_customer_confirmation")
        /// 离线不伪造客户签署。
        case "sign_quote", "accept":
            throw WBError.unavailable("独立演示不模拟客户签署结果，请连接服务后使用手写原件办理")
        /// 先检查签署、异议与明确约定的预付款。
        case "start":
            guard result.quote.approved, result.quote.signed,
                !result.issues.contains(where: {
                    !$0.bool("resolved")
                }), !result.quote.startRequiresPrepayment || result.summary.collectedCents >= result.quote.prepayCents
            else {
                throw WBError.unavailable("签署、异议或约定预付款条件未齐")
            }
            result.raw["status"] = .string("repairing")
        /// 完工须保留实际依据。
        case "finish":
            try requireNote()
            result.raw["status"] = .string("pending_quality_check")
        /// 质检结论决定后续履约阶段。
        case "qc":
            try requireNote()
            result.raw["status"] = .string(p["passed"]?.boolean == true ? "pending_delivery" : "pending_execution")
        /// 交付前要求异议已闭环。
        case "deliver":
            try requireNote()
            guard
                !result.issues.contains(where: {
                    !$0.bool("resolved")
                })
            else {
                throw WBError.unavailable("仍有未结异议")
            }
            result.raw["deliveredAt"] = .string(WBFoundation.now())
            result.raw["status"] = .string("pending_acceptance")
        /// 备注按角色约束可编辑范围。
        case "remark":
            if let remark = p["remark"]?.string {
                guard ["admin", "dispatcher", "finance", "engineer"].contains(actor.role) else {
                    throw WBError.unavailable("当前角色不能修改内部备注")
                }
                result.raw["remark"] = .string(remark)
            }
            if let customerNote = p["customerNote"]?.string {
                result.raw["customerNote"] = .string(customerNote)
            }
        /// 新增独立合成异议。
        case "issue":
            try requireNote()
            var issues = result.raw["issues"]?.array ?? []
            issues.append(
                .object([
                    "id": .string("ios-demo-issue-" + UUID().uuidString), "title": .string(note),
                    "ownerId": .string("ios-demo-dispatcher"), "dueAt": .string("2099-12-31T15:59:59Z"),
                    "resolved": .boolean(false),
                ])
            )
            result.raw["issues"] = .array(issues)
        /// 只能关闭仍未解决的异议。
        case "resolve_issue":
            try requireNote()
            let wanted = try WBContract.text(p, "issueId", nonempty: true)
            var found = false
            result.raw["issues"] = .array(
                result.issues.map { item in
                    var raw = item.raw
                    if item.id == wanted && !item.bool("resolved") {
                        found = true
                        raw["resolved"] = .boolean(true)
                        raw["resolution"] = .string(note)
                    }
                    return .object(raw)
                }
            )
            guard found else {
                throw WBError.unavailable("未找到未结异议")
            }
        /// 其余分支保留明确的保守处理。
        default:
            throw WBError.unavailable("此动作首版仅支持服务端办理，独立演示不会伪造票款或签署成功")
        }
        result.raw["version"] = .integer(Int64(result.version + 1))
        result.raw["updatedAt"] = .string(WBFoundation.now())
        result.quote = try WBContract.quote(result.raw["quote"] ?? .null)
        orders[position] = result
        refresh()
        return orders[position]
    }

    func refresh() {
        for index in orders.indices {
            var order = orders[index]
            let price = order.raw["receivableCents"]?.integer ?? order.quote.amountCents
            order.summary.receivableCents = price
            order.summary.remainingCents = max(0, price - order.summary.collectedCents)
            order.summary.missing = ["付款资料需求待确认", "开票需求待确认", "履约结果尚未明确"]
            if loans.contains(where: {
                $0.orderId == order.id && $0.blockingQuantity > 0
            }) {
                order.summary.missing.append("关联配件借用尚未归还")
            }
            if order.issues.contains(where: {
                !$0.bool("resolved")
            }) {
                order.summary.missing.append("未结异议")
            }
            order.raw["allowedActions"] = .array(
                actions(order).map {
                    .string($0)
                }
            )
            orders[index] = order
        }
    }

    private func actions(_ order: WBOrder) -> [String] {
        var result: [String] = []
        let role = actor.role
        if ["admin", "dispatcher", "finance", "engineer", "warehouse", "qc"].contains(role)
            && order.status != "completed"
        {
            result.append("remark")
        }
        if role != "supplier" && order.status != "completed" {
            result.append("issue")
        }
        if ["admin", "dispatcher"].contains(role) {
            result.append("resolve_issue")
            if order.status == "pending_intake" {
                result.append("intake")
            }
            if order.status == "diagnosis_quotation" {
                result.append("approve_quote")
            }
        }
        if ["admin", "dispatcher", "engineer", "outsource"].contains(role) {
            if order.status == "pending_arrangement" {
                result.append("diagnose")
            }
            if ["diagnosis_quotation", "pending_customer_confirmation"].contains(order.status) {
                result.append("quote")
            }
        }
        if ["admin", "engineer", "outsource"].contains(role) {
            if order.status == "pending_execution" {
                result.append("start")
            }
            if order.status == "repairing" {
                result.append("finish")
            }
        }
        if ["admin", "qc"].contains(role) && order.status == "pending_quality_check" {
            result.append("qc")
        }
        if ["admin", "warehouse", "engineer", "dispatcher"].contains(role) && order.status == "pending_delivery" {
            result.append("deliver")
        }
        return result
    }
}
