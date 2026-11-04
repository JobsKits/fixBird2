//
//  WBFormField.swift
//  WoodpeckerWorkbench
//
//  Created by Jobs on 2026年10月15日，星期四.
//

import UIKit
import JobsByUIKit
import JobsSwiftDSL
import JobsSwiftBaseDefines

final class WBFormField: UIStackView {
    let key: String
    private let caption: String
    private let kind: WBFieldKind
    private var selected: String
    private var selectedMany: Set<String> = []
    private var optionButtons: [UIButton] = []
    private lazy var emptyOptionLabel = WBUI.label("没有可选记录，请先完成对应业务或重新加载。", secondary: true)
    private lazy var label = WBUI.label(caption, size: 14, secondary: true)
    private lazy var input = WBUI.field(caption, value: selected)
    private lazy var textInput = UITextView.jobsMake { text in
        text.byText(selected)
            .byFont(JobsFont.systemFont(ofSize: 16))
            .byTextColor(JobsCor.label)
            .byBackgroundColor(JobsCor.tertiarySystemGroupedBackground)
            .byCornerRadius(8)
            .byHeight(110)
    }

    private var businessCalendar: Calendar {
        return WBActionCatalog.businessCalendar
    }
    private lazy var datePicker = UIDatePicker.jobsMake { picker in
        let parsed = ISO8601DateFormatter.jobsMake { _ in }.date(from: selected)
            ?? ISO8601DateFormatter.jobsMake { _ in }.date(from: selected + "T12:00:00+08:00")
            ?? Date()
        let mode: UIDatePicker.Mode
        if case .date = kind {
            mode = .date
        } else {
            mode = .dateAndTime
        }
        picker.byDatePickerMode(mode)
            .byPreferredDatePickerStyle(.compact)
            .byLocale(Locale(identifier: "zh_CN"))
            .byCalendar(businessCalendar)
            .byTimeZone(businessCalendar.timeZone)
            .byDate(parsed)
    }

    init(_ key: String, _ caption: String, kind: WBFieldKind = .text, value: String = "") {
        self.key = key
        self.caption = caption
        self.kind = kind
        self.selected = value
        super.init(frame: .zero)
        byAxis(.vertical)
            .bySpacing(7)
            .byAddArrangedSubview(label)
        switch kind {
        /// 多行事实说明保留输入。
        case .multiline:
            byAddArrangedSubview(textInput)
        /// 选择项只暴露业务文案。
        case .choice(let options):
            if selected.isEmpty {
                selected = options.first?.0 ?? ""
            }
            installOptions(options, multiple: false)
        /// 附件等多选引用只使用现有合法资料。
        case .multiple(let options):
            selectedMany = Set(value.split(separator: ",").map(String.init))
            installOptions(options, multiple: true)
        /// 原生日期选择器避免业务人员输入技术格式。
        case .date, .dateTime:
            byAddArrangedSubview(datePicker)
        /// 文本及数字统一输入后严格校验。
        default:
            byAddArrangedSubview(input)
        }
    }

    required init(coder: NSCoder) {
        fatalError("仅支持代码初始化")
    }

    var string: String {
        switch kind {
        /// 多行编辑器。
        case .multiline:
            return textInput.text ?? ""
        /// 单选值来自可见选项。
        case .choice:
            return selected
        /// 多选仅用于展示摘要，实际value返回数组。
        case .multiple:
            return selectedMany.sorted().joined(separator: ",")
        /// 日期在本地选择，提交时才转换标准时间。
        case .date:
            let end = businessCalendar.date(bySettingHour: 23, minute: 59, second: 59, of: datePicker.date) ?? datePicker.date
            return ISO8601DateFormatter.jobsMake { _ in }.string(from: end)
        /// 具体交接时间保留真实瞬间，选择器按北京时间显示。
        case .dateTime:
            return ISO8601DateFormatter.jobsMake { _ in }.string(from: datePicker.date)
        /// 普通编辑器。
        default:
            return input.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        }
    }

    func value() throws -> Any {
        switch kind {
        /// 金额按整数分提交。
        case .money:
            return try WBUI.cents(string)
        /// 数量与月数必须为整数。
        case .integer:
            guard let value = Int(string), value >= 0 else {
                throw WBUIError(caption + "须为非负整数。")
            }
            return value
        /// 多选使用真实引用ID。
        case .multiple:
            return selectedMany.sorted()
        /// 其余保留原始业务文字。
        default:
            return string
        }
    }

    private func installOptions(_ options: [(String, String)], multiple: Bool) {
        if options.isEmpty {
            byAddArrangedSubview(emptyOptionLabel)
        }
        optionButtons = options.map { option in
            WBUI.button(display(option, multiple: multiple)) { [weak self] in
                guard let self else {
                    return
                }
                if multiple {
                    if self.selectedMany.contains(option.0) {
                        self.selectedMany.remove(option.0)
                    } else {
                        self.selectedMany.insert(option.0)
                    }
                } else {
                    self.selected = option.0
                }
                for (index, button) in self.optionButtons.enumerated() {
                    button.byTitle(self.display(options[index], multiple: multiple))
                }
            }
        }
        byAddArrangedSubviews(optionButtons)
    }

    private func display(_ option: (String, String), multiple: Bool) -> String {
        let active = multiple ? selectedMany.contains(option.0) : selected == option.0
        return (active ? "已选 · " : "") + option.1
    }
}
