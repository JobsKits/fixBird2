//
//  WBOrderFormVC.swift
//  WoodpeckerWorkbench
//
//  Created by Jobs on 2026年10月15日，星期四.
//

import UIKit
import JobsByUIKit
import JobsInheritance
import JobsSwiftDSL
import JobsSwiftBaseDefines

final class WBOrderFormVC: BaseVC {
    private let store = WBStore.shared
    private lazy var page = WBPageView()
    private lazy var typeField = WBFormField("type", "业务类型", kind: .choice([("mail", "寄修"), ("onsite", "上门"), ("sale", "销售")]))
    private lazy var customer = WBFormField("customer", "客户名称", value: store.actor?.role == "customer" ? store.actor?.name ?? "" : "")
    private lazy var customerId = WBFormField("customerId", "已授权客户账号", value: store.actor?.role == "customer" ? store.actor?.id ?? "" : "")
    private lazy var companyId = WBFormField("companyId", "客户所属企业", value: store.actor?.role == "customer" ? store.actor?.companyId ?? "" : "")
    private lazy var project = WBFormField("project", "项目名称")
    private lazy var device = WBFormField("device", "设备型号 / 销售商品")
    private lazy var descriptionField = WBFormField("description", "故障现象 / 完整需求", kind: .multiline)
    private lazy var remark = WBFormField("remark", "内部备注", kind: .multiline)
    private lazy var customerNote = WBFormField("customerNote", "发布给客户的说明", kind: .multiline)
    private lazy var submitButton = WBUI.button("创建工单", primary: true) { [weak self] in
        self?.submit()
    }
    private var submitting = false

    override func viewDidLoad() {
        super.viewDidLoad()
        jobsSetupGKNav(title: "新建工单")
        page.mount(in: self)
        var rows: [UIView] = [
            WBUI.label(store.sourceLabel, size: 13, secondary: true),
            typeField, customer, customerId, companyId, project, device, descriptionField
        ]
        if store.actor?.isInternal == true {
            rows.append(remark)
        }
        rows.append(contentsOf: [customerNote, submitButton, page.message])
        page.replace(rows)
    }

    private func submit() {
        guard !submitting else {
            return
        }
        guard !customer.string.isEmpty, !customerId.string.isEmpty, !companyId.string.isEmpty,
              !device.string.isEmpty, !descriptionField.string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            page.status("请填写客户名称、授权账号、企业、设备和需求。")
            return
        }
        let input = WBOrderInput()
            .byType(typeField.string)
            .byCustomer(customer.string)
            .byCustomerId(customerId.string)
            .byCompanyId(companyId.string)
            .byProject(project.string)
            .byDevice(device.string)
            .byDescription(descriptionField.string)
            .byRemark(store.actor?.isInternal == true ? remark.string : "")
            .byCustomerNote(customerNote.string)
        submitting = true
        submitButton.byUserInteractionEnabled(false)
        page.status("正在提交…")
        store.createOrder(input: input) { [weak self] result in
            guard let self else {
                return
            }
            self.submitting = false
            self.submitButton.byUserInteractionEnabled(true)
            switch result {
            /// 展示确认后的完整工单，保留来源提示。
            case .success(let order):
                self.page.status(self.store.lastMessage)
                self.navigationController?.pushViewControllerByAnimated(WBOrderDetailVC(order: order))
            /// 未知结果不自动重复提交。
            case .failure(let error):
                self.page.status(error.localizedDescription + "\n请先查看工单列表确认结果，再决定是否重试。")
            }
        }
    }
}
