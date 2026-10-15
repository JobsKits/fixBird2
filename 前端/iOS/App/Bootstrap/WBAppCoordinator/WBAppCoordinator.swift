//
//  WBAppCoordinator.swift
//  RepairWorkbench
//
//  Created by Jobs on 2026年10月15日，星期四.
//

import UIKit

import JobsByUIKit
import JobsSwiftBaseDefines

@MainActor
final class WBAppCoordinator {
    private weak var window: UIWindow?
    private var observer: UUID?
    private var identity: String?
    private var navigationControllers: [UINavigationController] = []
    private var tabs: UITabBarController?
    private var login: WBLoginVC?

    lazy var rootViewController: UIViewController = {
        makeRoot()
    }()

    func attach(to window: UIWindow) {
        self.window = window
        identity = currentIdentity()
        observer = WBStore.shared.observe { [weak self] in
            self?.synchronizeIdentity()
        }
    }

    deinit {
        if let observer {
            WBStore.shared.removeObserver(observer)
        }
    }

    private func currentIdentity() -> String? {
        guard let actor = WBStore.shared.actor else {
            return nil
        }
        return [actor.id, actor.role, actor.companyId, String(actor.authVersion),
                WBStore.shared.endpoint, WBStore.shared.isDemo ? "demo" : "server"].joined(separator: "|")
    }

    private func synchronizeIdentity() {
        let nextIdentity = currentIdentity()
        guard identity != nextIdentity else {
            return
        }
        identity = nextIdentity
        rootViewController = makeRoot()
        window?.byRootViewController(rootViewController)
        if let window {
            WBTheme.apply(to: window)
        }
    }

    private func makeRoot() -> UIViewController {
        navigationControllers.removeAll()
        tabs = nil
        login = nil
        guard WBStore.shared.actor != nil else {
            let controller = WBLoginVC()
            login = controller
            return makeNavigation(controller, title: "登录")
        }
        navigationControllers = [
            makeNavigation(WBDashboardVC(), title: "工作台"),
            makeNavigation(WBOrdersVC(), title: "工单"),
            makeNavigation(WBInventoryVC(), title: "库存借还"),
            makeNavigation(WBSettingsVC(), title: "我的")
        ]
        let controller = UITabBarController.jobsMake { tab in
            tab.byViewControllers(navigationControllers)
                .byTabBarTintColor(JobsCor.label)
                .byTabBarBackgroundColor(JobsCor.systemBackground)
        }
        tabs = controller
        return controller
    }

    private func makeNavigation(_ controller: UIViewController, title: String) -> UINavigationController {
        return UINavigationController.jobsMake { navigation in
            navigation.byViewControllers([controller])
                .byTitle(title)
        }
    }
}
