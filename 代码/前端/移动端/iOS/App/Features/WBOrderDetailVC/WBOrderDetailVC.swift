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
    private lazy var refreshButton = WBUI.button(WBL10n.staticText("重新加载完整工单")) { [weak self] in
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
        page.status(WBL10n.staticText("正在加载完整工单…"))
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
                self.page.status(WBL10n.text(self.store.lastMessage))
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
                WBUI.label(WBL10n.text(order.typeLabel) + " · " + WBL10n.text(order.statusLabel)),
                WBUI.label(order.customer + " · " + order.project),
                WBUI.label(order.device),
                WBUI.label(order.description),
                WBUI.label(WBL10n.text(store.sourceLabel), size: 13, secondary: true)
            ]),
            refreshButton, page.message
        ]
        if order.isSummary || !detailsReady {
            rows.append(WBUI.empty(WBL10n.staticText("完整工单尚未加载"), message: WBL10n.staticText("重新加载后可查看资料和办理")) { [weak self] in
                self?.load()
            })
            page.replace(rows)
            return
        }
        rows.append(WBUI.card([
            WBUI.label(WBL10n.staticText("履约与报价"), size: 20),
            WBUI.label(WBL10n.staticText("公司负责人：") + order.ownerId + WBL10n.staticText("\n执行责任人：") + order.assigneeId),
            WBUI.label(WBL10n.staticText("报价 ") + WBUI.money(quote.amountCents) + (WBL10n.staticText("　质保 ") + String(describing: quote.warrantyMonths) + WBL10n.staticText(" 个月"))),
            WBUI.label(quote.description),
            WBUI.label(WBL10n.staticText("报价状态：") + (quote.approved ? WBL10n.staticText("已审核") : WBL10n.staticText("未审核")) + " / " + (quote.signed ? WBL10n.staticText("已签署") : WBL10n.staticText("未签署"))),
            WBUI.label(WBL10n.staticText("预付款 ") + WBUI.money(quote.prepayCents) + "\n" + (quote.startRequiresPrepayment ? WBL10n.staticText("明确约定先款：核实约定预付款后开修") : WBL10n.staticText("未约定先款开修"))),
            WBUI.label(WBL10n.staticText("接受期限：") + quote.validUntil + "\n" + (quote.autoAccept ? WBL10n.staticText("客户已接受七日自动验收规则") : WBL10n.staticText("未接受自动验收")), size: 13, secondary: true),
            WBUI.label(WBL10n.staticText("下一步：") + summary.nextTask + WBL10n.staticText("\n质保：") + summary.warrantyLabel)
        ]))
        rows.append(WBUI.card([
            WBUI.label(WBL10n.staticText("票款与资料"), size: 20),
            WBUI.label(WBL10n.staticText("有效应收 ") + WBUI.money(summary.receivableCents) + WBL10n.staticText("\n已核实净收 ") + WBUI.money(summary.collectedCents) + WBL10n.staticText("　待收 ") + WBUI.money(summary.remainingCents)),
            WBUI.label(WBL10n.staticText("未核实现金 ") + WBUI.money(summary.pendingCashCents) + WBL10n.staticText("\n超收待退 ") + WBUI.money(summary.overpaidCents) + WBL10n.staticText("　有效票额 ") + WBUI.money(summary.invoiceCents)),
            WBUI.label(WBL10n.staticText("付款资料：") + summary.documentStatus + WBL10n.staticText("\n发票：") + summary.invoiceStatus),
            WBUI.label(summary.missing.isEmpty ? WBL10n.staticText("当前没有已知缺项") : WBL10n.staticText("未办事项：\n") + summary.missing.joined(separator: "\n"), size: 13, secondary: true)
        ]))
        if !order.customerNote.isEmpty || !order.remark.isEmpty {
            rows.append(WBUI.card([
                WBUI.label(WBL10n.staticText("工单说明"), size: 20),
                WBUI.label(WBL10n.staticText("客户说明：") + order.customerNote),
                WBUI.label(order.remark.isEmpty ? "" : WBL10n.staticText("内部备注：") + order.remark, secondary: true)
            ]))
        }
        rows.append(WBUI.label(WBL10n.staticText("当前可办理"), size: 20))
        if order.allowedActions.isEmpty {
            rows.append(WBUI.empty(WBL10n.staticText("暂无可办理事项"), message: WBL10n.staticText("当前身份、阶段或单据条件不允许办理")) { [weak self] in
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
        rows.append(WBUI.label(WBL10n.staticText("配件借还"), size: 20))
        let loans = store.loans.filter { $0.orderId == order.id }
        if loans.isEmpty {
            rows.append(WBUI.empty(WBL10n.staticText("没有关联借用"), message: WBL10n.staticText("当前加载范围内尚无本单借用记录")) { [weak self] in
                self?.store.refresh()
                self?.load()
            })
        }
        for loan in loans {
            rows.append(WBUI.card([
                WBUI.label(loan.partName),
                WBUI.label((WBL10n.staticText("借出 ") + String(describing: loan.quantity) + WBL10n.staticText(" · 尚欠 ") + String(describing: loan.outstanding) + WBL10n.staticText(" · 完好归还 ") + String(describing: loan.returnedGood) + WBL10n.staticText(" · 隔离 ") + String(describing: loan.returnedQuarantine))),
                WBUI.label(WBL10n.staticText("责任人 ") + loan.borrowerId + WBL10n.staticText("　归还期限 ") + loan.dueAt, size: 13, secondary: true)
            ]))
        }
        rows.append(contentsOf: recordSection("业务事件", records: order.events))
        page.replace(rows)
    }

    private func recordSection(_ title: String, records: [WBRecord]) -> [UIView] {
        var rows: [UIView] = [WBUI.label(title, size: 20)]
        if records.isEmpty {
            rows.append(WBUI.empty(WBL10n.text("暂无{title}").replacingOccurrences(of: "{title}", with: WBL10n.text(title)), message: WBL10n.staticText("本单尚无可见记录")) { [weak self] in
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
                lines.append(WBL10n.staticText("金额 ") + WBUI.money(record.int("amountCents")))
            }
            if record.raw["verified"] != nil {
                lines.append(WBL10n.text(record.bool("verified") ? "财务已核实" : "待财务核实"))
            }
            if record.raw["resolved"] != nil {
                lines.append(WBL10n.text(record.bool("resolved") ? "已办理" : "待办理"))
            }
            if record.bool("deleted") || record.bool("voided") {
                lines.append(WBL10n.text("已删除 / 作废，不能作为有效资料"))
            }
            rows.append(WBUI.card([
                WBUI.label(lines.isEmpty ? WBL10n.staticText("已记录业务事实") : lines.joined(separator: "\n")),
                WBUI.label(WBL10n.staticText("记录 ") + record.id, size: 12, secondary: true)
            ]))
        }
        return rows
    }

    private func open(_ action: String) {
        guard detailsReady, order.can(action), !order.isSummary else {
            page.status(WBL10n.staticText("请重新加载完整工单后办理。"))
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
