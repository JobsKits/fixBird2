//
//  WBLoginVC.swift
//  WoodpeckerWorkbench
//
//  Created by Jobs on 2026年10月15日，星期四.
//

import UIKit
import JobsByUIKit
import JobsInheritance
import JobsSwiftDSL
import JobsSwiftBaseDefines

final class WBLoginVC: BaseVC {
    private let store = WBStore.shared
    private lazy var page = WBPageView()
    private lazy var username = WBUI.field("账号")
    private lazy var password = WBUI.field("密码", secure: true)
    private lazy var loginButton = WBUI.button("登录", primary: true) { [weak self] in
        self?.login()
    }
    private lazy var settingsButton = WBUI.button("服务地址与外观") { [weak self] in
        self?.navigationController?.pushViewControllerByAnimated(WBSettingsVC())
    }
    private lazy var introduction = WBUI.card([
        WBUI.label("啄木鸟维修平台", size: 28),
        WBUI.label("寄修 · 上门 · 销售，从受理到结算。", secondary: true),
        WBUI.label("请使用已授权账号登录。服务不可达时可进入独立合成演示，演示记录不代表真实业务。", size: 13, secondary: true)
    ])
    private var demoButtons: [UIButton] = []
    private var observer: UUID?

    override func viewDidLoad() {
        super.viewDidLoad()
        jobsSetupGKNav(title: "欢迎使用")
        page.mount(in: self)
        demoButtons = store.demoAccounts.filter { ["admin", "dispatcher", "engineer", "customer", "finance", "warehouse"].contains($0.role) }.map { account in
            WBUI.button("合成账号 · " + account.roleLabel) { [weak self] in
                guard let self, !self.store.isBusy else {
                    return
                }
                self.page.status("正在请求测试服务，无法连接时进入独立合成演示。")
                self.store.enterDemo(role: account.role)
            }
        }
        var rows: [UIView] = [introduction, username, password, loginButton, settingsButton, page.message,
            WBUI.label("合成演示入口", size: 20),
            WBUI.label("先请求测试 API；故障后才进入独立合成数据。账号拒绝认证时保留登录页。请勿录入真实客户资料。", size: 13, secondary: true)
        ]
        rows.append(contentsOf: demoButtons)
        page.replace(rows)
        observer = store.observe { [weak self] in
            self?.page.status(WBStore.shared.sourceLabel + "\n" + WBStore.shared.lastMessage)
        }
    }

    deinit {
        if let observer {
            store.removeObserver(observer)
        }
    }

    private func login() {
        guard let name = username.text?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty,
              let secret = password.text, !secret.isEmpty else {
            page.status("请填写账号和密码。")
            return
        }
        loginButton.byUserInteractionEnabled(false)
        page.status("正在验证账号…")
        store.login(username: name, password: secret) { [weak self] result in
            guard let self else {
                return
            }
            self.loginButton.byUserInteractionEnabled(true)
            switch result {
            /// 根协调器监听actor后进入工作台。
            case .success:
                self.password.byText("")
                self.page.status("登录成功，正在加载工作台。")
            /// 认证错误保留在登录页。
            case .failure(let error):
                self.page.status(error.localizedDescription)
            }
        }
    }
}
