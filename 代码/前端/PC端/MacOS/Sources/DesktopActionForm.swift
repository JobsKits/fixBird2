//
//  DesktopActionForm.swift
//  RepairDesktop
//
//  Created by Jobs on 2026年11月18日，星期三.
//

import AppKit
import SwiftUI

struct DesktopActionForm: View {
    @EnvironmentObject private var model: DesktopModel
    @Environment(\.dismiss) private var dismiss
    let order: WBOrder
    let action: String
    @State private var values: [String: String] = [:]
    @State private var signature: [[CGPoint]] = []
    @State private var dates: [String: Date] = [:]
    @State private var saving = false
    @State private var error = ""
    @State private var context = ""
    @State private var consent = false
    private var spec: DesktopAction {
        DesktopAction.all[action]!
    }

    private var currentContext: String {
        (model.store.actor?.id ?? "") + String(model.store.actor?.authVersion ?? 0)
            + model.store.endpoint + String(model.store.isDemo)
    }

    private var businessCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        return calendar
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(model.text(spec.title)).font(.title2)
            Text(order.number + " · " + model.text(order.statusLabel)).foregroundStyle(.secondary)
            Text(model.text("仅按已经发生、已经核实的事实填写。办理权限和当前业务条件以服务端确认为准。"))
                .font(.caption).foregroundStyle(.secondary)
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if action == "sign_quote" || action == "accept" {
                        Text(order.quote.description).textSelection(.enabled)
                        Text(model.text("含税总价（元）") + " " + WBFoundation.amount(order.quote.amountCents))
                        Text(model.text("约定预付款（元，可为零）") + " " + WBFoundation.amount(order.quote.prepayCents))
                        Text(model.text(order.quote.startRequiresPrepayment ? "已明确约定，核实约定预付款后开修" : "未约定先款开修"))
                        Text(model.text(order.quote.autoAccept ? "客户已接受，凭完整交付启动" : "未接受，不自动验收"))
                        Text(order.quote.validUntil + " · " + String(order.quote.warrantyMonths))
                        Toggle(model.text("我已阅读并确认以上条款"), isOn: $consent)
                    }

