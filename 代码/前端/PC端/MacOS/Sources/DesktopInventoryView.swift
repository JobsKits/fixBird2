//
//  DesktopInventoryView.swift
//  RepairDesktop
//
//  Created by Jobs on 2026年11月18日，星期三.
//

import SwiftUI

struct DesktopInventoryView: View {
  @EnvironmentObject private var model: DesktopModel
  @Environment(\.colorScheme) private var colorScheme
  @State private var selectedID: String?
  @State private var selectedPartID: String?
  @State private var borrowing = false
  @State private var returning = false
  @State private var supplementing = false
  private var t: (String) -> String { model.text }
  private var selected: WBLoan? { model.store.loans.first { $0.id == selectedID } }
  private var selectedPart: WBPart? { model.store.parts.first { $0.id == selectedPartID } }

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      HStack {
        Text(t("库存借还")).font(.title2).bold()
        Spacer()
        if ["admin", "warehouse"].contains(model.store.actor?.role ?? "") {
          Button(t("借出登记")) { borrowing = true }.buttonStyle(.borderedProminent)
        }
        Button(t("重新加载")) { model.store.refresh() }
      }
      HSplitView {
        VStack(alignment: .leading, spacing: 14) {
          if model.store.parts.isEmpty {
            empty
          } else {
            ForEach(model.store.parts, id: \.id) { part in
              Button {
                selectedPartID = part.id
                selectedID = nil
              } label: {
                HStack {
                  VStack(alignment: .leading, spacing: 4) {
                    Text(part.name).font(.headline)
                    Text(part.sku).font(.caption).foregroundStyle(.secondary)
                  }
                  Spacer()
                  Text(t("可用") + " \(part.available)").font(.callout)
                  Text(t("隔离") + " \(part.quarantine)").font(.callout)
                }.padding(12).contentShape(Rectangle())
              }.buttonStyle(.plain)
                .background(
                  selectedPartID == part.id
                    ? Color.secondary.opacity(colorScheme == .dark ? 0.25 : 0.14)
                    : Color.secondary.opacity(0.06)
                )
                .accessibilityAddTraits(selectedPartID == part.id ? .isSelected : [])
            }
          }
          Text(t("借还记录")).font(.headline)
          if model.store.loans.isEmpty {
            empty
          } else {
            List(Array(model.store.loans.enumerated()), id: \.element.id) { index, loan in
              Button {
                selectedID = loan.id
                selectedPartID = nil
              } label: {
                HStack {
                  Text("\(index + 1).")
                    .font(.callout.monospacedDigit())
                    .frame(minWidth: 22, alignment: .trailing)
                  VStack(alignment: .leading, spacing: 7) {
                    Text(loan.partName).font(.headline)
                    Text(loan.borrowerId).font(.caption).foregroundStyle(.secondary)
                    Text(t("借出时间") + " · " + model.timestamp(loan.createdAt))
                      .font(.caption).foregroundStyle(.secondary)
                    Text(t("归还期限") + " · " + model.timestamp(loan.dueAt))
                      .font(.caption).foregroundStyle(.secondary)
                  }
                  Spacer()
                  Text(t("尚欠") + " \(loan.outstanding)").font(.callout)
                }.padding(8).contentShape(Rectangle())
              }
              .buttonStyle(.plain)
              .listRowBackground(
                selectedID == loan.id
                  ? Color.secondary.opacity(colorScheme == .dark ? 0.25 : 0.14) : Color.clear
              )
              .accessibilityAddTraits(selectedID == loan.id ? .isSelected : [])
            }
          }
          Spacer(minLength: 0)
        }.padding(.trailing, 14).frame(minWidth: 310, idealWidth: 400)
        ScrollView {
          if let part = selectedPart {
            partDetail(part)
          } else if let loan = selected {
            VStack(alignment: .leading, spacing: 16) {
              Text(loan.partName).font(.title2).bold()
              LabeledContent(t("借用人账号"), value: loan.borrowerId)
              LabeledContent(t("数量"), value: String(loan.quantity))
              LabeledContent(t("尚欠"), value: String(loan.outstanding))
              LabeledContent(t("借出时间"), value: model.timestamp(loan.createdAt))
              LabeledContent(t("归还期限"), value: model.timestamp(loan.dueAt))
              if ["admin", "warehouse"].contains(model.store.actor?.role ?? "") {
                HStack {
                  Button(t("归还")) { returning = true }
                    .buttonStyle(.borderedProminent).disabled(
                      loan.outstanding < 1 || model.store.isBusy)
                  Button(t("补录图片凭据")) { supplementing = true }
                    .disabled(loan.files.count >= 8 || model.store.isBusy)
                }
              }
              Divider()
              Text(t("图片凭据")).font(.headline)
              if loan.files.isEmpty {
                Text(t("暂无图片凭据")).foregroundStyle(.secondary)
              } else {
                LazyVGrid(
                  columns: [GridItem(.adaptive(minimum: 240))], alignment: .leading, spacing: 14
                ) {
                  ForEach(loan.files, id: \.id) { file in
                    DesktopLoanProofTile(loan: loan, file: file).environmentObject(model)
                  }
                }
              }
            }.padding(20).frame(maxWidth: .infinity, alignment: .leading)
          } else {
            VStack(spacing: 16) {
              Image(systemName: "photo.on.rectangle.angled").font(.largeTitle)
              Text(t("请选择借还记录"))
            }.frame(maxWidth: .infinity, minHeight: 300)
          }
        }.frame(minWidth: 430)
      }
    }
    .padding(20)
    .sheet(isPresented: $borrowing) { DesktopLoanForm().environmentObject(model) }
    .sheet(isPresented: $returning) {
      if let loan = selected {
        DesktopLoanProofForm(loan: loan, supplement: false).environmentObject(model)
      }
    }
    .sheet(isPresented: $supplementing) {
      if let loan = selected {
        DesktopLoanProofForm(loan: loan, supplement: true).environmentObject(model)
      }
    }
    .onChange(of: model.contextKey) { _ in
      selectedID = nil
      selectedPartID = nil
      borrowing = false
      returning = false
      supplementing = false
    }
  }

  private func partDetail(_ part: WBPart) -> some View {
    let related = model.store.loans.filter { $0.partId == part.id }
    return VStack(alignment: .leading, spacing: 18) {
      Text(part.name).font(.title2).bold()
      LabeledContent("SKU", value: part.sku)
      LabeledContent(t("可用"), value: String(part.available))
      LabeledContent(t("隔离"), value: String(part.quarantine))
      Divider()
      Text(t("借还记录")).font(.headline)
      if related.isEmpty {
        empty
      } else {
        ForEach(Array(related.enumerated()), id: \.element.id) { index, loan in
          Button {
            selectedID = loan.id
            selectedPartID = nil
          } label: {
            HStack {
              Text("\(index + 1).").monospacedDigit()
              VStack(alignment: .leading, spacing: 6) {
                Text(loan.borrowerId).font(.headline)
                Text(t("借出时间") + " · " + model.timestamp(loan.createdAt))
                  .font(.caption).foregroundStyle(.secondary)
                Text(t("归还期限") + " · " + model.timestamp(loan.dueAt))
                  .font(.caption).foregroundStyle(.secondary)
              }
              Spacer()
              Text(t("数量") + " \(loan.quantity) · " + t("尚欠") + " \(loan.outstanding)")
              Image(systemName: "chevron.right").foregroundStyle(.secondary)
            }.padding(14).contentShape(Rectangle())
          }.buttonStyle(.plain).background(.quaternary.opacity(0.35))
        }
      }
    }.padding(20).frame(maxWidth: .infinity, alignment: .leading)
  }

  private var empty: some View {
    VStack(spacing: 10) {
      Image(systemName: "tray").font(.title)
      Text(t("暂时没有记录"))
      Button(t("重新加载")) { model.store.refresh() }
    }.padding(20).frame(maxWidth: .infinity)
  }
}
