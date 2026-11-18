//
//  DesktopSettingsView.swift
//  RepairDesktop
//
//  Created by Jobs on 2026年11月18日，星期三.
//

import SwiftUI

struct DesktopSettingsView: View {
  @EnvironmentObject private var model: DesktopModel
  @Environment(\.dismiss) private var dismiss
  var closeOnSave = false
  @State private var endpoint = ""
  @State private var timeout = 2.5
  @State private var error = ""
  private var t: (String) -> String { model.text }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 22) {
        Label(t("设置"), systemImage: "gearshape").font(.title2).bold()
        GroupBox {
          VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 14) {
              Text(t("语言")).frame(width: 60, alignment: .leading)
              Picker(t("语言"), selection: $model.language) {
                ForEach(
                  Array(
                    zip(
                      ["zh-Hans", "zh-Hant", "bo", "en", "ja", "fr", "es", "de", "ru", "ko"],
                      [
                        "简体中文", "繁體中文", "བོད་ཡིག", "English", "日本語", "Français", "Español", "Deutsch",
                        "Русский", "한국어",
                      ]
                    )), id: \.0
                ) { pair in
                  Text(pair.1).tag(pair.0)
                }
              }.labelsHidden().frame(width: 200)
              Spacer(minLength: 0)
            }
            HStack(spacing: 14) {
              Text(t("主题")).frame(width: 60, alignment: .leading)
              Picker(t("主题"), selection: $model.theme) {
                Text(t("白天")).tag("light")
                Text(t("黑夜")).tag("dark")
                Text(t("跟随系统")).tag("system")
              }.labelsHidden().pickerStyle(.segmented).frame(maxWidth: 340)
              Spacer(minLength: 0)
            }
          }.padding(14).frame(maxWidth: .infinity, alignment: .leading)
        } label: {
          Label(t("语言") + " · " + t("主题"), systemImage: "paintpalette")
        }
        GroupBox {
          VStack(alignment: .leading, spacing: 14) {
            Text(t("服务地址")).font(.callout).foregroundStyle(.secondary)
            TextField(t("服务地址"), text: $endpoint).textFieldStyle(.roundedBorder)
            HStack {
              Text(t("请求超时"))
              Spacer()
              Text(String(format: "%.1f s", timeout)).monospacedDigit()
            }
            Slider(value: $timeout, in: 0.5...30, step: 0.5) {
              Text(t("请求超时"))
            }
            if !error.isEmpty {
              Text(t(error)).font(.callout).foregroundStyle(.red)
            }
            HStack {
              Spacer()
              Button(t("保存设置")) {
                do {
                  try model.store.configureEndpoint(endpoint, timeout: timeout)
                  model.message = ""
                  error = ""
                  if closeOnSave { dismiss() }
                } catch {
                  self.error = error.localizedDescription
                  model.message = error.localizedDescription
                }
              }.buttonStyle(.borderedProminent)
            }
          }.padding(14)
        } label: {
          Label(t("服务地址"), systemImage: "network")
        }
      }
      .frame(maxWidth: 820, alignment: .leading)
      .padding(24)
      .frame(maxWidth: .infinity, alignment: .topLeading)
    }
    .onAppear {
      endpoint = model.store.endpoint
      timeout = model.store.timeout
    }
  }
}
