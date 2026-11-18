//
//  DesktopLoanProofForm.swift
//  RepairDesktop
//
//  Created by Jobs on 2026年11月18日，星期三.
//

import SwiftUI

struct DesktopLoanProofForm: View {
  @EnvironmentObject private var model: DesktopModel
  @Environment(\.dismiss) private var dismiss
  let loan: WBLoan
  let supplement: Bool
  @State private var stage = "borrow"
  @State private var quantity = 1
  @State private var condition = "good"
  @State private var note = ""
  @State private var attachments: [DesktopLoanAttachment] = []
  @State private var saving = false
  @State private var error = ""
  @State private var context = ""
  private var t: (String) -> String { model.text }

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text(t(supplement ? "补录图片凭据" : "归还")).font(.title2).bold()
      Text(loan.partName).foregroundStyle(.secondary)
      if supplement {
        Picker(t("类型"), selection: $stage) {
          Text(t("借出登记")).tag("borrow")
          Text(t("归还")).tag("return")
        }.pickerStyle(.segmented)
      }
      HStack {
        Stepper(t("数量") + " \(quantity)", value: $quantity, in: 1...max(1, maximum))
        if !supplement || stage == "return" {
          Picker(t("归还状态"), selection: $condition) {
            Text(t("完好归还")).tag("good")
            Text(t("隔离归还")).tag("quarantine")
          }
        }
      }
      TextField(t("备注"), text: $note).textFieldStyle(.roundedBorder)
      DesktopLoanAttachmentsPicker(attachments: $attachments).environmentObject(model)
      if !error.isEmpty { Text(t(error)).font(.callout).foregroundStyle(.red) }
      Divider()
      HStack {
        if saving { ProgressView().controlSize(.small) }
        Spacer()
        Button(t("取消")) { dismiss() }.keyboardShortcut(.cancelAction).disabled(saving)
        Button(t("确认提交"), action: submit).buttonStyle(.borderedProminent)
          .disabled(saving || attachments.isEmpty || maximum < 1 || quantity > maximum)
      }
    }
    .padding(24).frame(width: 600).fixedSize(horizontal: false, vertical: true)
    .interactiveDismissDisabled(saving)
    .onAppear {
      context = model.contextKey
      quantity = supplement ? 1 : loan.outstanding
      if model.store.isDemo,
        let sample = DesktopLoanAttachment.sample(
          supplement && stage == "borrow" ? "LoanBorrow" : "LoanReturn")
      {
        attachments = [sample]
      }
    }
    .onChange(of: stage) { _ in quantity = min(quantity, max(1, maximum)) }
    .onChange(of: condition) { _ in quantity = min(quantity, max(1, maximum)) }
    .onChange(of: model.contextKey) { _ in dismiss() }
  }

  private var maximum: Int {
    if !supplement { return loan.outstanding }
    if stage == "borrow" { return loan.quantity }
    return condition == "good" ? loan.returnedGood : loan.returnedQuarantine
  }

  private func submit() {
    guard context == model.contextKey else {
      dismiss()
      return
    }
    saving = true
    let payload: [String: Any] = [
      "stage": supplement ? stage : "return", "quantity": quantity, "condition": condition,
      "note": note, "attachments": attachments.map(\.payload),
    ]
    let completion: (Result<Void, Error>) -> Void = { result in
      saving = false
      switch result {
      case .success: dismiss()
      case .failure(let failure): error = failure.localizedDescription
      }
    }
    if supplement {
      model.store.addLoanFiles(loan: loan, payload: payload, completion: completion)
    } else {
      var returning = payload
      returning.removeValue(forKey: "stage")
      model.store.loanAction(
        loan: loan, action: "return", payload: returning, completion: completion)
    }
  }
}
