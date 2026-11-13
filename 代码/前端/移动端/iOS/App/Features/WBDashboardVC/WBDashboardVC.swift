//
//  WBDashboardVC.swift
//  WoodpeckerWorkbench
//
//  Created by Jobs on 2026年10月15日，星期四.
//

import UIKit
import JobsByUIKit
import JobsInheritance
import JobsSwiftDSL
import JobsSwiftBaseDefines

final class WBDashboardVC: BaseVC {
    private let store = WBStore.shared
    private lazy var page = WBPageView()
    private lazy var refreshButton = WBUI.button(WBL10n.staticText("重新加载")) { [weak self] in
        self?.store.refresh()
    }
    private var observer: UUID?

    override func viewDidLoad() {
        super.viewDidLoad()
        jobsSetupGKNav(title: WBL10n.text("维修工作台"))
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

    private func render() {
        let metrics = store.metrics
        let actor = store.actor
        var rows: [UIView] = [
            WBUI.card([
                WBUI.label(WBL10n.staticText("你好，") + (actor?.name ?? ""), size: 25),
                WBUI.label(WBL10n.text(actor?.roleLabel ?? "") + " · " + WBL10n.text(store.sourceLabel), size: 13, secondary: true),
                WBUI.label(WBL10n.text(store.lastMessage), size: 13, secondary: true)
            ]),
            WBUI.card([
                WBUI.label(WBL10n.staticText("当前待办"), size: 20),
                WBUI.label((WBL10n.staticText("履约中 ") + String(describing: metrics.openCount) + WBL10n.staticText(" 单　结算中 ") + String(describing: metrics.settlingCount) + WBL10n.staticText(" 单"))),
                WBUI.label((WBL10n.staticText("待办 ") + String(describing: metrics.tasksCount) + WBL10n.staticText(" 项　被阻塞 ") + String(describing: metrics.blockedCount) + WBL10n.staticText(" 项"))),
                WBUI.label((WBL10n.staticText("可完结 ") + String(describing: metrics.readyCount) + WBL10n.staticText(" 单"))),
                WBUI.label(WBL10n.staticText("待收款 ") + WBUI.money(metrics.remainingCents), size: 22)
            ]),
            refreshButton,
            WBUI.label(WBL10n.staticText("最近工单"), size: 20)
        ]
        if store.orders.isEmpty {
            rows.append(WBUI.empty(WBL10n.staticText("暂无工单"), message: WBL10n.staticText("尚未分配工单或当前条件没有结果")) { [weak self] in
                self?.store.refresh()
            })
        } else {
            for order in store.orders.prefix(6) {
                rows.append(WBUI.button(order.number + " · " + WBL10n.text(order.statusLabel) + "\n" + order.customer + " · " + order.device + "\n" + order.summary.nextTask) { [weak self] in
                    self?.navigationController?.pushViewControllerByAnimated(WBOrderDetailVC(order: order))
                })
            }
        }
        rows.append(WBUI.card([
            WBUI.label(WBL10n.staticText("寄修收件信息"), size: 20),
            WBUI.label(store.settings.companyAddress),
            WBUI.label(store.settings.companyReceiver + "　" + store.settings.companyPhone)
        ]))
        page.replace(rows)
    }
}
