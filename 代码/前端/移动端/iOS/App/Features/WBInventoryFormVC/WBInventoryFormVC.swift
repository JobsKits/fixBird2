//
//  WBInventoryFormVC.swift
//  WoodpeckerWorkbench
//
//  Created by Jobs on 2026年10月16日，星期五.
//

import UIKit
import JobsByUIKit
import JobsInheritance
import JobsSwiftDSL
import JobsSwiftBaseDefines

final class WBInventoryFormVC: BaseVC {
    private let store = WBStore.shared
    private let loan: WBLoan?
    private let action: String
    private let openingActor: WBActor?
    private var fields: [WBFormField] = []
    private var submitting = false
    private var saved = false
    private lazy var page = WBPageView()
    private lazy var submitButton = WBUI.button("确认实际交接", primary: true) { [weak self] in
        self?.submit()
    }
    private lazy var backButton = WBUI.button("返回台账核对") { [weak self] in
        self?.navigationController?.popViewControllerByAnimated()
    }

    init(loan: WBLoan? = nil, action: String = "borrow") {
        self.loan = loan
        self.action = action
        self.openingActor = WBStore.shared.actor
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        return nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        jobsSetupGKNav(title: ["borrow": "登记实际借出", "return": "核对实际归还", "consume": "批准转维修耗用", "dispose": "批准尚欠件处置", "transfer": "转为独立跟踪"][action] ?? "办理借还")
        page.mount(in: self)
        if let loan {
            fields = [WBFormField("quantity", "本次实际数量（当前尚欠 \(loan.outstanding)）", kind: .integer, value: "1")]
            if action == "return" {
                fields.append(WBFormField("condition", "核对实物成色", kind: .choice([("good", "完好，回可用库"), ("quarantine", "待检测 / 损坏，进隔离库")])))
            } else {
                fields.append(WBFormField("reason", "批准人与处置依据", kind: .multiline))
            }
            if action == "transfer" {
                fields.append(contentsOf: [
                    WBFormField("ownerId", "独立跟踪责任人账号", value: loan.borrowerId),
                    WBFormField("dueAt", "独立归还期限", kind: .date, value: loan.dueAt)
                ])
            }
        } else {
            fields = [
                WBFormField("partId", "配件 / 型号", kind: .choice(store.parts.map { ($0.id, $0.name + " · 可用 \($0.available)") })),
                WBFormField("quantity", "实际借出数量", kind: .integer, value: "1"),
                WBFormField("orderId", "关联工单", kind: .choice([("", "独立借用，不关联工单")] + store.orders.filter { $0.status != "completed" }.map { ($0.id, $0.number + " · " + $0.device) })),
                WBFormField("borrowerId", "内部工程师借用账号"),
                WBFormField("dueAt", "预计归还日", kind: .date, value: WBActionCatalog.date(7)),
                WBFormField("note", "批准 / 实际交接依据", kind: .multiline)
            ]
        }
        var rows: [UIView] = [WBUI.label(store.sourceLabel + "\n数量按实物交接登记，不使用取消操作清零尚欠。", size: 13, secondary: true)]
        rows.append(contentsOf: fields)
        rows.append(contentsOf: [submitButton, backButton, page.message])
        page.replace(rows)
    }

    private func submit() {
        guard !submitting, !saved, let actor = store.actor, let openingActor,
              actor.matches(openingActor), ["admin", "warehouse"].contains(actor.role) else {
            page.status("当前身份无法办理，或正在提交。")
            return
        }
        do {
            var payload: [String: Any] = [:]
            for field in fields {
                if field.key != "orderId", field.string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    throw WBUIError("请填写完整交接事实，或先创建所需配件。")
                }
                payload[field.key] = try field.value()
            }
            let quantity = payload["quantity"] as? Int ?? 0
            guard (1...100000).contains(quantity) else {
                throw WBUIError("数量须为1～100000之间的整数。")
            }
            if let loan {
                let maximum = action == "transfer" ? loan.blockingQuantity : loan.outstanding
                guard quantity <= maximum else {
                    throw WBUIError("本次数量超过当前可办理数量。")
                }
            } else if let id = payload["partId"] as? String, let part = store.parts.first(where: { $0.id == id }), quantity > part.available {
                throw WBUIError("可用库存不足。")
            }
            submitting = true
            submitButton.byUserInteractionEnabled(false)
            page.status("正在提交…")
            let completion: (Result<Void, Error>) -> Void = { [weak self] result in
                guard let self else {
                    return
                }
                self.submitting = false
                switch result {
                /// 结果确认后返回台账，避免重复交接。
                case .success:
                    self.saved = true
                    self.submitButton.byTitle("已提交，请返回台账核对")
                    self.page.status(self.store.sourceLabel + "\n" + self.store.lastMessage)
                /// 未知结果不自动重发。
                case .failure(let error):
                    self.submitButton.byUserInteractionEnabled(true)
                    self.page.status(error.localizedDescription)
                }
            }
            if let loan {
                store.loanAction(loan: loan, action: action, payload: payload, completion: completion)
            } else {
                store.createLoan(payload: payload, completion: completion)
            }
        } catch {
            page.status(error.localizedDescription)
        }
    }
}
