//
//  WBFileEvidenceVC.swift
//  RepairWorkbench
//
//  Created by Jobs on 2026年10月15日，星期四.
//

import UIKit
import UniformTypeIdentifiers

import JobsByUIKit
import JobsInheritance

final class WBFileEvidenceVC: BaseVC, UIDocumentPickerDelegate {
    private let order: WBOrder
    private let openingActor: WBActor?
    private let endpoint: String
    private let demo: Bool
    private var bytes: Data?
    private var fileName = ""
    private var mime = ""
    private var submitting = false
    private var importer: UIDocumentPickerViewController?
    private lazy var page = WBPageView()
    private lazy var source = WBUI.label(WBStore.shared.sourceLabel, size: 13, secondary: true)
    private lazy var titleField = WBFormField("name", "资料名称")
    private lazy var descriptionField = WBFormField("text", "事实说明（文字资料必填）", kind: .multiline)
    private lazy var fileInformation = WBUI.label("尚未选择文件；仅填写事实说明可归档为文字资料。", size: 13, secondary: true)
    private lazy var visibility = WBFormField("public", "资料可见范围", kind: .choice([
        ("false", "仅按内部业务授权查看"),
        ("true", "允许当前工单客户查看")
    ]), value: "false")
    private lazy var customerNotice = WBUI.label("客户上传的资料按当前工单授权共享。", size: 13, secondary: true)
    private lazy var chooseButton = WBUI.button("选择本地原件（PDF、图片、音视频）") { [weak self] in
        self?.chooseFile()
    }
    private lazy var discardButton = WBUI.button("取消文件选择，改为文字资料") { [weak self] in
        self?.discardFile()
    }
    private lazy var submitButton = WBUI.button("提交并归档资料", primary: true) { [weak self] in
        self?.submit()
    }

    init(order: WBOrder) {
        self.order = order
        openingActor = WBStore.shared.actor
        endpoint = WBStore.shared.endpoint
        demo = WBStore.shared.isDemo
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        return nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        jobsSetupGKNav(title: "归档业务资料")
        page.mount(in: self)
        page.replace([source, titleField, descriptionField, chooseButton, fileInformation, discardButton,
                      openingActor == nil || WBStore.shared.actor?.role == "customer" ? customerNotice : visibility,
                      submitButton, page.message])
    }

    private var sameContext: Bool {
        guard let openingActor, let currentActor = WBStore.shared.actor else {
            return false
        }
        return openingActor.matches(currentActor) && endpoint == WBStore.shared.endpoint && demo == WBStore.shared.isDemo
    }

    private func chooseFile() {
        guard sameContext, !submitting else {
            page.status("身份或数据来源已改变，请返回详情重新加载。")
            return
        }
        importer = UIDocumentPickerViewController.make(delegate: self)
        if let importer {
            present(importer, animated: true)
        }
    }

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        defer {
            importer = nil
        }
        guard sameContext, let url = urls.first, url.isFileURL else {
            page.status("当前资料来源已变化，请重新打开办理页面。")
            return
        }
        let scope = url.startAccessingSecurityScopedResource()
        defer {
            if scope {
                url.stopAccessingSecurityScopedResource()
            }
        }
        do {
            let values = try url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
            guard values.isRegularFile == true, let size = values.fileSize, size > 0, size <= 8 * 1024 * 1024 else {
                throw WBUIError("请选择不超过 8 MiB 的有效文件原件。")
            }
            let contentType = UTType(filenameExtension: url.pathExtension.lowercased())
            let selectedMIME = contentType?.preferredMIMEType ?? ""
            let normalized = ["audio/x-wav", "audio/vnd.wave", "audio/wave"].contains(selectedMIME) ? "audio/wav" : selectedMIME
            guard ["application/pdf", "image/png", "image/jpeg", "video/mp4", "audio/mpeg", "audio/wav"].contains(normalized) else {
                throw WBUIError("请选择 PDF、PNG、JPEG、MP4、MP3 或 WAV 原件。")
            }
            let data = try Data(contentsOf: url, options: .mappedIfSafe)
            guard !data.isEmpty, data.count <= 8 * 1024 * 1024 else {
                throw WBUIError("文件大小已变化，请重新选择不超过 8 MiB 的原件。")
            }
            bytes = data
            mime = normalized
            fileName = url.lastPathComponent
            fileInformation.byText("已选：\(fileName) · \(data.count) 字节\n提交后由服务端校验原件内容与权限；尚未归档。")
        } catch {
            page.status(error.localizedDescription)
        }
    }

    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        importer = nil
    }

    private func discardFile() {
        bytes = nil
        mime = ""
        fileName = ""
        fileInformation.byText("已取消文件选择，可填写事实说明作为文字资料。")
    }

    private func submit() {
        guard !submitting, sameContext, order.can("evidence"), !order.isSummary else {
            page.status("当前工单或身份不可办理，请返回详情重新加载。")
            return
        }
        let name = titleField.string.isEmpty ? fileName : titleField.string
        guard !name.isEmpty, name.count <= 200 else {
            page.status("请填写不超过 200 字的资料名称。")
            return
        }
        guard bytes != nil || !descriptionField.string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            page.status("请填写事实说明或选择文件原件。")
            return
        }
        let kind = bytes == nil ? "text" : mime.hasPrefix("image/") ? "image" : mime.hasPrefix("audio/") ? "audio" : mime.hasPrefix("video/") ? "video" : "document"
        let payload: [String: Any] = ["name": name, "kind": kind, "text": descriptionField.string,
                                      "mime": bytes == nil ? "text/plain" : mime,
                                      "data": bytes?.base64EncodedString() ?? "",
                                      "public": WBStore.shared.actor?.role == "customer" || visibility.string == "true"]
        submitting = true
        page.status("正在提交，请等待归档结果。")
        WBStore.shared.perform(order: order, action: "evidence", payload: payload) { [weak self] result in
            guard let self else {
                return
            }
            self.submitting = false
            switch result {
            /// 仅接纳服务端确认或明确标识的独立演示结果。
            case .success:
                self.navigationController?.popViewControllerByAnimated()
            /// 保留原件及输入，未知提交不自动重放。
            case .failure(let error):
                self.page.status(error.localizedDescription)
            }
        }
    }
}
