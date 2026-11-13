//
//  WBOrdersVC.swift
//  WoodpeckerWorkbench
//
//  Created by Jobs on 2026年10月15日，星期四.
//

import UIKit
import JobsByUIKit
import JobsInheritance
import JobsSwiftDSL
import JobsSwiftBaseDefines

final class WBOrdersVC: BaseVC {
    private let store = WBStore.shared
    private lazy var page = WBPageView()
    private lazy var search = WBUI.field("工单号、客户、设备或项目")
    private lazy var status = WBFormField("status", "工单状态", kind: .choice(
        [("", "全部状态")] + WBOrder.statusLabels.keys.sorted().map { ($0, WBOrder.statusLabels[$0] ?? $0) }
    ))
    private lazy var searchButton = WBUI.button(WBL10n.staticText("搜索"), primary: true) { [weak self] in
        guard let self else {
            return
        }
        self.store.setQuery(self.search.text ?? "", status: self.status.string)
    }
    private lazy var createButton = WBUI.button(WBL10n.staticText("新建工单")) { [weak self] in
        self?.navigationController?.pushViewControllerByAnimated(WBOrderFormVC())
    }
    private lazy var refreshButton = WBUI.button(WBL10n.staticText("重新加载")) { [weak self] in
        self?.store.refresh()
    }
    private lazy var moreButton = WBUI.button(WBL10n.staticText("加载更多")) { [weak self] in
        self?.store.loadMore()
    }
    private var observer: UUID?

    override func viewDidLoad() {
        super.viewDidLoad()
        jobsSetupGKNav(title: WBL10n.text("工单"))
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
        var rows: [UIView] = [search, status, searchButton, refreshButton]
        if ["admin", "dispatcher", "customer"].contains(store.actor?.role ?? "") {
            rows.append(createButton)
        }
        rows.append(WBUI.label(WBL10n.text(store.sourceLabel) + (" · " + String(describing: store.orders.count) + WBL10n.staticText(" 单\n")) + WBL10n.text(store.lastMessage), size: 13, secondary: true))
        if store.orders.isEmpty {
            rows.append(WBUI.empty(WBL10n.staticText("没有匹配的工单"), message: WBL10n.staticText("调整搜索条件或重新加载")) { [weak self] in
                self?.store.refresh()
            })
        }
        for order in store.orders {
            rows.append(WBUI.button(order.number + " · " + WBL10n.text(order.typeLabel) + "\n" + order.customer + " · " + order.device + "\n" + WBL10n.text(order.statusLabel) + " · " + order.summary.nextTask + WBL10n.staticText("\n待收 ") + WBUI.money(order.summary.remainingCents)) { [weak self] in
                self?.navigationController?.pushViewControllerByAnimated(WBOrderDetailVC(order: order))
            })
        }
        if store.hasMore {
            rows.append(moreButton)
        }
        page.replace(rows)
    }
}
