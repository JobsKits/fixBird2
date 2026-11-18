//
//  DesktopOrderUploadDraft.swift
//  RepairDesktop
//
//  Created by Jobs on 2026年11月18日，星期三.
//

import AppKit
import Combine
import UniformTypeIdentifiers

@MainActor final class DesktopOrderUploadDraft: ObservableObject {

    @Published private(set) var media: [DesktopDeviceMedia] = []
    @Published private(set) var importing = false
    @Published var progress = 0.0
    @Published var error = ""
    private var revision = 0
    private var imports: [Task<Void, Never>] = []
    private var importCount = 0
    private var cleanupRequests: [String: WBRequest] = [:]
    private let cleanupTransport = WBJobsTransport()

    func add(urls: [URL]) {
        guard !urls.isEmpty else {
            return
        }
        let captured = revision
        importCount += 1
        importing = true
        let work = Task { [weak self] in
            for url in urls {
                do {
                    let worker = Task.detached(priority: .userInitiated) {
                        try DesktopDeviceMedia.importing(url)
                    }
                    let item = try await withTaskCancellationHandler {
                        try await worker.value
                    } onCancel: {
                        worker.cancel()
                    }
                    guard let self, self.revision == captured, !Task.isCancelled else {
                        return
                    }
                    self.append(item)
                } catch {
                    guard let self, self.revision == captured, !Task.isCancelled else {
                        return
                    }
                    self.error = error.localizedDescription
                }
            }
            guard let self, self.revision == captured else {
                return
            }
            self.importCount -= 1
            self.importing = self.importCount > 0
        }
        imports.append(work)
    }

    func drop(_ providers: [NSItemProvider]) -> Bool {
        let candidates = providers.filter { $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) }
        guard !candidates.isEmpty else {
            return false
        }
        let captured = revision
        for provider in candidates {
            importCount += 1
            importing = true
            _ = provider.loadObject(ofClass: NSURL.self) { [weak self] value, error in
                let url = value as? URL
                Task { @MainActor in
                    guard let self, self.revision == captured else {
                        return
                    }
                    if let url {
                        self.add(urls: [url])
                    } else {
                        self.error = error?.localizedDescription ?? "请选择有效设备图片或视频原件"
                    }
                    self.importCount -= 1
                    self.importing = self.importCount > 0
                }
            }
        }
        return true
    }

    private func append(_ item: DesktopDeviceMedia) {
        if !media.contains(where: { $0.name == item.name && $0.size == item.size && $0.sha256 == item.sha256 }) {
            media.append(item)
        }
    }

    func remove(_ id: String) {
        if let request = cleanupRequests.removeValue(forKey: id) {
            cleanupTransport.send(request) { _ in }
        }
        media.removeAll { $0.id == id }
    }

    func prepare(input: WBOrderInput, store: WBStore, allowLocalDemo: Bool,
                 isCurrent: @escaping @MainActor () -> Bool) async throws -> WBOrderInput {
        var input = input
        if store.isDemo {
            guard allowLocalDemo else {
                throw WBError.unavailable("请先登录")
            }
            input.localMedia = media.map { DesktopDemoMediaRegistry.retain($0) }
            input.files = []
            return input
        }
        var files: [[String: Any]] = []
        let captured = revision
        for index in media.indices {
            try Task.checkCancellation()
            guard isCurrent(), revision == captured else {
                throw WBError.stale
            }
            let item = media[index]
            var uploadID = item.uploadID
            if uploadID == nil {
                let request = try store.orderUploadRequest(key: item.id)
                let transfer = DesktopFileTransfer()
                let receipt = try await transfer.upload(request: request, media: item) { [weak self] sent, expected in
                    Task { @MainActor in
                        guard let self, self.revision == captured, isCurrent() else {
                            return
                        }
                        self.progress = expected > 0 ? Double(sent) / Double(expected) : 0
                    }
                }
                guard let received = receipt["id"] as? String else {
                    throw WBError.invalidResponse("文件原件校验失败")
                }
                let cleanup = WBRequest(endpoint: request.endpoint, path: "/order-uploads/" + received,
                                        method: "DELETE", headers: request.headers, body: nil, timeout: request.timeout)
                guard isCurrent(), revision == captured, !Task.isCancelled else {
                    cleanupTransport.send(cleanup) { _ in }
                    throw WBError.stale
                }
                uploadID = received
                media[index].uploadID = received
                cleanupRequests[item.id] = cleanup
            }
            var reference = item.metadata
            reference["uploadId"] = uploadID
            files.append(reference)
        }
        input.files = files
        return input
    }

    func finish() {
        // Successful creation binds uploads atomically; only release the local draft copies.
        cleanupRequests.removeAll()
        cancel()
    }

    func cancel() {
        revision += 1
        imports.forEach { $0.cancel() }
        imports.removeAll()
        importCount = 0
        importing = false
        cleanupRequests.values.forEach { request in
            cleanupTransport.send(request) { _ in }
        }
        cleanupRequests.removeAll()
        media.removeAll()
    }
}
