//
//  WBOrderDetailVC.swift
//  WoodpeckerWorkbench
//
//  Created by Jobs on 2026年10月15日，星期四.
//

import UIKit
import JobsByUIKit
import JobsInheritance
import JobsSwiftDSL
import JobsSwiftBaseDefines

final class WBOrderDetailVC: BaseVC {
    private let store = WBStore.shared
    private var order: WBOrder
    private var loadRevision = 0
    private var detailsReady = false
    private lazy var page = WBPageView()
    private lazy var refreshButton = WBUI.button("重新加载完整工单") { [weak self] in
        self?.load()
    }

    init(order: WBOrder) {
        self.order = order
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        return nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        jobsSetupGKNav(title: order.number)
        page.mount(in: self)
        render()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        load()
    }

    private func load() {
        loadRevision += 1
        let revision = loadRevision
        detailsReady = false
        render()
        page.status("正在加载完整工单…")
        store.loadOrder(id: order.id) { [weak self] result in
            guard let self, revision == self.loadRevision else {
                return
            }
            switch result {
            /// 仅以完整校验后的结果开放办理入口。
            case .success(let order):
                self.order = order
                self.detailsReady = true
                self.render()
                self.page.status(self.store.lastMessage)
            /// 列表摘要不能替代可办理的完整单据。
            case .failure(let error):
                self.page.status(error.localizedDescription)
            }
        }
    }

    private func render() {
        let summary = order.summary
        let quote = order.quote
        var rows: [UIView] = [
            WBUI.card([
                WBUI.label(order.number, size: 26),
                WBUI.label(order.typeLabel + " · " + order.statusLabel),
                WBUI.label(order.customer + " · " + order.project),
                WBUI.label(order.device),
                WBUI.label(order.description),
                WBUI.label(store.sourceLabel, size: 13, secondary: true)
            ]),
            refreshButton, page.message
        ]
        if order.isSummary || !detailsReady {
            rows.append(WBUI.empty("完整工单尚未加载", message: "重新加载后可查看资料和办理") { [weak self] in
                self?.load()
            })
            page.replace(rows)
            return
        }
        rows.append(WBUI.card([
            WBUI.label("履约与报价", size: 20),
            WBUI.label("公司负责人：" + order.ownerId + "\n执行责任人：" + order.assigneeId),
            WBUI.label("报价 " + WBUI.money(quote.amountCents) + "　质保 \(quote.warrantyMonths) 个月"),
            WBUI.label(quote.description),
            WBUI.label("报价状态：" + (quote.approved ? "已审核" : "未审核") + " / " + (quote.signed ? "已签署" : "未签署")),
            WBUI.label("预付款 " + WBUI.money(quote.prepayCents) + "\n" + (quote.startRequiresPrepayment ? "明确约定先款：核实约定预付款后开修" : "未约定先款开修")),
            WBUI.label("接受期限：" + quote.validUntil + "\n" + (quote.autoAccept ? "客户已接受七日自动验收规则" : "未接受自动验收"), size: 13, secondary: true),
            WBUI.label("下一步：" + summary.nextTask + "\n质保：" + summary.warrantyLabel)
        ]))
        rows.append(WBUI.card([
            WBUI.label("票款与资料", size: 20),
            WBUI.label("有效应收 " + WBUI.money(summary.receivableCents) + "\n净实收 " + WBUI.money(summary.collectedCents) + "　待收 " + WBUI.money(summary.remainingCents)),
            WBUI.label("未核实现金 " + WBUI.money(summary.pendingCashCents) + "\n多收待退 " + WBUI.money(summary.overpaidCents) + "　有效票额 " + WBUI.money(summary.invoiceCents)),
            WBUI.label("付款资料：" + summary.documentStatus + "\n开票：" + summary.invoiceStatus),
            WBUI.label(summary.missing.isEmpty ? "当前没有已知缺项" : "待补齐：\n" + summary.missing.joined(separator: "\n"), size: 13, secondary: true)
        ]))
        if !order.customerNote.isEmpty || !order.remark.isEmpty {
            rows.append(WBUI.card([
                WBUI.label("工单说明", size: 20),
                WBUI.label("客户说明：" + order.customerNote),
                WBUI.label(order.remark.isEmpty ? "" : "内部备注：" + order.remark, secondary: true)
            ]))
        }
        rows.append(WBUI.label("当前可办理", size: 20))
        if order.allowedActions.isEmpty {
            rows.append(WBUI.empty("暂无可办理事项", message: "当前身份、阶段或单据条件不允许办理") { [weak self] in
                self?.load()
            })
        }
        for action in order.allowedActions {
            rows.append(WBUI.button(WBActionCatalog.title(action), primary: ["start", "sign_quote", "accept", "complete"].contains(action)) { [weak self] in
                self?.open(action)
            })
        }
        rows.append(contentsOf: recordSection("现金事实", records: order.cash))
        rows.append(contentsOf: recordSection("发票记录", records: order.invoices))
        rows.append(contentsOf: recordSection("归档资料", records: order.evidence))
        rows.append(contentsOf: recordSection("验收历史", records: order.acceptanceRecords))
        rows.append(contentsOf: recordSection("异议协商", records: order.issues))
        rows.append(contentsOf: recordSection("内部余项", records: order.obligations))
        rows.append(contentsOf: recordSection("上门行程", records: order.visits))
        rows.append(contentsOf: recordSection("内部成本", records: order.costs))
        rows.append(contentsOf: recordSection("提成结算", records: order.commissions))
        rows.append(WBUI.label("配件借还", size: 20))
        let loans = store.loans.filter { $0.orderId == order.id }
        if loans.isEmpty {
            rows.append(WBUI.empty("没有关联借用", message: "当前加载范围内尚无本单借用记录") { [weak self] in
                self?.store.refresh()
                self?.load()
            })
        }
        for loan in loans {
            rows.append(WBUI.card([
                WBUI.label(loan.partName),
                WBUI.label("借出 \(loan.quantity) · 尚欠 \(loan.outstanding) · 归还完好 \(loan.returnedGood) · 隔离 \(loan.returnedQuarantine)"),
                WBUI.label("责任人 " + loan.borrowerId + "　归还期限 " + loan.dueAt, size: 13, secondary: true)
            ]))
        }
        rows.append(contentsOf: recordSection("业务事件", records: order.events))
        page.replace(rows)
    }

