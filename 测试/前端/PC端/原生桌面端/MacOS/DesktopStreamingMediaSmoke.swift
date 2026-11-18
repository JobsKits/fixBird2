//
//  DesktopStreamingMediaSmoke.swift
//  RepairDesktopTests
//
//  Created by Jobs on 2026年11月18日，星期三.
//

import Foundation

@main struct DesktopStreamingMediaSmoke {

    @MainActor static func main() async throws {
        guard CommandLine.arguments.count == 3,
              let endpoint = URLComponents(string: CommandLine.arguments[1]),
              endpoint.host == "127.0.0.1", let port = endpoint.port, port != 8098 else {
            fatalError("Use isolated loopback backend and a synthetic MP4 fixture")
        }
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("repair-stream-smoke-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }
        let png = Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+j6XcAAAAASUVORK5CYII=")!
        var urls: [URL] = []
        for index in 0..<8 {
            let url = directory.appendingPathComponent("设备图片\(index).png")
            try png.write(to: url)
            if index < 2 {
                try pad(url, count: 9 * 1024 * 1024, video: false)
            }
            urls.append(url)
        }
        let video = directory.appendingPathComponent("设备大视频.mp4")
        try FileManager.default.copyItem(at: URL(fileURLWithPath: CommandLine.arguments[2]), to: video)
        try pad(video, count: 17 * 1024 * 1024, video: true)
        urls.append(video)
        let draft = DesktopOrderUploadDraft()
        draft.add(urls: urls)
        while draft.importing {
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        precondition(draft.error.isEmpty && draft.media.count == 9)
        precondition(draft.media.reduce(Int64(0)) { $0 + $1.size } > 32 * 1024 * 1024)
        precondition(draft.media.first!.size > 8 * 1024 * 1024 && draft.media.last!.size > 16 * 1024 * 1024)
        let store = WBStore(transport: WBJobsTransport(), environment: WBEnvironment(endpoint: CommandLine.arguments[1], timeout: 10, editable: true), allowsSyntheticDemo: false)
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            store.login(username: "admin", password: "1234") { continuation.resume(with: $0) }
        }
        let first: WBOrder = try await withCheckedThrowingContinuation { continuation in
            store.loadOrder(id: store.orders.first!.id) { continuation.resume(with: $0) }
        }
        let input = WBOrderInput().byCustomer(first.customer).byCustomerId(first.customerId).byCompanyId(first.companyId).byDevice("原生9件流式原件夹具").byDescription("无应用大小或数量上限专项")
        let prepared = try await draft.prepare(input: input, store: store, allowLocalDemo: false) { true }
        precondition(prepared.files.count == 9)
        let encoded = try WBFoundation.data(prepared.payload)
        precondition(encoded.count < 8192 && !String(decoding: encoded, as: UTF8.self).contains("dataBase64"))
        let original = draft.media[0]
        let repeated = try await DesktopFileTransfer().upload(request: store.orderUploadRequest(key: original.id), media: original) { _, _ in }
        precondition(repeated["id"] as? String == original.uploadID)
        let order: WBOrder = try await withCheckedThrowingContinuation { continuation in
            store.createOrder(input: prepared) { continuation.resume(with: $0) }
        }
        try WBInitialMedia.confirm(order: order, submitted: prepared.files)
        precondition(order.evidence.count == 9)
        var wrong = order
        wrong.raw["evidence"] = .array(order.evidence.map { record in
            var raw = record.raw
            raw["sha256"] = .string(String(repeating: "0", count: 64))
            return .object(raw)
        })
        do {
            try WBInitialMedia.confirm(order: wrong, submitted: prepared.files)
            fatalError("Corrupted SHA receipt must be rejected")
        } catch {}
        let largeVideo = order.evidence.first { $0.string("mime") == "video/mp4" }!
        let downloaded = try await DesktopFileTransfer().download(request: store.evidenceRequest(orderID: order.id, fileID: largeVideo.id)) { _, _ in }
        try DesktopDeviceMedia.verify(url: downloaded.url, size: largeVideo.int("size"), sha256: largeVideo.string("sha256"))
        do {
            _ = try await call(store, path: "/order-uploads/" + original.uploadID!, method: "DELETE")
            fatalError("Bound upload cannot be deleted")
        } catch let error as WBError {
            precondition(error.isBusinessRejection)
        }
        let orphanRequest = try store.orderUploadRequest(key: UUID().uuidString)
        let orphan = try await DesktopFileTransfer().upload(request: orphanRequest, media: draft.media[2]) { _, _ in }
        _ = try await call(store, path: "/order-uploads/" + (orphan["id"] as! String), method: "DELETE")
        let cancelled = Task {
            try await DesktopFileTransfer().upload(request: store.orderUploadRequest(key: UUID().uuidString), media: original) { _, _ in }
        }
        cancelled.cancel()
        do {
            _ = try await cancelled.value
            fatalError("Cancelled native transfer cannot succeed")
        } catch is CancellationError {}
        var demoInput = input
        demoInput.localMedia = draft.media.map { DesktopDemoMediaRegistry.retain($0) }
        precondition(demoInput.payload["localMedia"] == nil && demoInput.payload["files"] == nil)
        let demoOrder = try WBDemoState(username: "admin").create(demoInput)
        precondition(demoOrder.evidence.count == 9)
        for evidence in demoOrder.evidence {
            precondition(DesktopDemoMediaRegistry.url(evidence.string("localFileReference")) != nil)
        }
        let localReference = demoOrder.evidence[0].string("localFileReference")
        DesktopDemoMediaRegistry.clear()
        precondition(DesktopDemoMediaRegistry.url(localReference) == nil)
        draft.finish()
        store.logout()
        do {
            _ = try store.orderUploadRequest(key: "must-deny")
            fatalError("Logged-out upload must fail")
        } catch {}
        print("PASS Mac native stream: 9 originals/35+MiB, >8MiB images, >16MiB video, small metadata JSON, upload idempotency, atomic create+SHA, disk download+SHA, bound delete denial, unbound cancel/delete, task cancellation, demo original references and session cleanup")
    }

    static func pad(_ url: URL, count: Int, video: Bool) throws {
        let handle = try FileHandle(forWritingTo: url)
        defer {
            try? handle.close()
        }
        try handle.seekToEnd()
        if video {
            let size = UInt32(count + 8)
            try handle.write(contentsOf: Data([UInt8((size >> 24) & 255), UInt8((size >> 16) & 255), UInt8((size >> 8) & 255), UInt8(size & 255), 102, 114, 101, 101]))
        }
        let chunk = Data(repeating: 0, count: 1024 * 1024)
        var remaining = count
        while remaining > 0 {
            let amount = min(remaining, chunk.count)
            try handle.write(contentsOf: chunk.prefix(amount))
            remaining -= amount
        }
    }

    @MainActor static func call(_ store: WBStore, path: String, method: String) async throws -> WBJSON {
        return try await withCheckedThrowingContinuation { continuation in
            store.send(path: path, method: method) { continuation.resume(with: $0) }
        }
    }
}
