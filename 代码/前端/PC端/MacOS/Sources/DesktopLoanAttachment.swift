//
//  DesktopLoanAttachment.swift
//  RepairDesktop
//
//  Created by Jobs on 2026年11月18日，星期三.
//

import AppKit
import SwiftUI

struct DesktopLoanAttachment: Identifiable {
  let id = UUID()
  let name: String
  let mime: String
  let data: Data

  var payload: [String: Any] {
    ["name": name, "mime": mime, "dataBase64": data.base64EncodedString()]
  }

  static func load(_ url: URL) throws -> DesktopLoanAttachment {
    let scoped = url.startAccessingSecurityScopedResource()
    defer {
      if scoped { url.stopAccessingSecurityScopedResource() }
    }
    let mime: String
    switch url.pathExtension.lowercased() {
    case "png": mime = "image/png"
    case "jpg", "jpeg": mime = "image/jpeg"
    case "gif": mime = "image/gif"
    default: throw WBError.unavailable("仅支持 PNG、JPEG、GIF 图片")
    }
    let metadata = try url.resourceValues(forKeys: [.fileSizeKey])
    guard let size = metadata.fileSize, size > 0, size <= 8 * 1024 * 1024 else {
      throw WBError.unavailable("图片最多8张，单张8MiB，总计32MiB")
    }
    let data = try Data(contentsOf: url)
    guard data.count == size, NSImage.makeLoanProof(data) != nil else {
      throw WBError.unavailable("仅支持 PNG、JPEG、GIF 图片")
    }
    return DesktopLoanAttachment(name: url.lastPathComponent, mime: mime, data: data)
  }

  static func sample(_ resource: String) -> DesktopLoanAttachment? {
    guard let url = Bundle.main.url(forResource: resource, withExtension: "png"),
      let data = try? Data(contentsOf: url)
    else { return nil }
    return DesktopLoanAttachment(name: resource + ".png", mime: "image/png", data: data)
  }
}

extension NSImage {
  static func makeLoanProof(_ data: Data) -> NSImage? {
    NSImage(data: data)
  }
}