    private func recordSection(_ title: String, records: [WBRecord]) -> [UIView] {
        var rows: [UIView] = [WBUI.label(title, size: 20)]
        if records.isEmpty {
            rows.append(WBUI.empty("暂无" + title, message: "本单尚无可见记录") { [weak self] in
                self?.load()
            })
        }
        for record in records.reversed() {
            var lines = [String]()
            for key in ["name", "title", "number", "note", "text", "reason", "recipient", "purpose", "receipt", "plannedAt", "at", "createdAt", "occurredAt"] {
                let text = record.string(key)
                if !text.isEmpty {
                    lines.append(text)
                }
            }
            if record.raw["amountCents"] != nil {
                lines.append("金额 " + WBUI.money(record.int("amountCents")))
            }
            if record.raw["verified"] != nil {
                lines.append(record.bool("verified") ? "财务已核实" : "待财务核实")
            }
            if record.raw["resolved"] != nil {
                lines.append(record.bool("resolved") ? "已办理" : "待办理")
            }
            if record.bool("deleted") || record.bool("voided") {
                lines.append("已删除 / 作废，不能作为有效资料")
            }
            rows.append(WBUI.card([
                WBUI.label(lines.isEmpty ? "已记录业务事实" : lines.joined(separator: "\n")),
                WBUI.label("记录 " + record.id, size: 12, secondary: true)
            ]))
        }
        return rows
    }

    private func open(_ action: String) {
        guard detailsReady, order.can(action), !order.isSummary else {
            page.status("请重新加载完整工单后办理。")
            return
        }
        if action == "evidence" {
            navigationController?.pushViewControllerByAnimated(WBFileEvidenceVC(order: order))
            return
        }
        if ["sign_quote", "accept"].contains(action) {
            navigationController?.pushViewControllerByAnimated(WBSignatureVC(order: order, action: action))
            return
        }
        navigationController?.pushViewControllerByAnimated(WBActionFormVC(order: order, action: action))
    }
}
