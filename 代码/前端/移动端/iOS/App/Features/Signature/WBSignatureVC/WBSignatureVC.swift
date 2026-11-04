//
//  WBSignatureVC.swift
//  RepairWorkbench
//
//  Created by Jobs on 2026年10月15日，星期四.
//

import UIKit

import JobsByUIKit
import JobsInheritance

final class WBSignatureVC: BaseVC {
    private let order: WBOrder
    private let action: String
    private let openingActor: WBActor?
    private let openingEndpoint: String
    private let openingDemo: Bool
    private var consent = false
    private var submitting = false
    private lazy var page = WBPageView()
    private lazy var canvas = WBSignatureCanvas()
        .byDrawingStateChanged { [weak self] drawing in
            self?.page.byScrollEnabled(!drawing)
        }
    private lazy var instructions = WBUI.label("请先核对本次条款，再在白色区域留下本人手写签名。", secondary: true)
    private lazy var terms = WBUI.label(termsDescription)
    private lazy var decision = WBFormField("passed", "验收结论", kind: .choice([
        ("true", "验收通过"),
        ("false", "验收不通过，提交复核说明")
    ]), value: "true")
    private lazy var note = WBFormField("note", "验收说明（不通过时必填）", kind: .multiline)
    private lazy var clearButton = WBUI.button("清除当前签名") { [weak self] in
        self?.canvas.clearSignature()
    }
    private lazy var consentButton = WBUI.button("确认已核对本次条款") { [weak self] in
        self?.toggleConsent()
    }
    private lazy var submitButton = WBUI.button("提交本人签署", primary: true) { [weak self] in
        self?.submit()
    }

    init(order: WBOrder, action: String) {
        self.order = order
        self.action = action
        openingActor = WBStore.shared.actor
        openingEndpoint = WBStore.shared.endpoint
        openingDemo = WBStore.shared.isDemo
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        return nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        jobsSetupGKNav(title: action == "sign_quote" ? "报价确认与签署" : "交付验收与签署")
        page.byDelaysContentTouches(false)
            .mount(in: self)
        installForm()
    }

    private var termsDescription: String {
        if action == "sign_quote" {
            let terms = order.quote.paymentTerms == "credit" ? "账期付款" : "现款结算"
            let gate: String
            if order.type == "sale" {
                gate = order.quote.paymentTerms == "cash"
                    ? "现款销售：核实冻结报价全款后才允许出库。"
                    : "账期销售：按约定核实预付款后出库，余款按账期结算。"
            } else {
                gate = order.quote.startRequiresPrepayment
                    ? "已明确约定先款开修，核实约定预付款后才允许开修。"
                    : "未约定先款开修，预付金额本身不隐含开修门槛。"
            }
            let acceptance = order.type == "onsite"
                ? "上门业务须现场人工验收，不适用自动验收。"
                : order.quote.autoAccept
                ? "已约定自动验收：交付后按七个中国自然日规则核对，未结异议会阻断；不替代资料、票款、借还及整单完结核对。"
                : "未约定自动验收，须另行人工确认。"
            return "\(order.number)\n报价版本 \(order.quote.version) · \(WBUI.money(order.quote.amountCents))\n\(order.quote.description)\n质保 \(order.quote.warrantyMonths) 个月\n付款约定：\(terms)\n预付款：\(WBUI.money(order.quote.prepayCents))\n报价有效期至：\(order.quote.validUntil)\n\(gate)\n\(acceptance)"
        }
        return "\(order.number) · \(order.device)\n请根据实际交付情况选择验收结论；不通过也会保留本次签署原件与说明。"
    }

    private func installForm() {
        var rows: [UIView] = [terms, instructions]
        if action == "accept" {
            rows.append(decision)
            rows.append(note)
        }
        rows.append(contentsOf: [canvas, clearButton, consentButton, submitButton, page.message])
        page.replace(rows)
    }

    private func toggleConsent() {
        consent.toggle()
        consentButton.byTitle(consent ? "取消条款确认（当前已确认）" : "确认已核对本次条款")
    }

    private func submit() {
        guard !submitting else {
            return
        }
        guard let openingActor, let currentActor = WBStore.shared.actor,
              openingActor.matches(currentActor), openingEndpoint == WBStore.shared.endpoint,
              openingDemo == WBStore.shared.isDemo else {
            page.status("身份或数据来源已改变，请返回详情重新加载。")
            return
        }
        guard ["sign_quote", "accept"].contains(action), order.can(action), !order.isSummary else {
            page.status("当前工单或身份不可办理，请返回详情重新加载。")
            return
        }
        guard consent else {
            page.status("请先核对并确认本次条款。")
            return
        }
        guard let signature = canvas.signatureDataURL() else {
            page.status("请先在白色区域完成本人手写签名。")
            return
        }
        var payload: [String: Any] = ["signature": signature]
        if action == "sign_quote" {
            payload["quoteVersion"] = order.quote.version
        } else {
            let passed = decision.string == "true"
            guard passed || !note.string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                page.status("验收不通过时，请填写实际问题说明。")
                return
            }
            payload["passed"] = passed
            payload["note"] = note.string
        }
        submitting = true
        page.status("正在提交签署，请等待结果。")
        WBStore.shared.perform(order: order, action: action, payload: payload) { [weak self] result in
            guard let self else {
                return
            }
            self.submitting = false
            switch result {
            /// 服务端确认或明确标注的独立演示结果完成后返回详情。
            case .success:
                self.navigationController?.popViewControllerByAnimated()
            /// 保留签名及意图，允许读取核对后按原意图重试。
            case .failure(let error):
                self.page.status(error.localizedDescription)
            }
        }
    }
}
