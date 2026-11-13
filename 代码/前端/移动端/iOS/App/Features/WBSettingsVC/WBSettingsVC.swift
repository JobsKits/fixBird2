//
//  WBSettingsVC.swift
//  WoodpeckerWorkbench
//
//  Created by Jobs on 2026年10月15日，星期四.
//

import UIKit
import SnapKit
import JobsByUIKit
import JobsInheritance
import JobsSwiftDSL
import JobsSwiftBaseDefines

final class WBSettingsVC: BaseVC, UIPickerViewDataSource, UIPickerViewDelegate {
    private let store = WBStore.shared
    private lazy var page = WBPageView()
    private lazy var endpoint = WBUI.field("服务地址", value: store.endpoint)
    private lazy var timeout = WBUI.field("请求超时（秒，1～10）", value: String(store.timeout))
    private lazy var saveButton = WBUI.button(WBL10n.staticText("保存连接设置"), primary: true) { [weak self] in
        self?.save()
    }
    private lazy var refreshButton = WBUI.button(WBL10n.staticText("重新连接 / 加载")) { [weak self] in
        self?.store.refresh()
    }
    private lazy var logoutButton = WBUI.button(WBL10n.staticText("退出登录")) { [weak self] in
        self?.store.logout()
    }
    private lazy var languagePicker = UIPickerView.jobsMake { picker in
        picker.byDelegate(self)
            .byDataSource(self)
            .bySelectRow(WBL10n.languages.firstIndex(where: { $0.0 == WBL10n.language }) ?? 0, inComponent: 0, animated: false)
            .byHeight(144)
    }
    private lazy var languageButton = WBUI.button(WBL10n.staticText("应用语言")) { [weak self] in
        guard let self else {
            return
        }
        WBL10n.language = WBL10n.languages[self.languagePicker.selectedRow(inComponent: 0)].0
    }
    private var themeButtons: [UIButton] = []
    private var observer: UUID?

    override func viewDidLoad() {
        super.viewDidLoad()
        languagePicker.snp.makeConstraints { make in
            make.height.equalTo(144)
        }
        jobsSetupGKNav(title: WBL10n.text("我的与设置"))
        if navigationController?.viewControllers.first === self {
            gk_navLeftBarButtonItem?.byHidden(true)
        }
        page.mount(in: self)
        themeButtons = WBTheme.Mode.allCases.map { mode in
            WBUI.button(mode.title) { [weak self] in
                WBTheme.set(mode)
                self?.render()
                self?.page.status(WBL10n.staticText("已切换为") + WBL10n.text(mode.title))
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
                WBUI.label(store.actor?.name ?? WBL10n.staticText("尚未登录"), size: 25),
                WBUI.label(WBL10n.text(store.actor?.roleLabel ?? "请使用授权账号"), secondary: true),
                WBUI.label(WBL10n.text(store.sourceLabel) + "\n" + WBL10n.text(store.lastMessage), size: 13, secondary: true)
            ]),
            WBUI.label(WBL10n.staticText("外观"), size: 20)
        ]
        rows.append(contentsOf: themeButtons)
        rows.append(WBUI.label(WBL10n.staticText("当前：") + WBL10n.text(WBTheme.mode.title), size: 13, secondary: true))
        rows.append(WBUI.card([WBUI.label(WBL10n.staticText("语言"), size: 20), languagePicker, languageButton]))
        if WBEnvironment.current().editable {
            rows.append(contentsOf: [
                WBUI.label(WBL10n.staticText("连接服务"), size: 20),
                WBUI.label(WBL10n.staticText("模拟器使用电脑的 127.0.0.1；真机填写同网段电脑地址。短超时后保留独立演示。"), size: 13, secondary: true),
                endpoint, timeout, saveButton
            ])
        } else {
            rows.append(WBUI.label(WBL10n.staticText("生产服务地址由发布配置管理：") + store.endpoint, size: 13, secondary: true))
        }
        rows.append(contentsOf: [refreshButton, page.message])
        if store.actor != nil {
            rows.append(logoutButton)
        }
        page.replace(rows)
    }

    private func save() {
        guard let seconds = TimeInterval(timeout.text ?? ""), (1...10).contains(seconds) else {
            page.status(WBL10n.staticText("超时须为1～10秒。"))
            return
        }
        do {
            try store.configureEndpoint(endpoint.text ?? "", timeout: seconds)
            page.status(WBL10n.staticText("连接设置已更新，请重新登录或加载。"))
        } catch {
            page.status(error.localizedDescription)
        }
    }

    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }

    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return WBL10n.languages.count
    }

    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return WBL10n.languages[row].1
    }
}
