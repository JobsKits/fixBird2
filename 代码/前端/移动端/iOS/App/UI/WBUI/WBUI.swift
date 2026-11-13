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

    static func label(_ text: String, size: CGFloat = 16, secondary: Bool = false) -> UILabel {
        return UILabel.jobsMake { label in
            label.byText(WBL10n.text(text))
                .byFont(JobsFont.preferredFont(forTextStyle: size >= 25 ? .title1 : size >= 20 ? .title3 : size <= 13 ? .footnote : .body))
                .byAdjustsFontForContentSizeCategory(true)
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
                            .byCornerRadius(10)
                    )
                    .byContentInsets(NSDirectionalEdgeInsets(top: 15, leading: 16, bottom: 15, trailing: 16))
            )
            .byTitle(WBL10n.text(title))
            .byTitleFont(JobsFont.preferredFont(forTextStyle: .headline))
            .byContentHorizontalAlignment(.leading)
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
                    .byCornerRadius(10)))
        }
        return button.byTitleColor(primary ? JobsCor.white : JobsCor.label)
    }

    static func stack(_ rows: [UIView] = [], spacing: CGFloat = 16) -> UIStackView {
        return UIStackView.jobsMake { stack in
            stack.byAxis(.vertical)
                .bySpacing(spacing)
                .byAddArrangedSubviews(rows)
        }
    }

    static func card(_ rows: [UIView]) -> UIStackView {
        return stack(rows, spacing: 12)
            .byLayoutMargins(UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16), relative: true)
            .byBackgroundColor(JobsCor.secondarySystemGroupedBackground)
            .byCornerRadius(16)
    }

    static func field(_ placeholder: String, value: String = "", secure: Bool = false) -> UITextField {
        let field = UITextField.jobsMake { field in
            field.byPlaceholder(WBL10n.text(placeholder))
                .byText(value)
                .byFont(JobsFont.preferredFont(forTextStyle: .body))
                .byAdjustsFontForContentSizeCategory(true)
                .byTextColor(JobsCor.label)
                .byBackgroundColor(JobsCor.tertiarySystemGroupedBackground)
                .byBorderStyle(.roundedRect)
                .byAutocapitalizationType(.none)
                .byAutocorrectionType(.no)
                .bySecureTextEntry(secure)
                .byHeight(52)
        }
        field.snp.makeConstraints { make in
            make.height.greaterThanOrEqualTo(52)
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
            .byTitle(WBL10n.text(title))
            .bySubTitle(WBL10n.text(message) + " · " + WBL10n.text("重新加载"))
            .byImage(UIImage.make(named: "RepairLogo"))
            .byHeight(160)
            .onTap { _ in
                reload()
            }
    }
}

enum WBL10n {
    static let languages: [(String, String)] = [
        ("zh-Hans", "简体中文"), ("zh-Hant", "繁體中文"), ("bo", "བོད་ཡིག"),
        ("en", "English"), ("ja", "日本語"), ("fr", "Français"),
        ("es", "Español"), ("de", "Deutsch"), ("ru", "Русский"), ("ko", "한국어")
    ]
    static var didChange: (() -> Void)?
    static var language: String {
        get {
            return UserDefaults.standard.string(forKey: "WBUI.language") ?? "zh-Hans"
        }
        set {
            guard languages.contains(where: { $0.0 == newValue }) else {
                return
            }
            UserDefaults.standard.set(newValue, forKey: "WBUI.language")
            didChange?()
        }
    }
    private static let messages: [String: [String: String]] = {
        guard let url = Bundle.main.url(forResource: "ui-l10n", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let catalog = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return [:]
        }
        return catalog["messages"] as? [String: [String: String]] ?? [:]
    }()

    private static func literal(_ value: String) -> String {
        let direct = text(value)
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if direct != value, trimmed != value, let range = value.range(of: trimmed) {
            return String(value[..<range.lowerBound]) + direct.trimmingCharacters(in: .whitespacesAndNewlines) + String(value[range.upperBound...])
        }
        guard direct == value, !trimmed.isEmpty,
              let pair = messages[language]?.first(where: { $0.key.trimmingCharacters(in: .whitespacesAndNewlines) == trimmed }),
              let range = value.range(of: trimmed) else {
            return direct
        }
        return String(value[..<range.lowerBound]) + pair.value.trimmingCharacters(in: .whitespacesAndNewlines) + String(value[range.upperBound...])
    }

    // Called only for source literals, before business values are appended.
    static func staticText(_ value: String) -> String {
        let direct = literal(value)
        guard direct == value else {
            return direct
        }
        var result = ""
        var word = ""
        for character in value {
            let separator = character.unicodeScalars.allSatisfy { scalar in
                CharacterSet.whitespacesAndNewlines.contains(scalar) || CharacterSet.punctuationCharacters.contains(scalar)
            }
            if separator {
                result += literal(word)
                word = ""
                result.append(character)
            } else {
                word.append(character)
            }
        }
        return result + literal(word)
    }

    static func text(_ value: String) -> String {
        return messages[language]?[value] ?? value
    }
}
