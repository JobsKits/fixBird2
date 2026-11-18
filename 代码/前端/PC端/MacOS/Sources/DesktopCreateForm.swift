//
//  DesktopCreateForm.swift
//  RepairDesktop
//
//  Created by Jobs on 2026年11月18日，星期三.
//

import Combine
import SwiftUI
import UniformTypeIdentifiers

struct DesktopCreateForm: View {

    @EnvironmentObject private var model: DesktopModel
    @Environment(\.dismiss) private var dismiss
    @StateObject private var directory = DesktopCustomerDirectory()
    @State private var input = WBOrderInput()
    @State private var selectedCustomer = ""
    @State private var previousCustomer = ""
    @State private var editor: DesktopDirectoryOperation?
    @StateObject private var uploads = DesktopOrderUploadDraft()
    @State private var submission: Task<Void, Never>?
    @State private var frozenInput: WBOrderInput?
    @State private var uploading = false
    @State private var dropTargeted = false
    @State private var error = ""
    @State private var saving = false
    @State private var actorAtOpen: WBActor?
    @State private var endpointAtOpen = ""
    @State private var demoAtOpen = false

    var profile: DesktopCustomerProfile? {
        return directory.profiles.first { $0.id == selectedCustomer }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(model.text("新建工单")).font(.title2)
            Divider()
            Group {
                if let pending = directory.pendingCreation, let operation = pending["operation"] as? String {
                    HStack {
                        caption("提交结果未知；输入及原请求意图保留，请核对后重试")
                        Spacer()
                        Button(model.text("重试原请求")) {
                            editor = DesktopDirectoryOperation(rawValue: operation)
                        }
                    }
                }
                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        caption("客户")
                        Picker(model.text("客户"), selection: $selectedCustomer) {
                            Text(model.text("请选择客户")).tag("")
                            ForEach(directory.profiles) { customer in
                                Text(customer.name).tag(customer.id)
                            }
                            if directory.canManage {
                                Divider()
                                Text(model.text("新建客户")).tag("__new__")
                            }
                        }
                        .labelsHidden()
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    VStack(alignment: .leading, spacing: 6) {
                        caption("类型")
                        Picker(model.text("类型"), selection: $input.type) {
                            Text(model.text("寄修")).tag("mail")
                            Text(model.text("上门")).tag("onsite")
                            Text(model.text("销售")).tag("sale")
                        }
                        .labelsHidden()
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        caption("客户账号")
                        Picker(model.text("客户账号"), selection: $input.customerId) {
                            Text(model.text("请选择客户账号")).tag("")
                            ForEach(profile?.accounts ?? [], id: \.id) { account in
                                Text(account.name + " · " + account.username).tag(account.id)
                            }
                            if directory.canManage && profile != nil {
                                Divider()
                                Text(model.text("新建客户账号")).tag("__new__")
                            }
                        }
                        .labelsHidden()
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    VStack(alignment: .leading, spacing: 6) {
                        caption("企业")
                        Picker(model.text("企业"), selection: $input.companyId) {
                            Text(model.text("请选择企业")).tag("")
                            ForEach(profile?.companies ?? []) { company in
                                Text(company.name + " · " + company.id).tag(company.id)
                            }
                            if directory.canManage && profile != nil {
                                Divider()
                                Text(model.text("新建企业")).tag("__new__")
                            }
                        }
                        .labelsHidden()
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                if input.customerId.isEmpty && !input.companyId.isEmpty {
                    caption("该企业尚无客户账号，请新建客户账号")
                }
                if directory.busy {
                    HStack {
                        ProgressView().controlSize(.small)
                        caption("正在加载客户档案")
                    }
                } else if !directory.error.isEmpty || directory.profiles.isEmpty {
                    HStack {
                        caption(directory.error.isEmpty ? "暂无客户档案" : directory.error)
                        Button(model.text("重新加载")) {
                            directory.load(store: model.store)
                        }
                    }
                }
                HStack(alignment: .top, spacing: 16) {
                    field("项目", text: $input.project)
                    field("设备", text: $input.device)
                }
                VStack(alignment: .leading, spacing: 6) {
                    caption("故障说明")
                    TextField(model.text("故障说明"), text: $input.description, axis: .vertical)
                        .lineLimit(2...3)
                        .textFieldStyle(.roundedBorder)
                }
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        caption("设备图片／视频")
                        Spacer()
                        Button(model.text("添加图片／视频")) {
                            uploads.add(urls: DesktopDeviceMedia.selectURLs())
                        }
                    }
                    caption("将图片或视频拖到这里")
                    if uploads.importing {
                        ProgressView().controlSize(.small)
                    }
                    if !uploads.media.isEmpty {
                        ScrollView {
                            LazyVStack(spacing: 8) {
                                ForEach(uploads.media) { item in
                                    HStack(spacing: 10) {
                                        if let image = item.thumbnail {
                                            Image(nsImage: image).resizable().scaledToFill().frame(width: 48, height: 40).clipped()
                                        } else {
                                            Image(systemName: item.mime.hasPrefix("video/") ? "video" : "photo")
                                                .accessibilityLabel(model.text(item.mime.hasPrefix("video/") ? "视频" : "图片"))
                                                .frame(width: 48, height: 40)
                                        }
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(item.name).lineLimit(1)
                                            Text(ByteCountFormatter.string(fromByteCount: item.size, countStyle: .file)).font(.caption).foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        Button(model.text("预览")) {
                                            NSWorkspace.shared.open(item.url)
                                        }
                                        Button(model.text("移除")) {
                                            uploads.remove(item.id)
                                        }
                                    }
                                }
                            }
                        }
                        .frame(height: CGFloat(min(uploads.media.count, 3)) * 48)
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, minHeight: 72)
                .background(dropTargeted ? Color.accentColor.opacity(0.12) : Color.secondary.opacity(0.05))
                .onDrop(of: [UTType.fileURL], isTargeted: $dropTargeted) { providers in
                    guard !saving, frozenInput == nil else {
                        return false
                    }
                    return uploads.drop(providers)
                }
            }
            .disabled(saving || frozenInput != nil)
            if frozenInput != nil && !saving {
                caption("提交结果未知；输入及原请求意图保留，请核对后重试")
            }
            if !error.isEmpty || !uploads.error.isEmpty {
                Text(model.text(error.isEmpty ? uploads.error : error)).font(.callout).foregroundStyle(.red).fixedSize(horizontal: false, vertical: true)
            }
            if uploading {
                HStack {
                    caption("正在上传设备附件")
                    ProgressView(value: uploads.progress).frame(width: 160)
                    Button(model.text("取消上传")) {
                        submission?.cancel()
                    }
                }
            } else if saving {
                caption("正在提交工单")
            }
            Divider()
            HStack {
                if saving {
                    ProgressView().controlSize(.small)
                }
                Spacer()
                Button(model.text("取消")) {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                .disabled(saving)
                Button(model.text("确认提交"), action: submit)
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(saving || uploads.importing || directory.busy || directory.pendingCreation != nil || input.customerId.isEmpty || input.companyId.isEmpty)
            }
        }
        .interactiveDismissDisabled(saving)
        .padding(24)
        .frame(width: 660)
        .fixedSize(horizontal: false, vertical: true)
        .task {
            actorAtOpen = model.store.actor
            endpointAtOpen = model.store.endpoint
            demoAtOpen = model.store.isDemo
            directory.load(store: model.store)
        }
        .onReceive(model.$revision.dropFirst()) { _ in
            if let original = actorAtOpen,
               model.store.actor?.matches(original) != true || model.store.endpoint != endpointAtOpen || model.store.isDemo != demoAtOpen {
                dismiss()
                submission?.cancel()
                uploads.cancel()
            }
        }
        .onReceive(directory.$revision.dropFirst()) { _ in
            reconcileSelection()
        }
        .onChange(of: selectedCustomer) { value in
            if value == "__new__" {
                selectedCustomer = previousCustomer
                editor = .customer
            } else {
                previousCustomer = value
                if directory.selection?.customer == value {
                    chooseCustomer(value, account: directory.selection?.account, company: directory.selection?.company)
                } else {
                    chooseCustomer(value)
                }
            }
        }
        .onChange(of: input.customerId) { value in
            if value == "__new__" {
                input.customerId = profile?.accounts.first(where: { $0.companyId == input.companyId })?.id ?? ""
                editor = .account
            } else if let account = profile?.accounts.first(where: { $0.id == value }) {
                input.companyId = account.companyId
            }
        }
        .onChange(of: input.companyId) { value in
            if value == "__new__" {
                input.companyId = profile?.accounts.first(where: { $0.id == input.customerId })?.companyId ?? profile?.companies.first?.id ?? ""
                editor = .company
            } else if profile?.accounts.first(where: { $0.id == input.customerId })?.companyId != value {
                input.customerId = profile?.accounts.first(where: { $0.companyId == value })?.id ?? ""
            }
        }
        .sheet(item: $editor) { operation in
            DesktopDirectoryEditor(operation: operation, profile: profile, preferredCompany: input.companyId, directory: directory)
                .environmentObject(model)
        }
        .onDisappear {
            submission?.cancel()
            uploads.cancel()
        }
    }

    private func reconcileSelection() {
        let requested = directory.selection
        let customer = requested?.customer ?? (directory.profiles.contains(where: { $0.id == selectedCustomer }) ? selectedCustomer : directory.profiles.first?.id ?? "")
        selectedCustomer = customer
        chooseCustomer(customer, account: requested?.account, company: requested?.company)
    }

    private func chooseCustomer(_ id: String,
                                account: String? = nil,
                                company: String? = nil) {
        guard let customer = directory.profiles.first(where: { $0.id == id }) else {
            input.customer = ""
            input.customerId = ""
            input.companyId = ""
            return
        }
        input.customer = customer.name
        let wantedCompany = company.flatMap { $0.isEmpty ? nil : $0 }
        let preferred = customer.accounts.first(where: { $0.id == account })
            ?? customer.accounts.first(where: { $0.id == input.customerId && (wantedCompany == nil || $0.companyId == wantedCompany) })
            ?? customer.accounts.first(where: { wantedCompany == nil || $0.companyId == wantedCompany })
        input.companyId = preferred?.companyId ?? wantedCompany ?? customer.companies.first?.id ?? ""
        input.customerId = preferred?.id ?? ""
    }

    private func submit() {
        guard !input.device.trimmingCharacters(in: .whitespaces).isEmpty,
              !input.description.trimmingCharacters(in: .whitespaces).isEmpty,
              let account = profile?.accounts.first(where: { $0.id == input.customerId }), account.companyId == input.companyId else {
            error = model.text("请填写设备和故障说明，并选择匹配的客户账号与企业")
            return
        }
        let context = model.contextKey
        let demoAllowed = model.localDemoAvailable
        saving = true
        error = ""
        uploads.error = ""
        uploading = frozenInput == nil && !uploads.media.isEmpty
        submission = Task { @MainActor in
            do {
                let prepared: WBOrderInput
                if let frozenInput {
                    prepared = frozenInput
                } else {
                    prepared = try await uploads.prepare(input: input, store: model.store, allowLocalDemo: demoAllowed) {
                        model.contextKey == context
                    }
                }
                try Task.checkCancellation()
                guard model.contextKey == context else {
                    throw WBError.stale
                }
                uploading = false
                frozenInput = prepared
                let result: Result<WBOrder, Error> = await withCheckedContinuation { continuation in
                    model.store.createOrder(input: prepared) { result in
                        continuation.resume(returning: result)
                    }
                }
                guard model.contextKey == context else {
                    return
                }
                saving = false
                switch result {
                /// Keep only the demo registry references after an acknowledged atomic creation.
                case .success:
                    frozenInput = nil
                    uploads.finish()
                    model.result(result)
                    dismiss()
                /// Unknown writes retain the exact input and the store's original idempotency key.
                case .failure(let failure):
                    if let failure = failure as? WBError,
                       failure.isBusinessRejection || failure.isUnauthorized || failure == .stale {
                        frozenInput = nil
                    }
                    error = failure.localizedDescription
                }
            } catch {
                guard model.contextKey == context else {
                    return
                }
                uploading = false
                saving = false
                self.error = error is CancellationError ? model.text("上传已取消") : error.localizedDescription
                if let failure = error as? WBError, failure.isUnauthorized {
                    model.store.logout()
                }
            }
        }
    }

    private func caption(_ value: String) -> some View {
        Text(model.text(value)).font(.callout).foregroundStyle(.secondary)
    }

    private func field(_ title: String,
                       text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            caption(title)
            TextField(model.text(title), text: text).textFieldStyle(.roundedBorder)
        }
        .frame(maxWidth: .infinity)
    }
}
