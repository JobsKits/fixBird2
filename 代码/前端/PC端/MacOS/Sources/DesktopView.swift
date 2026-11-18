//
//  DesktopView.swift
//  RepairDesktop
//
//  Created by Jobs on 2026年11月18日，星期三.
//

import SwiftUI

struct DesktopView: View {
  @EnvironmentObject private var model: DesktopModel
  @Environment(\.colorScheme) private var colorScheme
  @State private var query = ""
  @State private var status = ""
  @State private var creating = false
  @State private var action: String?
  @State private var connectionSettings = false
  private var t: (String) -> String {
    model.text
  }

  var body: some View {
    VStack(spacing: 0) {
      HStack {
        DesktopLogo().frame(width: 44, height: 44)
        VStack(alignment: .leading) {
          Text(t("啄木鸟维修平台")).font(.title2).bold()
          Text(
            t(
              model.store.actor == nil
                ? (model.localDemoAvailable ? "本地演示账号" : "请先登录") : model.store.sourceLabel)
          ).font(.caption).foregroundStyle(
            model.store.isDemo ? Color.orange : Color.green)
        }

        Spacer()
        if model.store.isBusy {
          ProgressView().controlSize(.small)
        }

        if let actor = model.store.actor {
          Text(
            actor.name == actor.roleLabel || actor.name == t(actor.roleLabel)
              ? t(actor.roleLabel) : actor.name + " · " + t(actor.roleLabel))
          Button(t("重新加载")) {
            model.store.refresh()
          }

          Button(t("退出登录")) {
            model.store.logout()
          }
        } else {
          Button {
            connectionSettings = true
          } label: {
            Label(t("设置"), systemImage: "gearshape")
          }
        }
      }.padding(18)
      Divider()
      if model.store.actor == nil {
        DesktopAuthView().environmentObject(model)
      } else {
        TabView {
          orders.tabItem {
            Label(t("工单"), systemImage: "wrench.and.screwdriver")
          }

          DesktopInventoryView().environmentObject(model).tabItem {
            Label(t("库存借还"), systemImage: "shippingbox")
          }

          DesktopSettingsView().environmentObject(model).tabItem {
            Label(t("设置"), systemImage: "gearshape")
          }
        }.padding(12)
      }

      HStack {
        Text(t(model.message.isEmpty ? model.store.lastMessage : model.message)).font(.caption)
          .textSelection(.enabled)
        Spacer()
      }.padding(12).background(.quaternary)
    }.sheet(isPresented: $creating) {
      DesktopCreateForm().environmentObject(model)
    }.sheet(
      isPresented: Binding(
        get: {
          action != nil && model.selected != nil
        },
        set: {
          if !$0 {
            action = nil
          }
        }
      )
    ) {
      if let selected = model.selected, let action {
        DesktopActionForm(order: selected, action: action).environmentObject(model)
      }
    }.sheet(isPresented: $connectionSettings) {
      DesktopSettingsView(closeOnSave: true).environmentObject(model).frame(width: 660, height: 460)
    }.onAppear {
      model.refreshDemoAvailability()
    }.onChange(of: model.store.endpoint) { _ in
      model.refreshDemoAvailability()
    }
  }

