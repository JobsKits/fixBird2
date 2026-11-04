//
//  WBTheme.swift
//  WoodpeckerWorkbench
//
//  Created by Jobs on 2026年10月15日，星期四.
//

import UIKit
import JobsSwiftBaseDefines
import JobsSwiftDSL

@MainActor
enum WBTheme {
    enum Mode: String, CaseIterable {
        case system
        case light
        case dark

        var title: String {
            switch self {
            /// 跟随当前窗口的系统外观。
            case .system:
                return "跟随系统"
            /// 明亮阅读主题。
            case .light:
                return "白天"
            /// 深色阅读主题。
            case .dark:
                return "黑夜"
            }
        }

        var interfaceStyle: UIUserInterfaceStyle {
            switch self {
            /// 不对根控制器强制外观。
            case .system:
                return .unspecified
            /// 固定浅色。
            case .light:
                return .light
            /// 固定深色。
            case .dark:
                return .dark
            }
        }
    }

    private static var configured = false

    static func configureIfNeeded() {
        guard !configured else {
            return
        }
        configured = (try? JobsThemeCenter.shared.configure(resource: "JobsThemeResources")) != nil
    }

    static let didChange = Notification.Name.JobsThemeDidChange
    static var mode: Mode {
        return Mode(rawValue: UserDefaults.standard.string(forKey: "WBTheme.mode") ?? "") ?? .system
    }

    static func set(_ value: Mode) {
        UserDefaults.standard.set(value.rawValue, forKey: "WBTheme.mode")
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .forEach { apply(to: $0) }
    }

    static func apply(to window: UIWindow) {
        window.rootViewController?.byOverrideUserInterfaceStyle(mode.interfaceStyle)
        sync(with: window.traitCollection)
    }

    static func sync(with traits: UITraitCollection) {
        configureIfNeeded()
        let style = mode == .system ? traits.userInterfaceStyle : mode.interfaceStyle
        JobsThemeCenter.shared.setStyle(style == .dark ? .dark : .light)
    }
}