                    ForEach(
                        spec.fields.filter {
                            $0.key != "remark"
                                || ["admin", "dispatcher", "engineer", "finance"].contains(
                                    model.store.actor?.role ?? "")
                        }, id: \.key
                    ) {
                        field in
                        editor(field)
                    }
                }.padding(4)
            }

            Text(model.text(error)).foregroundStyle(.red).textSelection(.enabled)
            HStack {
                Button(model.text("取消")) {
                    dismiss()
                }.disabled(saving).keyboardShortcut(.cancelAction)
                Spacer()
                Button(model.text("确认提交"), action: submit).keyboardShortcut(.defaultAction).disabled(saving)
            }
        }.interactiveDismissDisabled(saving).padding(24).frame(width: 620, height: 650)
            .onAppear {
                context = currentContext
                for f in spec.fields {
                    values[f.key] = initial(f)
                    dates[f.key] = f.value == "$future" ? Date().addingTimeInterval(30 * 86400) : Date()
                }
            }
    }

    @ViewBuilder private func editor(_ f: DesktopAction.Field) -> some View {
        VStack(alignment: .leading) {
            Text(model.text(f.title)).font(.headline)
            switch f.kind {
            case "bool":
                Toggle(
                    model.text("是"),
                    isOn: Binding(
                        get: {
                            values[f.key] == "true"
                        },
                        set: {
                            values[f.key] = String($0)
                        }
                    ))
            case "choice", "ref":
                Picker("", selection: binding(f.key)) {
                    Text(model.text("请选择")).tag("")
                    ForEach(options(f), id: \.0) {
                        option in Text(model.text(option.1)).tag(option.0)
                    }
                }.labelsHidden()
            case "refs":
                ForEach(options(f), id: \.0) {
                    option in
                    Toggle(
                        option.1,
                        isOn: Binding(
                            get: {
                                (values[f.key] ?? "").split(separator: ",").contains(Substring(option.0))
                            },
                            set: {
                                selected in
                                var ids = Set((values[f.key] ?? "").split(separator: ",").map(String.init))
                                if selected {
                                    ids.insert(option.0)
                                } else {
                                    ids.remove(option.0)
                                }

                                values[f.key] = ids.sorted().joined(separator: ",")
                            }
                        ))
                }

            case "date", "instant":
                DatePicker(
                    "",
                    selection: Binding(
                        get: {
                            dates[f.key] ?? Date()
                        },
                        set: {
                            dates[f.key] = $0
                        }
                    ),
                    displayedComponents: f.kind == "date" ? [.date] : [.date, .hourAndMinute]
                ).labelsHidden()
                    .environment(\.calendar, businessCalendar).environment(
                        \.timeZone, businessCalendar.timeZone)
            case "integer" where f.key == "quoteVersion":
                Text(String(order.quote.version))
            case "signature":
                DesktopSignature(strokes: $signature)
                Button(model.text("清除签名")) {
                    signature = []
                }

            default:
                TextField("", text: binding(f.key), axis: .vertical).lineLimit(2...5).textFieldStyle(
                    .roundedBorder)
            }
        }
    }

    private func binding(_ key: String) -> Binding<String> {
        Binding(
            get: {
                values[key] ?? ""
            },
            set: {
                values[key] = $0
            }
        )
    }

    private func options(_ f: DesktopAction.Field) -> [(String, String)] {
        if f.kind == "choice" {
            let labels = [
                "cash": "现金约定", "credit": "批准企业账期", "receipt": "收到现金", "refund": "实际退还现金", "unknown": "待确认",
                "required": "需要真实资料", "none": "无需，已有确认依据", "customer_refused": "客户拒修",
                "company_refused": "公司拒修", "unrepairable": "确认不能修", "cancelled": "批准取消",
                "negotiated": "按协商停止",
            ]
            return f.options.map {
                ($0, labels[$0] ?? $0)
            }
        }

        if f.value == "parts" {
            return model.store.parts.map {
                ($0.id, $0.name)
            }
        }

        return order.records(f.value).filter {
            !$0.bool("deleted") && !$0.bool("resolved")
        }.map {
            (
                $0.id,
                [$0.string("number"), $0.string("name"), $0.string("title"), $0.string("note")].first {
                    !$0.isEmpty
                }
                    ?? $0.id
            )
        }
    }

    private func initial(_ f: DesktopAction.Field) -> String {
        switch f.value {
        case "$owner":
            return order.ownerId
        case "$assignee":
            return order.assigneeId
        case "$amount":
            return String(
                format:
                    "%.2f", Double(order.quote.amountCents) / 100)
        case "$receivable":
            return String(
                format:
                    "%.2f", Double(order.summary.receivableCents) / 100)
        case "$quoteVersion":
            return String(order.quote.version)
        case "$remark":
            return order.remark
        case "$customerNote":
            return order.customerNote
        default: return f.kind == "ref" || f.kind == "refs" ? "" : f.value
        }
    }

    private func submit() {
        guard context == currentContext, model.store.actor != nil else {
            error = model.text("身份或数据来源已改变，请重新打开当前单据。")
            return
        }

        if (action == "sign_quote" || action == "accept") && !consent {
            error = model.text("请先阅读并确认条款")
            return
        }

        var payload: [String: Any] = [:]
        for f in spec.fields {
            if f.key == "remark"
                && !["admin", "dispatcher", "engineer", "finance"].contains(model.store.actor?.role ?? "")
            {
                continue
            }

            let value = values[f.key] ?? ""
            switch f.kind {
            case "money":
                guard let decimal = Decimal(string: value, locale: Locale(identifier: "en_US_POSIX")),
                    decimal >= 0
                else {
                    error = model.text("请输入有效金额")
                    return
                }

                let cents = decimal * 100
                guard cents <= Decimal(Int64.max),
                    NSDecimalNumber(decimal: cents).decimalValue
                        == Decimal(NSDecimalNumber(decimal: cents).int64Value)
                else {
                    error = model.text("请输入有效金额")
                    return
                }

                payload[f.key] = NSDecimalNumber(decimal: cents).int64Value
            case "integer":
                guard let number = Int(value), number >= 0 else {
                    error = model.text("请输入有效整数")
                    return
                }

                payload[f.key] = number
            case "bool":
                payload[f.key] = value == "true"
            case "refs":
                payload[f.key] = value.split(
                    separator:
                        ","
                ).map(String.init)
            case "date", "instant":
                let selected = dates[f.key] ?? Date()
                let date =
                    f.kind == "date"
                    ? businessCalendar.date(bySettingHour: 23, minute: 59, second: 59, of: selected)
                        ?? selected : selected
                payload[f.key] = WBFoundation.nowForDesktop(date)
            case "signature":
                guard
                    signature.reduce(
                        0,
                        {
                            $0 + $1.count
                        }
                    ) >= 12,
                    let png = DesktopSignature.png(signature)
                else {
                    error = model.text("请实际手写签名")
                    return
                }

                payload[f.key] = "data:image/png;base64," + png.base64EncodedString()
            default: payload[f.key] = value
            }
        }

        if action == "evidence" {
            payload["kind"] = "text"
            payload["mime"] = "text/plain"
        }

        saving = true
        model.store.perform(order: order, action: action, payload: payload) {
            result in
            saving = false
            switch result {
            case .success:
                model.result(result)
                dismiss()
            case .failure(let failure):
                error = failure.localizedDescription
            }
        }
    }
}

extension WBFoundation {
    static func nowForDesktop(_ date: Date) -> String {
        ISO8601DateFormatter.jobsMake {
            _ in
        }.string(from: date)
    }
}
