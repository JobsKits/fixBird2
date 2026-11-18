//
//  DesktopDeviceEvidenceView.swift
//  RepairDesktop
//
//  Created by Jobs on 2026年11月18日，星期三.
//

import SwiftUI

struct DesktopDeviceEvidenceView: View {

    @EnvironmentObject private var model: DesktopModel
    let order: WBOrder
    @State private var files: [String: DesktopMediaFile] = [:]
    @State private var active = ""
    @State private var progress = 0.0
    @State private var error = ""
    @State private var work: Task<Void, Never>?
    @State private var context = ""
    @State private var generation = UUID()
    @State private var seedThumbnails: [String: NSImage] = [:]

    private var evidence: [WBRecord] {
        return order.evidence.filter { !$0.bool("deleted") && ["image", "video"].contains($0.string("kind")) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(model.text("设备图片／视频")).font(.headline)
            if evidence.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "photo.on.rectangle.angled").font(.title2).foregroundStyle(.secondary)
                    Text(model.text("暂无设备附件")).foregroundStyle(.secondary)
                    Button(model.text("重新加载")) {
                        model.open(order)
                    }
                }
                .frame(maxWidth: .infinity).padding(16)
            } else {
                if model.store.isDemo && evidence.contains(where: { $0.bool("synthetic") }) {
                    Text(model.text("合成演示设备资料")).font(.caption).foregroundStyle(.secondary)
                }
                ForEach(evidence, id: \.id) { item in
                    HStack {
                        if let thumbnail = seedThumbnails[item.id] {
                            Button {
                                open(item)
                            } label: {
                                Image(nsImage: thumbnail)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 112, height: 74)
                                    .clipped()
                                    .overlay {
                                        if item.string("kind") == "video" {
                                            Image(systemName: "play.circle.fill")
                                                .font(.system(size: 28))
                                                .foregroundStyle(.white)
                                                .shadow(color: .black.opacity(0.5), radius: 4, y: 2)
                                        }
                                    }
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(model.text(item.string("kind") == "video" ? "播放" : "预览") + " " + item.string("name"))
                            .disabled(!active.isEmpty)
                        } else {
                            Image(systemName: item.string("kind") == "video" ? "video" : "photo")
                        }
                        VStack(alignment: .leading) {
                            Text(item.string("name")).lineLimit(1)
                            Text(ByteCountFormatter.string(fromByteCount: item.int("size"), countStyle: .file)).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button(model.text(item.string("kind") == "video" ? "播放" : "预览")) {
                            open(item)
                        }
                        .disabled(!active.isEmpty)
                    }
                }
            }
            if !active.isEmpty {
                HStack {
                    Text(model.text("正在下载原件")).font(.caption)
                    ProgressView(value: progress).frame(width: 140)
                    Button(model.text("取消下载")) {
                        work?.cancel()
                    }
                }
            }
            if !error.isEmpty {
                Text(model.text(error)).foregroundStyle(.red).font(.caption)
            }
        }
        .onAppear {
            context = model.contextKey
            loadSeedThumbnails()
        }
        .onReceive(model.$revision) { _ in
            if context != model.contextKey {
                clear()
            }
        }
        .onDisappear(perform: clear)
        .onChange(of: order.id) { _ in
            clear()
            loadSeedThumbnails()
        }
        .onChange(of: order.evidence) { _ in
            clear()
            loadSeedThumbnails()
        }
    }

    private func clear() {
        generation = UUID()
        work?.cancel()
        work = nil
        active = ""
        files.removeAll()
        seedThumbnails.removeAll()
    }

    private func loadSeedThumbnails() {
        guard model.store.isDemo, let actorID = model.store.actor?.id else {
            return
        }
        for item in evidence where item.bool("synthetic") {
            seedThumbnails[item.id] = DesktopDemoMediaRegistry.thumbnail(item.string("localFileReference"), actorID: actorID)
        }
    }

    private func open(_ item: WBRecord) {
        if model.store.isDemo {
            if let url = DesktopDemoMediaRegistry.url(item.string("localFileReference"), actorID: model.store.actor?.id) {
                NSWorkspace.shared.open(url)
            } else {
                error = "暂无设备附件"
            }
            return
        }
        if let file = files[item.id] {
            NSWorkspace.shared.open(file.url)
            return
        }
        let captured = model.contextKey
        let ticket = UUID()
        generation = ticket
        context = captured
        active = item.id
        error = ""
        progress = 0
        work = Task { @MainActor in
            do {
                let request = try model.store.evidenceRequest(orderID: order.id, fileID: item.id)
                let file = try await DesktopFileTransfer().download(request: request) { written, expected in
                    Task { @MainActor in
                        guard model.contextKey == captured, generation == ticket, active == item.id else {
                            return
                        }
                        progress = expected > 0 ? Double(written) / Double(expected) : 0
                    }
                }
                let checksum = Task.detached(priority: .userInitiated) {
                    try DesktopDeviceMedia.verify(url: file.url, size: item.int("size"), sha256: item.string("sha256"))
                }
                try await withTaskCancellationHandler {
                    try await checksum.value
                } onCancel: {
                    checksum.cancel()
                }
                try Task.checkCancellation()
                guard model.contextKey == captured, generation == ticket else {
                    return
                }
                files[item.id] = file
                active = ""
                NSWorkspace.shared.open(file.url)
            } catch {
                guard model.contextKey == captured, generation == ticket else {
                    return
                }
                active = ""
                self.error = error is CancellationError ? "下载已取消" : error.localizedDescription
                if let failure = error as? WBError, failure.isUnauthorized {
                    model.store.logout()
                }
            }
        }
    }
}
