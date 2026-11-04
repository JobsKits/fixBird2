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
    private lazy var refreshButton = WBUI.button("重新加载库存与借还") { [weak self] in
        self?.store.refresh()
    }
    private lazy var borrowButton = WBUI.button("登记实际借出", primary: true) { [weak self] in
        self?.navigationController?.pushViewControllerByAnimated(WBInventoryFormVC())
    }
    private var observer: UUID?

    override func viewDidLoad() {
        super.viewDidLoad()
        jobsSetupGKNav(title: "库存与借还")
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
            WBUI.label(store.sourceLabel + "\n" + store.lastMessage, size: 13, secondary: true),
            refreshButton
        ]
        if canHandle {
            rows.append(borrowButton)
        }
        rows.append(WBUI.label("配件库存", size: 22))
        if store.parts.isEmpty {
            rows.append(WBUI.empty("没有可见库存", message: "当前账号没有可见配件或尚未建库") { [weak self] in
                self?.store.refresh()
            })
        }
        for part in store.parts {
            rows.append(WBUI.card([
                WBUI.label(part.name, size: 18),
                WBUI.label("型号 " + part.sku),
                WBUI.label("可用 \(part.available) 件　隔离 \(part.quarantine) 件")
            ]))
        }
        rows.append(WBUI.label("借用台账", size: 22))
        if store.loans.isEmpty {
            rows.append(WBUI.empty("暂无借用记录", message: "实际借出后会生成独立记录") { [weak self] in
                self?.store.refresh()
            })
        }
        for loan in store.loans {
            var content: [UIView] = [
                WBUI.label(loan.partName, size: 18),
                WBUI.label("借出 \(loan.quantity) · 尚欠 \(loan.outstanding) · 工单阻塞 \(loan.blockingQuantity)"),
                WBUI.label("完好归还 \(loan.returnedGood) · 隔离归还 \(loan.returnedQuarantine)\n维修耗用 \(loan.consumed) · 批准处置 \(loan.disposed)"),
                WBUI.label("借用责任人：" + loan.borrowerId + "\n归还期限：" + loan.dueAt, size: 13, secondary: true)
            ]
            if !loan.orderId.isEmpty {
                let number = store.orders.first { $0.id == loan.orderId }?.number ?? loan.orderId
                content.append(WBUI.label("关联工单：" + number, size: 13, secondary: true))
            }
            for transfer in loan.transfers where transfer.int("quantity") > 0 {
                content.append(WBUI.label("独立跟踪 \(transfer.int("quantity")) 件 · " + transfer.string("ownerId") + " · " + transfer.string("dueAt"), size: 13, secondary: true))
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
