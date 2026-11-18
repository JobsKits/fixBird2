//
//  DesktopLoanProofTile.swift
//  RepairDesktop
//
//  Created by Jobs on 2026年11月18日，星期三.
//

import SwiftUI

struct DesktopLoanProofTile: View {
  @EnvironmentObject private var model: DesktopModel
  let loan: WBLoan
  let file: WBRecord
  @State private var image: NSImage?
  @State private var error = ""
  @State private var generation = UUID()
  @State private var expanded = false

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text(model.text(file.string("stage") == "borrow" ? "借出登记" : "归还"))
        .font(.headline)
      if let image {
        Button {
          expanded = true
        } label: {
          Image(nsImage: image).resizable().scaledToFit()
            .frame(maxWidth: .infinity).frame(height: 150)
        }.buttonStyle(.plain).accessibilityLabel(model.text("预览") + " · " + file.string("name"))
      } else if error.isEmpty {
        ProgressView().frame(height: 100)
      } else {
        Text(model.text(error)).font(.caption).foregroundStyle(.secondary)
        Button(model.text("重新加载"), action: load)
      }
      Text(file.string("name")).font(.caption).textSelection(.enabled)
      Text(model.text("数量") + " \(file.int("quantity"))").font(.caption)
      Text(model.timestamp(file.string("createdAt"))).font(.caption).foregroundStyle(.secondary)
    }
    .padding(14)
    .background(.quaternary.opacity(0.35))
    .clipShape(RoundedRectangle(cornerRadius: 10))
    .onAppear(perform: load)
    .onChange(of: file.id) { _ in load() }
    .onDisappear {
      generation = UUID()
      image = nil
    }
    .sheet(isPresented: $expanded) {
      VStack(spacing: 12) {
        HStack {
          Text(file.string("name")).font(.headline)
          Spacer()
          Button(model.text("关闭")) { expanded = false }.keyboardShortcut(.cancelAction)
        }
        if let image { Image(nsImage: image).resizable().scaledToFit() }
      }.padding(20).frame(width: 850, height: 600)
    }
  }

  private func load() {
    let revision = UUID()
    generation = revision
    error = ""
    image = nil
    model.loadLoanProof(loan: loan, file: file) { result in
      guard generation == revision else { return }
      switch result {
      case .success(let data):
        image = NSImage.makeLoanProof(data)
        if image == nil { error = "借还图片凭据响应无效" }
      case .failure(let failure):
        error = failure.localizedDescription
      }
    }
  }
}
