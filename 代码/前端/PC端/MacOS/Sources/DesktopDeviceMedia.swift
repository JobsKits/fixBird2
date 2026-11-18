//
//  DesktopDeviceMedia.swift
//  RepairDesktop
//
//  Created by Jobs on 2026年11月18日，星期三.
//

import AppKit
import CryptoKit
import ImageIO
import UniformTypeIdentifiers

final class DesktopMediaFile: @unchecked Sendable {

    let url: URL

    init(url: URL) {
        self.url = url
    }

    deinit {
        try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
    }
}

struct DesktopDeviceMedia: Identifiable, Sendable {

    let id: String
    let file: DesktopMediaFile
    let name: String
    let mime: String
    let size: Int64
    let sha256: String
    var uploadID: String?

    var url: URL {
        return file.url
    }

    var metadata: [String: Any] {
        return ["name": name, "mime": mime, "size": size, "sha256": sha256]
    }

    @MainActor var thumbnail: NSImage? {
        guard mime.hasPrefix("image/"), let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceThumbnailMaxPixelSize: 96,
                kCGImageSourceCreateThumbnailWithTransform: true,
              ] as CFDictionary) else {
            return nil
        }
        return NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
    }

    @MainActor static func selectURLs() -> [URL] {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = [.image, .movie]
        guard panel.runModal() == .OK else {
            return []
        }
        return panel.urls
    }

    // Own a stable copy: Finder security scope and provider temporary URLs can expire after import.
    static func importing(_ source: URL) throws -> DesktopDeviceMedia {
        let scoped = source.startAccessingSecurityScopedResource()
        defer {
            if scoped {
                source.stopAccessingSecurityScopedResource()
            }
        }
        let mime = ["png": "image/png", "jpg": "image/jpeg", "jpeg": "image/jpeg", "gif": "image/gif", "webp": "image/webp", "mp4": "video/mp4", "mov": "video/quicktime", "webm": "video/webm"][source.pathExtension.lowercased()] ?? ""
        let properties = try source.resourceValues(forKeys: [.isRegularFileKey])
        guard properties.isRegularFile == true, !mime.isEmpty else {
            throw WBError.unavailable("请选择有效设备图片或视频原件")
        }
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("repair-device-" + UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let file = DesktopMediaFile(url: directory.appendingPathComponent(source.lastPathComponent))
        try FileManager.default.copyItem(at: source, to: file.url)
        let handle = try FileHandle(forReadingFrom: file.url)
        defer {
            try? handle.close()
        }
        let prefix = try handle.read(upToCount: 512) ?? Data()
        if mime.hasPrefix("image/") {
            guard let image = CGImageSourceCreateWithURL(file.url as CFURL, nil), CGImageSourceGetCount(image) > 0 else {
                throw WBError.unavailable("请选择有效设备图片或视频原件")
            }
        } else {
            let bytes = Array(prefix)
            let webm = bytes.starts(with: [0x1a, 0x45, 0xdf, 0xa3]) && String(decoding: bytes, as: UTF8.self).contains("webm")
            let movie = bytes.count >= 16 && String(decoding: bytes[4..<8], as: UTF8.self) == "ftyp"
            guard mime == "video/webm" ? webm : movie else {
                throw WBError.unavailable("请选择有效设备图片或视频原件")
            }
        }
        try handle.seek(toOffset: 0)
        var hash = SHA256()
        var size: Int64 = 0
        while let chunk = try handle.read(upToCount: 1024 * 1024), !chunk.isEmpty {
            try Task.checkCancellation()
            hash.update(data: chunk)
            size += Int64(chunk.count)
        }
        guard size > 0 else {
            throw WBError.unavailable("请选择有效设备图片或视频原件")
        }
        let digest = hash.finalize().map { String(format: "%02x", $0) }.joined()
        return DesktopDeviceMedia(id: UUID().uuidString, file: file, name: source.lastPathComponent, mime: mime, size: size, sha256: digest)
    }

    static func verify(url: URL, size: Int64, sha256: String) throws {
        let handle = try FileHandle(forReadingFrom: url)
        defer {
            try? handle.close()
        }
        var hash = SHA256()
        var count: Int64 = 0
        while let chunk = try handle.read(upToCount: 1024 * 1024), !chunk.isEmpty {
            try Task.checkCancellation()
            count += Int64(chunk.count)
            hash.update(data: chunk)
        }
        let digest = hash.finalize().map { String(format: "%02x", $0) }.joined()
        guard count == size, digest == sha256 else {
            throw WBError.invalidResponse("文件原件校验失败")
        }
    }
}

@MainActor enum DesktopDemoMediaRegistry {

    private static var files: [String: DesktopDeviceMedia] = [:]

    static func retain(_ media: DesktopDeviceMedia) -> [String: Any] {
        files[media.id] = media
        return media.metadata.merging(["localFileReference": media.id]) { _, replacement in replacement }
    }

    static func url(_ reference: String,
                    actorID: String? = nil) -> URL? {
        if let file = files[reference] {
            return file.url
        }
        guard let actorID, let item = WBDemoMediaSeed.item(reference: reference, actorID: actorID),
              let url = Bundle.main.resourceURL?.appendingPathComponent(item.resource),
              (try? DesktopDeviceMedia.verify(url: url, size: item.size, sha256: item.sha256)) != nil else {
            return nil
        }
        return url
    }

    static func thumbnail(_ reference: String,
                          actorID: String) -> NSImage? {
        guard let item = WBDemoMediaSeed.item(reference: reference, actorID: actorID),
              var url = url(reference, actorID: actorID) else {
            return nil
        }
        if item.mime.hasPrefix("video/") {
            guard let poster = WBDemoMediaSeed.poster(reference: reference, actorID: actorID),
                  let posterURL = Bundle.main.resourceURL?.appendingPathComponent(poster.resource),
                  (try? DesktopDeviceMedia.verify(url: posterURL, size: poster.size, sha256: poster.sha256)) != nil else {
                return nil
            }
            url = posterURL
        }
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceThumbnailMaxPixelSize: 320,
                kCGImageSourceCreateThumbnailWithTransform: true,
              ] as CFDictionary) else {
            return nil
        }
        return NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
    }

    static func clear() {
        files.removeAll()
    }
}
