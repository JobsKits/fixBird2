//
//  WBActionFormVC.swift
//  WoodpeckerWorkbench
//
//  Created by Jobs on 2026年10月15日，星期四.
//

import UIKit
import JobsByUIKit
import JobsInheritance
import JobsSwiftDSL
import JobsSwiftBaseDefines

final class WBActionFormVC: BaseVC {
    private let store = WBStore.shared
    private let order: WBOrder
    private let action: String
    private let openingActor: WBActor?
    private var fields: [WBFormField] = []
    private var requiredKeys: Set<String> = []
    private var unsupported = false
    private var submitting = false
    private var saved = false
    private lazy var page = WBPageView()
    private lazy var submitButton = WBUI.button("确认提交", primary: true) { [weak self] in
        self?.submit()
    }
    private lazy var reloadButton = WBUI.button("返回工单核对结果") { [weak self] in
        self?.navigationController?.popViewControllerByAnimated()
    }

    init(order: WBOrder, action: String) {
        self.order = order
        self.action = action
        self.openingActor = WBStore.shared.actor
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        return nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        jobsSetupGKNav(title: WBActionCatalog.title(action))
        page.mount(in: self)
        buildFields()
        var rows: [UIView] = [WBUI.card([
            WBUI.label(order.number + " · " + order.statusLabel, size: 20),
            WBUI.label(store.sourceLabel, size: 13, secondary: true),
            WBUI.label("仅按已经发生、已经核实的事实填写。办理权限和当前业务条件以服务端确认为准。", size: 13, secondary: true)
        ])]
        rows.append(contentsOf: fields)
        if unsupported {
            rows.append(WBUI.label("此事项请在网页工作台完成。原生客户端暂不提交该类记录。", secondary: true))
        } else {
            rows.append(submitButton)
        }
        rows.append(contentsOf: [reloadButton, page.message])
        page.replace(rows)
    }

    private func field(_ key: String, _ title: String, kind: WBFieldKind = .text, value: String = "", required: Bool = true) {
        fields.append(WBFormField(key, title, kind: kind, value: value))
        if required {
            requiredKeys.insert(key)
        }
    }

    private func note() {
        field("note", "事实说明 / 办理依据", kind: .multiline)
    }

    private func choice(_ key: String, _ title: String, _ values: [(String, String)], value: String = "") {
        field(key, title, kind: .choice(values), value: value)
    }

    private func flag(_ key: String, _ title: String, yes: String = "是", no: String = "否", value: Bool = false) {
        choice(key, title, [("false", no), ("true", yes)], value: String(value))
    }

    private func reference(_ key: String, _ title: String, records: [WBRecord]) {
        choice(key, title, records.map { record in
            let description = [record.string("number"), record.string("title"), record.string("name"), record.string("note")].first { !$0.isEmpty } ?? record.id
            return (record.id, description + (record.raw["amountCents"] == nil ? "" : " · " + WBUI.money(record.int("amountCents"))))
        })
    }

    private func files(invoice: Bool) {
        let options = order.evidence.filter { record in
            guard !record.bool("deleted") else {
                return false
            }
            return !invoice || record.string("kind") == "image" || record.string("mime") == "application/pdf"
        }.map { ($0.id, $0.string("name")) }
        field("files", "选择已归档的真实原件", kind: .multiple(options), value: invoice ? "" : order.documents.strings("files").joined(separator: ","), required: invoice)
    }

