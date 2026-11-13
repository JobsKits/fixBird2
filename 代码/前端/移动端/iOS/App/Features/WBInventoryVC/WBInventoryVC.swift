//
//  WBInventoryVC.swift
//  WoodpeckerWorkbench
//
//  Created by Jobs on 2026年10月16日，星期五.
//

import UIKit
import JobsByUIKit
import JobsInheritance
import JobsSwiftDSL
import JobsSwiftBaseDefines

final class WBInventoryVC: BaseVC {
    private let store = WBStore.shared
    private lazy var page = WBPageView()
    private lazy var refreshButton = WBUI.button(WBL10n.staticText("重新加载库存与借还")) { [weak self] in
        self?.store.refresh()
    }
    private lazy var borrowButton = WBUI.button(WBL10n.staticText("登记实际借出"), primary: true) { [weak self] in
        self?.navigationController?.pushViewControllerByAnimated(WBInventoryFormVC())
    }
    private var observer: UUID?

    override func viewDidLoad() {
        super.viewDidLoad()
        jobsSetupGKNav(title: WBL10n.text("库存与借还"))
        if navigationController?.viewControllers.first === self {
            gk_navLeftBarButtonItem?.byHidden(true)
        }
        page.mount(in: self)
        observer = store.observe { [weak self] in
            self?.render()
        }
        render()
        store.refresh()
    }

    deinit {
        if let observer {
            store.removeObserver(observer)
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        store.refresh()
    }

    private func render() {
        let canHandle = ["admin", "warehouse"].contains(store.actor?.role ?? "")
        var rows: [UIView] = [
            WBUI.label(WBL10n.text(store.sourceLabel) + "\n" + WBL10n.text(store.lastMessage), size: 13, secondary: true),
            refreshButton
        ]
        if canHandle {
            rows.append(borrowButton)
        }
        rows.append(WBUI.label(WBL10n.staticText("配件库存"), size: 22))
        if store.parts.isEmpty {
            rows.append(WBUI.empty(WBL10n.staticText("没有可见库存"), message: WBL10n.staticText("当前账号没有可见配件或尚未建库")) { [weak self] in
                self?.store.refresh()
            })
        }
        for part in store.parts {
            rows.append(WBUI.card([
                WBUI.label(part.name, size: 18),
                WBUI.label(WBL10n.staticText("型号 ") + part.sku),
                WBUI.label((WBL10n.staticText("可用 ") + String(describing: part.available) + WBL10n.staticText(" 件　隔离 ") + String(describing: part.quarantine) + WBL10n.staticText(" 件")))
            ]))
        }
        rows.append(WBUI.label(WBL10n.staticText("借用台账"), size: 22))
        if store.loans.isEmpty {
            rows.append(WBUI.empty(WBL10n.staticText("暂无借用记录"), message: WBL10n.staticText("实际借出后会生成独立记录")) { [weak self] in
                self?.store.refresh()
            })
        }
        for loan in store.loans {
            var content: [UIView] = [
                WBUI.label(loan.partName, size: 18),
                WBUI.label((WBL10n.staticText("借出 ") + String(describing: loan.quantity) + WBL10n.staticText(" · 尚欠 ") + String(describing: loan.outstanding) + WBL10n.staticText(" · 工单阻塞 ") + String(describing: loan.blockingQuantity))),
                WBUI.label((WBL10n.staticText("完好归还 ") + String(describing: loan.returnedGood) + WBL10n.staticText(" · 隔离归还 ") + String(describing: loan.returnedQuarantine) + WBL10n.staticText("\n维修耗用 ") + String(describing: loan.consumed) + WBL10n.staticText(" · 批准处置 ") + String(describing: loan.disposed))),
                WBUI.label(WBL10n.staticText("借用责任人：") + loan.borrowerId + WBL10n.staticText("\n归还期限：") + loan.dueAt, size: 13, secondary: true)
            ]
            if !loan.orderId.isEmpty {
                let number = store.orders.first { $0.id == loan.orderId }?.number ?? loan.orderId
                content.append(WBUI.label(WBL10n.staticText("关联工单：") + number, size: 13, secondary: true))
            }
            for transfer in loan.transfers where transfer.int("quantity") > 0 {
                content.append(WBUI.label((WBL10n.staticText("独立跟踪 ") + String(describing: transfer.int("quantity")) + WBL10n.staticText(" 件 · ")) + transfer.string("ownerId") + " · " + transfer.string("dueAt"), size: 13, secondary: true))
            }
            if canHandle, loan.outstanding > 0 {
                content.append(actionButton(loan, action: "return", title: "核对实际归还"))
                if store.actor?.role == "admin" {
                    if !loan.orderId.isEmpty {
                        content.append(actionButton(loan, action: "consume", title: "批准转维修耗用"))
                    }
                    content.append(actionButton(loan, action: "dispose", title: "批准尚欠件处置"))
                    if loan.blockingQuantity > 0 {
                        content.append(actionButton(loan, action: "transfer", title: "正式转为独立跟踪"))
                    }
                }
            }
            rows.append(WBUI.card(content))
        }
        page.replace(rows)
    }

    private func actionButton(_ loan: WBLoan, action: String, title: String) -> UIButton {
        return WBUI.button(title) { [weak self] in
            self?.navigationController?.pushViewControllerByAnimated(WBInventoryFormVC(loan: loan, action: action))
        }
    }
}
