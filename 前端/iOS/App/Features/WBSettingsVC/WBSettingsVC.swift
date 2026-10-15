//
//  WBSettingsVC.swift
//  WoodpeckerWorkbench
//
//  Created by Jobs on 2026年10月15日，星期四.
//

import UIKit
import JobsByUIKit
import JobsInheritance
import JobsSwiftDSL
import JobsSwiftBaseDefines

final class WBSettingsVC: BaseVC {
    private let store = WBStore.shared
    private lazy var page = WBPageView()
    private lazy var endpoint = WBUI.field("服务地址", value: store.endpoint)
    private lazy var timeout = WBUI.field("请求超时（秒，1～10）", value: String(store.timeout))
    private lazy var saveButton = WBUI.button("保存连接设置", primary: true) { [weak self] in
        self?.save()
    }
    private lazy var refreshButton = WBUI.button("重新连接 / 加载") { [weak self] in
        self?.store.refresh()
    }
    private lazy var logoutButton = WBUI.button("退出登录") { [weak self] in
        self?.store.logout()
    }
    private var themeButtons: [UIButton] = []
    private var observer: UUID?

    override func viewDidLoad() {
        super.viewDidLoad()
        jobsSetupGKNav(title: "我的与设置")
        page.mount(in: self)
        themeButtons = WBTheme.Mode.allCases.map { mode in
            WBUI.button(mode.title) { [weak self] in
                WBTheme.set(mode)
                self?.render()
                self?.page.status("已切换为" + mode.title)
            }
        }
        observer = store.observe { [weak self] in
            self?.render()
        }
        render()
    }

    deinit {
        if let observer {
            store.removeObserver(observer)
        }
    }

    private func render() {
        var rows: [UIView] = [
            WBUI.card([
                WBUI.label(store.actor?.name ?? "尚未登录", size: 25),
                WBUI.label(store.actor?.roleLabel ?? "请使用授权账号", secondary: true),
                WBUI.label(store.sourceLabel + "\n" + store.lastMessage, size: 13, secondary: true)
            ]),
            WBUI.label("外观", size: 20)
        ]
        rows.append(contentsOf: themeButtons)
        rows.append(WBUI.label("当前：" + WBTheme.mode.title, size: 13, secondary: true))
        if WBEnvironment.current().editable {
            rows.append(contentsOf: [
                WBUI.label("连接服务", size: 20),
                WBUI.label("模拟器使用电脑的 127.0.0.1；真机填写同网段电脑地址。短超时后保留独立演示。", size: 13, secondary: true),
                endpoint, timeout, saveButton
            ])
        } else {
            rows.append(WBUI.label("生产服务地址由发布配置管理：" + store.endpoint, size: 13, secondary: true))
        }
        rows.append(contentsOf: [refreshButton, page.message])
        if store.actor != nil {
            rows.append(logoutButton)
        }
        page.replace(rows)
    }

    private func save() {
        guard let seconds = TimeInterval(timeout.text ?? ""), (1...10).contains(seconds) else {
            page.status("超时须为1～10秒。")
            return
        }
        do {
            try store.configureEndpoint(endpoint.text ?? "", timeout: seconds)
            page.status("连接设置已更新，请重新登录或加载。")
        } catch {
            page.status(error.localizedDescription)
        }
    }
}