    private func buildFields() {
        let quote = order.quote
        switch action {
        /// 受理与改派使用已授权真实账号，不以角色名虚构人员。
        case "intake":
            field("ownerId", "公司负责人账号", value: order.ownerId)
            field("assigneeId", "执行责任人账号", value: order.assigneeId)
        /// 改派只更换执行责任人。
        case "assign":
            field("assigneeId", "新执行责任人账号", value: order.assigneeId)
        /// 交接经办人保留授权核实依据。
        case "handover_contact":
            field("customerId", "同企业新授权经办人账号")
            field("reason", "授权核实、交接原因及待办说明", kind: .multiline)
        /// 报价保留独立先款约定，不把现金约定等同先款开修。
        case "quote":
            field("amountCents", "含税总价（元）", kind: .money, value: WBActionCatalog.amount(quote.amountCents))
            field("warrantyMonths", "质保月数（1～60）", kind: .integer, value: String(max(1, quote.warrantyMonths)))
            choice("paymentTerms", "付款约定", [("cash", "现金约定"), ("credit", "批准企业账期")], value: quote.paymentTerms)
            field("prepayCents", "约定预付款（元，可为零）", kind: .money, value: WBActionCatalog.amount(quote.prepayCents))
            if order.type != "sale" {
                flag("startRequiresPrepayment", "是否明确约定先款开修", yes: "已明确约定，核实约定预付款后开修", no: "未约定先款开修", value: quote.startRequiresPrepayment)
            }
            field("validUntil", "报价接受截止日", kind: .date, value: quote.validUntil.isEmpty ? WBActionCatalog.date(30) : quote.validUntil)
            flag("autoAccept", "七日自动验收规则", yes: "客户已接受，凭完整交付启动", no: "未接受，不自动验收", value: quote.autoAccept)
            field("description", "型号、数量、维修方案与完整条款", kind: .multiline, value: quote.description)
        /// 完工、质检与交付记录实际履约事实。
        case "qc":
            flag("passed", "实际质量结论", yes: "公司质检合格", no: "质检不合格，安排整改", value: true)
            note()
        /// 销售出库按实际配件和数量登记。
        case "stock_ready":
            choice("partId", "实际出库配件", store.parts.map { ($0.id, $0.name + " · 可用 \($0.available)") })
            field("quantity", "实际出库数量", kind: .integer, value: "1")
        /// 物流方式和运单作为独立交付事实。
        case "dispatch":
            field("carrier", "承运方 / 自送方式")
            field("tracking", "真实物流号（自送可注明）", required: false)
            note()
        /// 签收时间必须是实际完整交接时刻。
        case "deliver":
            field("deliveredAt", "实际完整签收时间", kind: .dateTime, value: WBActionCatalog.instant())
            note()
        /// 付款资料与发票只引用已有原件。
        case "requirements":
            let options = [("unknown", "待确认"), ("required", "需要真实资料"), ("none", "无需，已有确认依据")]
            choice("documentRequirement", "付款资料要求", options, value: order.documents.string("requirement"))
            choice("invoiceRequirement", "本单开票要求", options, value: order.text("invoiceRequirement"))
            field("documentReason", "付款资料要求来源 / 无需依据", kind: .multiline, value: order.documents.string("reason"), required: false)
            field("invoiceReason", "开票要求来源 / 无需依据", kind: .multiline, value: order.text("invoiceReason"), required: false)
            field("invoiceDueCents", "当前应开含税票额（元）", kind: .money, value: WBActionCatalog.amount(order.raw["invoiceDueCents"]?.integer ?? quote.amountCents))
        /// 制作与发送分别确认，保留已有原件引用。
        case "documents":
            flag("prepared", "实际制作状态", yes: "资料已实际齐备", no: "尚未齐备", value: order.documents.bool("prepared"))
            flag("sent", "实际发送状态", yes: "已经实际发送", no: "尚未发送", value: order.documents.bool("sent"))
            field("recipient", "发送对象与方式 / 凭据说明", value: order.documents.string("recipient"), required: false)
            files(invoice: false)
        /// 发票只引用当前有效PDF或图片原件。
        case "invoice":
            field("number", "真实发票号码")
            field("amountCents", "含税票额（元）", kind: .money, value: "0.00")
            files(invoice: true)
        /// 作废保留原票记录及依据。
        case "void_invoice":
            reference("invoiceId", "选择有效发票", records: order.invoices.filter { !$0.bool("voided") })
            field("reason", "红冲 / 作废原因与依据", kind: .multiline)
        /// 现金登记、财务核实和内部交接保持独立。
        case "cash":
            choice("kind", "本次实际现金事实", [("receipt", "收到现金"), ("refund", "实际退还现金")])
            field("amountCents", "现金金额（元）", kind: .money, value: "0.00")
            field("purpose", "款项用途（预付 / 尾款等）")
            field("occurredAt", "现金实际发生时间", kind: .dateTime, value: WBActionCatalog.instant())
            field("receipt", "现金凭证 / 客户收讫依据", kind: .multiline)
        /// 财务逐笔核实现金，不凭总额代替。
        case "verify_cash":
            reference("cashId", "选择未核实现金记录", records: order.cash.filter { !$0.bool("verified") })
            note()
        /// 内部交接不再次增加客户收款。
        case "handover_cash":
            reference("cashId", "选择尚未内部交接的现金", records: order.cash.filter { !$0.bool("handedOver") })
            note()
        /// 调整有效应收必须保留批准依据。
        case "adjust_receivable":
            field("amountCents", "批准后的有效应收总额（元）", kind: .money, value: WBActionCatalog.amount(order.summary.receivableCents))
            field("reason", "批准人与调整依据", kind: .multiline)
        /// 客户说明与内部备注分别提交。
        case "remark":
            if ["admin", "dispatcher", "finance", "engineer"].contains(store.actor?.role ?? "") {
                field("remark", "内部备注", kind: .multiline, value: order.remark, required: false)
            }
            field("customerNote", "发布给客户的说明", kind: .multiline, value: order.customerNote, required: false)
        /// 文字事实单独归档，不伪造二进制原件。
        case "evidence":
            field("name", "文字资料名称")
            field("text", "事实内容（原生暂仅支持文字归档）", kind: .multiline)
        /// 删除只影响本人或管理员可管理的资料。
        case "delete_evidence":
            reference("evidenceId", "选择本人待删除资料", records: order.evidence.filter { !$0.bool("deleted") && ($0.string("uploaderId") == store.actor?.id || store.actor?.role == "admin") })
            field("reason", "删除原因（将停用旧下载和资料包引用）", kind: .multiline)
        /// 异议和内部余项使用当前单据中的真实记录。
        case "issue":
            note()
            field("ownerId", "协商责任人账号", value: order.ownerId)
            field("dueAt", "下次处理期限", kind: .date, value: WBActionCatalog.date(3))
        /// 协商处理引用本单未解决异议。
        case "resolve_issue":
            reference("issueId", "选择未解决异议", records: order.issues.filter { !$0.bool("resolved") })
            note()
        /// 内部余项明确责任人与期限。
        case "obligation":
            field("title", "本单必须办理事项")
            field("ownerId", "责任人账号", value: order.ownerId)
            field("dueAt", "办理期限", kind: .date, value: WBActionCatalog.date(3))
        /// 办理结果对应本单未完成事项。
        case "resolve_obligation":
            reference("obligationId", "选择本人可办理的余项", records: order.obligations.filter {
                !$0.bool("resolved") && (["admin", "dispatcher"].contains(store.actor?.role ?? "") || $0.string("ownerId") == store.actor?.id)
            })
            note()
        /// 停止履约同时明确最终应收与退件责任。
        case "failure":
            choice("reason", "真实停止履约结果", [("customer_refused", "客户拒修"), ("company_refused", "公司拒修"), ("unrepairable", "确认不能修"), ("cancelled", "批准取消"), ("negotiated", "按协商停止")])
            field("amountCents", "批准的本次最终应收（元）", kind: .money, value: WBActionCatalog.amount(order.summary.receivableCents))
            flag("returnRequired", "客户设备是否必须退回", yes: "需要退件并生成余项", no: "无需退件，有实际依据", value: true)
            note()
        /// 行程和成本按实际事实登记。
        case "visit":
            field("plannedAt", "预计到场时间", kind: .dateTime, value: WBActionCatalog.instant())
            field("feeMemo", "内部基础费用备忘", kind: .multiline, required: false)
            note()
        /// 到场事实只能关联已有行程。
        case "start_visit":
            reference("visitId", "选择待到场行程", records: order.visits.filter { $0.string("startedAt").isEmpty })
            note()
        /// 外包保留责任主体及真实流向。
        case "outsource":
            field("provider", "一手外包责任主体 / 后续机构")
            field("contact", "已知联系人", required: false)
            field("destination", "后续流向 / 设备去向", required: false)
            note()
        /// 按本次实际业务事实办理。
        case "cost":
            choice("category", "实际成本分类", [("parts", "配件"), ("labor", "人工工时"), ("transport", "交通物流"), ("outsource", "一手外包"), ("other", "其他获批费用")])
            field("amountCents", "成本金额（元）", kind: .money, value: "0.00")
            note()
        /// 批准只对应尚未审核成本。
        case "approve_cost":
            reference("costId", "选择待审核成本", records: order.costs.filter { !$0.bool("approved") })
            note()
        /// 提成单独登记归属及金额。
        case "commission":
            field("person", "实际提成归属人")
            field("amountCents", "提成金额（元）", kind: .money, value: "0.00")
            note()
        /// 结算只核实已有未结算记录。
        case "settle_commission":
            reference("commissionId", "选择待结算提成", records: order.commissions.filter { !$0.bool("settled") })
            note()
        /// 整单重开必须保留原因及批准依据。
        case "reopen":
            field("reason", "重开原因与批准依据", kind: .multiline)
        /// 关联返修须明确是否核实免费范围。
        case "rework":
            note()
            flag("free", "本次返修费用约定", yes: "有效质保内免费，范围已核实", no: "另行核定费用", value: true)
        /// 常用履约步骤保留本次事实说明。
        case "receive", "diagnose", "report", "approve_quote", "start", "finish", "complete":
            note()
        /// 停机线下异议等安全流程暂转网页，不伪造签署与校核。
        default:
            unsupported = true
        }
    }

