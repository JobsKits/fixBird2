//
//  DesktopDirectoryEditor.swift
//  RepairDesktop
//
//  Created by Jobs on 2026年11月18日，星期三.
//

import SwiftUI

enum DesktopDirectoryOperation: String, Identifiable {

    case customer
    case company
    case account

    var id: String {
        return rawValue
    }

    var title: String {
        switch self {
        case .customer:
            return "新建客户"
        case .company:
            return "新建企业"
        case .account:
            return "新建客户账号"
        }
    }
}

struct DesktopDirectoryEditor: View {

    @EnvironmentObject private var model: DesktopModel
    @Environment(\.dismiss) private var dismiss
    let operation: DesktopDirectoryOperation
    let profile: DesktopCustomerProfile?
    var preferredCompany = ""
    @ObservedObject var directory: DesktopCustomerDirectory
    @State private var name = ""
    @State private var companyName = ""
    @State private var companyID = ""
    @State private var accountName = ""
    @State private var username = ""
    @State private var password = ""
    @State private var confirmation = ""
    @State private var passwordVisible = false
    @State private var confirmationVisible = false
    @State private var error = ""
    @State private var saving = false
    @State private var passwordRejected = false
    @State private var confirmationRejected = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(model.text(operation.title)).font(.title2.bold())
            if let profile, operation != .customer {
                Text(profile.name).font(.callout).foregroundStyle(.secondary)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 13) {
                    if operation != .account {
                        field(operation == .customer ? "客户名称" : "企业名称", value: $name)
                    }
                    if operation == .customer {
                        field("首家企业名称", value: $companyName)
                    }
                    if operation == .account {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(model.text("所属企业")).foregroundStyle(.secondary)
                            Picker(model.text("所属企业"), selection: $companyID) {
                                Text(model.text("请选择企业")).tag("")
                                ForEach(profile?.companies ?? []) { company in
                                    Text(company.name + " · " + company.id).tag(company.id)
                                }
                            }
                            .labelsHidden()
                        }
                    }
                    if operation != .company {
                        field("客户账号", value: $username)
                        field("账号显示名称", value: $accountName)
                        Text(model.text("密码")).font(.callout).foregroundStyle(.secondary)
                        DesktopPasswordField(title: model.text("密码"), showTitle: model.text("显示密码"), hideTitle: model.text("隐藏密码"), text: $password, visible: $passwordVisible, rejectionTitle: model.text("密码不能包含表情符号"), onRejectionChange: { passwordRejected = $0 })
                        Text(model.text("确认密码")).font(.callout).foregroundStyle(.secondary)
                        DesktopPasswordField(title: model.text("确认密码"), showTitle: model.text("显示密码"), hideTitle: model.text("隐藏密码"), text: $confirmation, visible: $confirmationVisible, rejectionTitle: model.text("密码不能包含表情符号"), onRejectionChange: { confirmationRejected = $0 })
                        Text(model.text("至少8字符，两次输入一致；账号仅有客户权限")).font(.caption).foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 3)
            }
            .disabled(directory.pendingCreation != nil)
            if !error.isEmpty {
                Text(model.text(error)).font(.callout).foregroundStyle(.red).fixedSize(horizontal: false, vertical: true)
            }
            HStack {
                if saving {
                    ProgressView().controlSize(.small)
                }
                Spacer()
                Button(model.text("取消")) {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                Button(model.text(operation.title), action: submit)
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .disabled(saving)
        .interactiveDismissDisabled(saving)
        .padding(24)
        .frame(width: 500, height: operation == .company ? 290 : 570)
        .onAppear {
            companyID = profile?.companies.contains(where: { $0.id == preferredCompany }) == true ? preferredCompany : profile?.companies.first?.id ?? ""
            passwordVisible = model.store.isDemo
            confirmationVisible = model.store.isDemo
            if let pending = directory.pendingCreation, pending["operation"] as? String == operation.rawValue {
                name = pending["name"] as? String ?? ""
                companyName = pending["companyName"] as? String ?? ""
                companyID = pending["companyId"] as? String ?? ""
                accountName = pending["accountName"] as? String ?? ""
                username = pending["username"] as? String ?? ""
                password = pending["password"] as? String ?? ""
                confirmation = pending["confirmPassword"] as? String ?? ""
            }
        }
        .onDisappear {
            password = ""
            confirmation = ""
        }
    }

    private func field(_ title: String,
                       value: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(model.text(title)).font(.callout).foregroundStyle(.secondary)
            TextField(model.text(title), text: value).textFieldStyle(.roundedBorder)
        }
    }

    private func submit() {
        guard !passwordRejected, !confirmationRejected,
              !DesktopPasswordPolicy.containsEmoji(password),
              !DesktopPasswordPolicy.containsEmoji(confirmation) else {
            error = "密码不能包含表情符号"
            return
        }
        if operation != .account && name.trimmingCharacters(in: .whitespaces).isEmpty {
            error = "请填写必填字段"
            return
        }
        if operation != .company && (username.count < 3 || password.count < 8 || password != confirmation || operation == .customer && companyName.trimmingCharacters(in: .whitespaces).isEmpty || operation == .account && companyID.isEmpty) {
            error = "请选本客户企业，填写有效用户名和至少8字符的一致密码"
            return
        }
        let payload: [String: Any] = [
            "operation": operation.rawValue,
            "customerId": operation == .customer ? "" : profile?.id ?? "",
            "name": name,
            "companyName": companyName,
            "companyId": companyID,
            "username": username,
            "accountName": accountName,
            "password": password,
            "confirmPassword": confirmation,
        ]
        saving = true
        directory.create(payload, store: model.store) { result in
            saving = false
            switch result {
            case .success:
                dismiss()
            case .failure(let failure):
                error = failure.localizedDescription
            }
        }
    }
}
