//
//  DesktopLoanForm.swift
//  RepairDesktop
//
//  Created by Jobs on 2026年11月18日，星期三.
//

import SwiftUI

struct DesktopLoanForm: View {
  @EnvironmentObject private var model: DesktopModel
  @Environment(\.dismiss) private var dismiss
  @State private var order = ""
  @State private var part = ""
  @State private var quantity = 1
  @State private var borrower = ""
  @State private var due = Date().addingTimeInterval(7 * 24 * 60 * 60)
  @State private var note = ""
  @State private var error = ""
  @State private var saving = false
  @State private var attachments: [DesktopLoanAttachment] = []
  @State private var context = ""
  var body: some View {
    VStack(alignment: .leading, spacing: 18) {
      Text(model.text("借出登记")).font(.title2)
      Form {
        Picker(model.text("工单"), selection: $order) {
          Text(model.text("请选择")).tag("")
          ForEach(model.store.orders, id: \.id) {
            Text($0.number).tag($0.id)
          }
        }

        Picker(model.text("配件"), selection: $part) {
          Text(model.text("请选择")).tag("")
          ForEach(model.store.parts, id: \.id) {
            Text($0.name).tag($0.id)
          }
        }

        Stepper(model.text("数量") + " \(quantity)", value: $quantity, in: 1...10000)
        TextField(model.text("借用人账号"), text: $borrower)
        DatePicker(model.text("归还期限"), selection: $due)
        TextField(model.text("备注"), text: $note)
      }.frame(height: 220)
      DesktopLoanAttachmentsPicker(attachments: $attachments).environmentObject(model)
      if !error.isEmpty {
        Text(model.text(error)).font(.callout).foregroundStyle(.red)
      }
      HStack {
        Button(model.text("取消")) {
          dismiss()
        }.disabled(saving)

        Spacer()
        Button(model.text("确认提交")) {
          guard context == model.contextKey else {
            dismiss()
            return
          }
          saving = true
          model.store.createLoan(payload: [
            "orderId": order, "partId": part, "quantity": quantity, "borrowerId": borrower,
            "dueAt": WBFoundation.nowForDesktop(due), "note": note,
            "attachments": attachments.map(\.payload),
          ]) {
            result in
            saving = false
            switch result {
            case .success:
              dismiss()
            case .failure(let failure):
              error = failure.localizedDescription
            }
          }
        }.buttonStyle(.borderedProminent).disabled(
          saving || part.isEmpty || borrower.isEmpty || attachments.isEmpty)
      }
    }.interactiveDismissDisabled(saving).padding(24).frame(width: 600)
      .fixedSize(horizontal: false, vertical: true)
      .onAppear {
        context = model.contextKey
        if model.store.isDemo {
          order = model.store.orders.first?.id ?? ""
          part = model.store.parts.first?.id ?? ""
          borrower = "ios-demo-engineer"
          note = model.text("独立合成演示")
          if let sample = DesktopLoanAttachment.sample("LoanBorrow") {
            attachments = [sample]
          }
        }
      }
      .onChange(of: model.contextKey) { _ in dismiss() }
  }
}