    private func submit() {
        guard !submitting, !saved, !unsupported else {
            return
        }
        guard order.can(action), !order.isSummary, let actor = store.actor, let openingActor,
              actor.matches(openingActor) else {
            page.status("身份或单据已变化，请返回并重新打开工单。")
            return
        }
        do {
            var payload: [String: Any] = [:]
            for field in fields {
                if requiredKeys.contains(field.key), field.string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    throw WBUIError("还有必填事项未填写或没有可选记录，请核对后提交。")
                }
                payload[field.key] = try field.value()
            }
            for key in ["passed", "prepared", "sent", "startRequiresPrepayment", "autoAccept", "returnRequired", "free"] {
                if let value = payload[key] as? String {
                    payload[key] = value == "true"
                }
            }
            for key in ["validUntil", "dueAt"] {
                if let value = payload[key] as? String, value.count == 10 {
                    payload[key] = value + "T23:59:59+08:00"
                }
            }
            for key in ["validUntil", "dueAt", "occurredAt", "deliveredAt", "plannedAt"] {
                if let value = payload[key] as? String, ISO8601DateFormatter.jobsMake { _ in }.date(from: value) == nil {
                    throw WBUIError("日期格式不正确，请按页面示例填写。")
                }
            }
            if ["cash", "invoice", "cost", "commission"].contains(action), (payload["amountCents"] as? Int64 ?? 0) <= 0 {
                throw WBUIError("本次金额必须大于零。")
            }
            if action == "quote" {
                let months = payload["warrantyMonths"] as? Int ?? 0
                guard (1...60).contains(months), (payload["amountCents"] as? Int64 ?? 0) > 0 else {
                    throw WBUIError("报价金额须大于零，质保月数须为1～60。")
                }
                if payload["startRequiresPrepayment"] as? Bool == true, (payload["prepayCents"] as? Int64 ?? 0) <= 0 {
                    throw WBUIError("明确先款开修时须填写大于零的约定预付款。")
                }
            }
            if action == "evidence" {
                payload["kind"] = "text"
            }
            submitting = true
            submitButton.byUserInteractionEnabled(false)
            page.status("正在提交…")
            store.perform(order: order, action: action, payload: payload) { [weak self] result in
                guard let self else {
                    return
                }
                self.submitting = false
                switch result {
                /// 一次办理结束后返回详情核对，避免重复记账。
                case .success:
                    self.saved = true
                    self.submitButton.byTitle("已提交，请返回工单核对")
                    self.page.status(self.store.sourceLabel + "\n" + self.store.lastMessage)
                /// 数据层保留同一请求意图，页面不自动重发。
                case .failure(let error):
                    self.submitButton.byUserInteractionEnabled(true)
                    self.page.status(error.localizedDescription)
                }
            }
        } catch {
            page.status(error.localizedDescription)
        }
    }
}
