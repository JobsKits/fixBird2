//
//  DesktopLoanAttachmentsPicker.swift
//  RepairDesktop
//
//  Created by Jobs on 2026年11月18日，星期三.
//

import SwiftUI
import UniformTypeIdentifiers

struct DesktopLoanAttachmentsPicker: View {
  @EnvironmentObject private var model: DesktopModel
  @Binding var attachments: [DesktopLoanAttachment]
  @State private var choosing = false
  @State private var error = ""
  private var t: (String) -> String { model.text }

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack {
        Text(t("图片凭据")).font(.headline)
        Spacer()
        Button {
          choosing = true
        } label: {
          Label(t("选择图片"), systemImage: "photo.badge.plus")
        }
      }
      Text(t("每次至少选择一张图片，支持 PNG、JPEG、GIF。"))
        .font(.caption).foregroundStyle(.secondary)
      if !attachments.isEmpty {
        ScrollView(.horizontal) {
          HStack(alignment: .top, spacing: 12) {
            ForEach(attachments) { attachment in
              VStack(alignment: .leading, spacing: 5) {
                if let image = NSImage.makeLoanProof(attachment.data) {
                  Image(nsImage: image).resizable().scaledToFit()
                    .frame(width: 120, height: 78)
                }
                HStack {
                  Text(attachment.name).font(.caption).lineLimit(1)
                  Spacer(minLength: 0)
                  Button {
                    attachments.removeAll { $0.id == attachment.id }
                  } label: {
                    Image(systemName: "xmark.circle.fill")
                  }.buttonStyle(.plain).accessibilityLabel(t("删除"))
                }
              }.frame(width: 140)
            }
          }
        }
      }
      if !error.isEmpty {
        Text(t(error)).font(.caption).foregroundStyle(.red)
      }
    }
    .fileImporter(
      isPresented: $choosing, allowedContentTypes: [.png, .jpeg, .gif],
      allowsMultipleSelection: true
    ) { result in
      do {
        let images = try result.get().map { try DesktopLoanAttachment.load($0) }
        let next = attachments + images
        guard next.count <= 8, next.reduce(0, { $0 + $1.data.count }) <= 32 * 1024 * 1024 else {
          throw WBError.unavailable("图片最多8张，单张8MiB，总计32MiB")
        }
        attachments = next
        error = ""
      } catch {
        self.error = error.localizedDescription
      }
    }
  }
}