  private var orders: some View {
    HSplitView {
      VStack(alignment: .leading) {
        HStack {
          TextField(t("搜索工单"), text: $query).textFieldStyle(.roundedBorder).onSubmit {
            search()
          }

          Button(t("搜索"), action: search)
          Button(t("新建工单")) {
            creating = true
          }
        }

        Picker(t("状态"), selection: $status) {
          Text(t("全部")).tag("")
          ForEach(WBOrder.statusLabels.keys.sorted(), id: \.self) {
            key in
            Text(t(WBOrder.statusLabels[key]!)).tag(key)
          }
        }.onChange(of: status) {
          _ in search()
        }

        VStack(alignment: .leading, spacing: 5) {
          Text(t("当前已加载工单")).foregroundStyle(.secondary)
          HStack {
            Text(t("进行中") + " \(model.visibleOpenCount)")
            Spacer()
            Text(t("待收款") + " " + WBFoundation.amount(model.visibleRemainingCents))
          }
        }.font(.caption).padding(.vertical, 8)
        if model.visibleOrders.isEmpty {
          empty
        } else {
          List(Array(model.visibleOrders.enumerated()), id: \.element.id) {
            index, order in
            let isSelected = model.selectedOrderID == order.id
            Button {
              model.open(order)
            } label: {
              VStack(alignment: .leading, spacing: 6) {
                HStack {
                  Text("\(index + 1).")
                    .monospacedDigit()
                  Text(order.number).bold()
                  Spacer()
                  Text(t(order.statusLabel)).font(.caption)
                }

                Text(order.device + " · " + order.customer)
                Text(t("创建时间") + " · " + model.timestamp(order.raw["createdAt"]?.string ?? ""))
                  .font(.caption)
                Text(t(order.summary.nextTask)).font(.caption).foregroundStyle(
                  isSelected ? selectedRowForeground.opacity(0.85) : Color.secondary)
              }.padding(5).contentShape(Rectangle())
            }.buttonStyle(.plain)
              .foregroundStyle(isSelected ? selectedRowForeground : Color.primary)
              .listRowBackground(isSelected ? selectedRowBackground : Color.clear)
              .accessibilityAddTraits(isSelected ? .isSelected : [])
          }
        }

        if model.store.hasMore {
          Button(t("加载更多")) {
            model.store.loadMore()
          }
        }
      }.padding(12).frame(minWidth: 360, idealWidth: 440)
      ScrollView {
        if let order = model.selected {
          VStack(alignment: .leading, spacing: 20) {
            HStack {
              Text(order.number).font(.title2).bold()
              Spacer()
              Button(t("重新加载")) {
                model.open(order)
              }
            }

            Text(t(order.statusLabel) + " · " + t(order.typeLabel))
            LabeledContent(t("创建时间"), value: model.timestamp(order.raw["createdAt"]?.string ?? ""))
            LabeledContent(t("更新时间"), value: model.timestamp(order.raw["updatedAt"]?.string ?? ""))
            LabeledContent(t("客户"), value: order.customer)
            LabeledContent(t("项目"), value: order.project)
            LabeledContent(t("设备"), value: order.device)
            Text(order.description).textSelection(.enabled)
            DesktopDeviceEvidenceView(order: order).environmentObject(model)
            Divider()
            Text(t("报价") + " " + WBFoundation.amount(order.quote.amountCents)).font(.headline)
            Text(order.quote.description)
            Text(t(order.quote.startRequiresPrepayment ? "已明确约定，核实约定预付款后开修" : "未约定先款开修"))
            Text(t("约定预付款（元，可为零）") + " " + WBFoundation.amount(order.quote.prepayCents))
            Text(t("待收款") + " " + WBFoundation.amount(order.summary.remainingCents))
            Text(t(order.summary.nextTask)).font(.headline)
            Text(order.customerNote).textSelection(.enabled)
            if !order.remark.isEmpty {
              Text(t("内部备注") + " · " + order.remark)
            }

            Divider()
            Text(t("当前可办理")).font(.headline)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 170))], alignment: .leading) {
              ForEach(
                order.allowedActions.filter {
                  DesktopAction.all[$0] != nil
                }, id: \.self
              ) {
                key in
                Button(t(DesktopAction.all[key]!.title)) {
                  action = key
                }.disabled(
                  model.store.isBusy)
              }
            }

            Divider()
            Text(t("业务记录")).font(.headline)
            ForEach(order.events.indices.reversed(), id: \.self) {
              i in
              VStack(alignment: .leading) {
                Text(order.events[i].string("createdAt")).font(.caption).foregroundStyle(.secondary)
                Text(order.events[i].string("note"))
                Text(order.events[i].string("type")).font(.caption)
              }
            }

            ForEach(order.cash, id: \.id) {
              cash in
              Text(
                t(cash.bool("verified") ? "已核实" : "待核实") + " · "
                  + WBFoundation.amount(cash.int("amountCents")) + " · " + cash.id
              ).font(.caption)
            }
          }.padding(24).textSelection(.enabled)
        } else {
          VStack(spacing: 18) {
            Image(systemName: "doc.text.magnifyingglass").font(.largeTitle)
            Text(t("请选择工单"))
          }.frame(maxWidth: .infinity, minHeight: 430)
        }
      }.frame(minWidth: 430)
    }
  }

  private var empty: some View {
    VStack(spacing: 12) {
      Image(systemName: "tray").font(.largeTitle)
      Text(t("暂时没有记录"))
      Text(t("可以调整筛选条件，或重新加载当前列表。"))
        .font(.caption)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
      Button(t("重新加载")) {
        model.store.refresh()
      }
    }.frame(maxWidth: .infinity, minHeight: 130)
  }

  private func search() {
    model.setOrderFilter(query, status: status)
  }

  private var selectedRowBackground: Color {
    colorScheme == .dark
      ? Color(red: 0.64, green: 0.84, blue: 0.71)
      : Color(red: 0.14, green: 0.37, blue: 0.28)
  }

  private var selectedRowForeground: Color {
    colorScheme == .dark ? Color(red: 0.08, green: 0.19, blue: 0.13) : .white
  }
}
