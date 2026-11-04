//
//  WBUI.swift
//  WoodpeckerWorkbench
//
//  Created by Jobs on 2026年10月15日，星期四.
//

import UIKit
import SnapKit
import JobsByUIKit
import JobsSwiftDSL
import JobsSwiftBaseDefines

enum WBUI {
    static var brand: UIColor {
        return UIColor(r: 15, g: 81, b: 68, a: 1)
    }

    static func label(_ text: String, size: CGFloat = 15, secondary: Bool = false) -> UILabel {
        return UILabel.jobsMake { label in
            label.byText(text)
                .byFont(JobsFont.systemFont(ofSize: size, weight: size >= 20 ? .semibold : .regular))
                .byTextColor(secondary ? JobsCor.secondaryLabel : JobsCor.label)
                .byNumberOfLines(0)
        }
    }

    static func button(_ title: String, primary: Bool = false, action: @escaping () -> Void) -> UIButton {
        let button = UIButton.sys()
            .byConfiguration(
                UIButton.Configuration.filled()
                    .byBaseBackgroundColor(primary ? brand : JobsCor.secondarySystemGroupedBackground)
                    .byBaseForegroundColor(primary ? JobsCor.white : JobsCor.label)
                    .byBackground(
                        UIBackgroundConfiguration.clear()
                            .byBackgroundColor(primary ? brand : JobsCor.secondarySystemGroupedBackground)
                            .byCornerRadius(12)
                    )
                    .byContentInsets(NSDirectionalEdgeInsets(top: 13, leading: 14, bottom: 13, trailing: 14))
            )
            .byTitle(title)
            .byTitleFont(JobsFont.systemFont(ofSize: 15, weight: .semibold))
            .byNumberOfLines(0)
            .byLineBreakMode(.byWordWrapping)
            .onTap { _ in
                action()
            }
        JobsThemeCenter.shared.bind(button, slot: "WBUI.button.configuration") { object, center in
            guard let target = object as? UIButton else {
                return
            }
            let background = primary ? brand : center.resolvedColor(.backgroundGroupedSecondary)
            let foreground = primary ? JobsCor.white : center.resolvedColor(.textPrimary)
            let configuration = target.configuration ?? .filled()
            target.byConfiguration(configuration
                .byBaseBackgroundColor(background)
                .byBaseForegroundColor(foreground)
                .byBackground(configuration.background
                    .byBackgroundColor(background)
                    .byCornerRadius(12)))
        }
        return button.byTitleColor(primary ? JobsCor.white : JobsCor.label)
    }

    static func stack(_ rows: [UIView] = [], spacing: CGFloat = 12) -> UIStackView {
        return UIStackView.jobsMake { stack in
            stack.byAxis(.vertical)
                .bySpacing(spacing)
                .byAddArrangedSubviews(rows)
        }
    }

    static func card(_ rows: [UIView]) -> UIStackView {
        return stack(rows, spacing: 10)
            .byLayoutMargins(UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16), relative: true)
            .byBackgroundColor(JobsCor.secondarySystemGroupedBackground)
            .byCornerRadius(16)
    }

    static func field(_ placeholder: String, value: String = "", secure: Bool = false) -> UITextField {
        let field = UITextField.jobsMake { field in
            field.byPlaceholder(placeholder)
                .byText(value)
                .byFont(JobsFont.systemFont(ofSize: 16))
                .byTextColor(JobsCor.label)
                .byBorderStyle(.roundedRect)
                .byAutocapitalizationType(.none)
                .byAutocorrectionType(.no)
                .bySecureTextEntry(secure)
                .byHeight(46)
        }
        if !placeholder.isEmpty {
            JobsThemeCenter.shared.bind(field, slot: "WBUI.field.placeholder") { object, _ in
                guard let target = object as? UITextField else {
                    return
                }
                target.byPlaceholderColor(JobsCor.placeholderText)
            }
        }
        return field
    }

    static func money(_ cents: Int64) -> String {
        return String(format: "¥%.2f", Double(cents) / 100)
    }

    static func cents(_ text: String) throws -> Int64 {
        let raw = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = raw.split(separator: ".", omittingEmptySubsequences: false)
        guard !parts.isEmpty, parts.count <= 2, !parts[0].isEmpty,
              parts[0].allSatisfy({ $0.isASCII && $0.isNumber }),
              parts.count == 1 || (parts[1].count <= 2 && parts[1].allSatisfy({ $0.isASCII && $0.isNumber })),
              let whole = Int64(parts[0]), whole <= 1_000_000 else {
            throw WBUIError("请输入正确金额，最多两位小数，范围不超过100万元。")
        }
        let decimal = parts.count == 2 ? String(parts[1]) : ""
        return whole * 100 + (Int64(decimal.padding(toLength: 2, withPad: "0", startingAt: 0)) ?? 0)
    }

    static func empty(_ title: String, message: String, reload: @escaping () -> Void) -> UIButton {
        return JobsEmptyAuto.Config.defaultProvider()
            .byTitle(title)
            .bySubTitle(message + " · 点击重新加载")
            .byImage(UIImage.make(named: "RepairLogo"))
            .byHeight(160)
            .onTap { _ in
                reload()
            }
    }
}
