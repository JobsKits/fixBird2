//
//  DesktopAuthView.swift
//  RepairDesktop
//
//  Created by Jobs on 2026年11月18日，星期三.
//

import SwiftUI

struct DesktopAuthView: View {
  @EnvironmentObject private var model: DesktopModel
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var mode = "login"
  @State private var role = "admin"
  @State private var username = ""
  @State private var password = ""
  @State private var confirmation = ""
  @State private var name = ""
  @State private var email = ""
  @State private var code = ""
  @State private var visible = false
  @State private var confirmationVisible = false
  @State private var autoFilled = false
  @State private var preservingRegisteredAccount = false
  @State private var message = ""
  @State private var busy = false
  @State private var sendingCode = false
  @State private var passwordRejected = false
  @State private var confirmationRejected = false
  @State private var attempt = 0
  private var t: (String) -> String { model.text }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        HStack(spacing: 14) {
          DesktopLogo().frame(width: 48, height: 48)
          VStack(alignment: .leading, spacing: 5) {
            Text(t("欢迎使用")).font(.title).bold()
            Text(t("啄木鸟维修平台")).foregroundStyle(.secondary)
          }
        }
        HStack(alignment: .top, spacing: 20) {
          VStack(alignment: .leading, spacing: 12) {
            ForEach(["login", "register", "reset"], id: \.self) { destination in
              Button {
                switchMode(destination)
              } label: {
                VStack(alignment: .center, spacing: 12) {
                  Image(
                    systemName: destination == "login"
                      ? "person.crop.circle"
                      : destination == "register" ? "person.badge.plus" : "key"
                  )
                  .font(.system(size: 40, weight: .medium))
                  Text(t(title(destination)))
                    .font(.system(size: 24, weight: .semibold))
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                    .multilineTextAlignment(.center)
                }
                .frame(width: 132, alignment: .center)
                .frame(maxHeight: .infinity, alignment: .center)
                .padding(16)
                .background(mode == destination ? Color.accentColor : Color.secondary.opacity(0.08))
                .foregroundStyle(mode == destination ? Color.white : Color.primary)
                .clipShape(RoundedRectangle(cornerRadius: 12))
              }
              .buttonStyle(.plain)
              .accessibilityLabel(t(title(destination)))
              .help(t(title(destination)))
              .accessibilityAddTraits(mode == destination ? .isSelected : [])
            }
          }
          card.id(mode)
            .transition(
              .asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)))
        }
        .frame(height: 480)
        .clipped()
      }
      .frame(maxWidth: 790, alignment: .leading)
      .padding(28)
      .frame(maxWidth: .infinity, alignment: .top)
    }
    .onAppear { prefillIfNeeded() }
    .onChange(of: model.localDemoAvailable) { available in
      if available {
        prefillIfNeeded()
      } else if autoFilled {
        username = ""
        password = ""
        visible = false
        autoFilled = false
      }
    }
    .onChange(of: model.store.endpoint) { _ in
      attempt += 1
      busy = false
      sendingCode = false
      passwordRejected = false
      confirmationRejected = false
      message = ""
      username = ""
      password = ""
      confirmation = ""
      code = ""
      visible = false
    }
    .onDisappear {
      attempt += 1
      if model.store.actor == nil {
        model.store.logout()
      }
    }
  }

  private var card: some View {
    VStack(alignment: .leading, spacing: 16) {
      ScrollView {
        VStack(alignment: .leading, spacing: 14) {
          if mode == "login", model.localDemoAvailable {
            Picker(t("本地演示账号"), selection: $role) {
              ForEach(model.store.demoAccounts, id: \.id) { actor in
                Text(t(actor.roleLabel)).tag(actor.role)
              }
            }
            .disabled(busy || model.store.isBusy)
            .onChange(of: role) { _ in
              if preservingRegisteredAccount {
                preservingRegisteredAccount = false
              } else {
                fillRole()
              }
            }
            Divider()
          }
          if mode == "register" {
            HStack(alignment: .top, spacing: 14) {
              field("用户名", text: $username)
              field("姓名", text: $name)
            }
          } else if mode == "login" {
            field("用户名", text: $username)
          }
          if mode != "login" {
            field("邮箱", text: $email)
            HStack(alignment: .bottom) {
              field("验证码", text: $code)
              Button(action: sendCode) {
                HStack(spacing: 8) {
                  if sendingCode {
                    ProgressView().controlSize(.small)
                  } else {
                    Image(systemName: "paperplane")
                  }
                  Text(t(sendingCode ? "发送中…" : "发送验证码"))
                    .font(.body.weight(.semibold))
                }
                .padding(.horizontal, 14)
                .frame(minWidth: 132, minHeight: 42)
                .foregroundStyle(busy || email.isEmpty ? Color.secondary : Color.accentColor)
                .background(busy || email.isEmpty ? Color.secondary.opacity(0.1) : Color.accentColor.opacity(0.14))
                .clipShape(RoundedRectangle(cornerRadius: 8))
              }
              .buttonStyle(.plain)
              .disabled(busy || model.store.isBusy || email.isEmpty)
            }
          }
          VStack(alignment: .leading, spacing: 6) {
            Text(t("密码")).font(.callout).foregroundStyle(.secondary)
            passwordField(text: $password, visible: $visible, rejected: $passwordRejected)
          }
          if mode != "login" {
            VStack(alignment: .leading, spacing: 6) {
              Text(t("确认密码")).font(.callout).foregroundStyle(.secondary)
              passwordField(text: $confirmation, visible: $confirmationVisible, rejected: $confirmationRejected)
            }
          }
          if mode == "login", model.localDemoAvailable {
            Text(t("已预填合成账号和密码，可直接登录；仅用于演示。"))
              .font(.caption).foregroundStyle(.secondary)
          }
        }.frame(maxWidth: .infinity, alignment: .leading)
      }
      if !message.isEmpty {
        Text(t(message)).font(.callout).foregroundStyle(.secondary).textSelection(.enabled)
      }
      HStack {
        if busy || model.store.isBusy { ProgressView().controlSize(.small) }
        Spacer()
        Button(t(mode == "login" ? "登录" : mode == "register" ? "创建账号" : "重置密码"), action: submit)
          .buttonStyle(.borderedProminent)
          .keyboardShortcut(.defaultAction)
          .disabled(
            busy || model.store.isBusy || passwordRejected || confirmationRejected || password.isEmpty
              || (mode != "reset" && username.isEmpty))
      }
    }
    .padding(24)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    .background(.background)
    .clipShape(RoundedRectangle(cornerRadius: 16))
    .overlay(RoundedRectangle(cornerRadius: 16).stroke(.secondary.opacity(0.2)))
  }

  private func field(_ title: String, text: Binding<String>) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(t(title)).font(.callout).foregroundStyle(.secondary)
      TextField(t(title), text: text).textFieldStyle(.plain)
        .padding(.horizontal, 10).frame(height: 42)
        .background(.background)
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(.secondary.opacity(0.35)))
        .disabled(busy || model.store.isBusy)
    }
  }

  private func passwordField(text: Binding<String>, visible: Binding<Bool>, rejected: Binding<Bool>) -> some View {
    DesktopPasswordField(
      title: t("密码"), showTitle: t("显示密码"), hideTitle: t("隐藏密码"), text: text, visible: visible,
      rejectionTitle: t("密码不能包含表情符号"),
      onRejectionChange: { rejected.wrappedValue = $0 }
    )
    .disabled(busy || model.store.isBusy)
  }

  private func title(_ mode: String) -> String {
    mode == "login" ? "登录" : mode == "register" ? "新用户注册" : "忘记密码"
  }

  private func switchMode(_ destination: String) {
    guard mode != destination else { return }
    attempt += 1
    busy = false
    sendingCode = false
    passwordRejected = false
    confirmationRejected = false
    model.store.logout()
    if destination == "register", autoFilled {
      username = ""
      autoFilled = false
    }
    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.3)) {
      mode = destination
      password = ""
      confirmation = ""
      code = ""
      message = ""
      visible = false
      confirmationVisible = false
    }
    prefillIfNeeded()
  }

  private func fillRole() {
    username = role
    password = role == "admin" ? "1234" : "Demo-Repair-2026!"
    visible = true
    autoFilled = true
  }

  private func prefillIfNeeded() {
    if mode == "login", model.localDemoAvailable, username.isEmpty || autoFilled {
      fillRole()
    }
  }

  private func sendCode() {
    attempt += 1
    let revision = attempt
    let endpoint = model.store.endpoint
    busy = true
    sendingCode = true
    model.authRequest(
      path: "/auth/email-code",
      body: ["email": email, "purpose": mode == "register" ? "register" : "reset_password"]
    ) { result in
      guard revision == attempt, endpoint == model.store.endpoint else { return }
      busy = false
      sendingCode = false
      switch result {
      case .success(let response):
        if model.localDemoAvailable, let sample = response.object?["demoCode"]?.string {
          code = sample
          message = t("演示验证码") + "：" + sample
        } else {
          message = t("验证码已发送")
        }
      case .failure(let error):
        message = error.localizedDescription
      }
    }
  }

  private func submit() {
    attempt += 1
    let revision = attempt
    let endpoint = model.store.endpoint
    message = ""
    guard !passwordRejected, !confirmationRejected,
      !DesktopPasswordPolicy.containsEmoji(password),
      !DesktopPasswordPolicy.containsEmoji(confirmation) else {
      message = t("密码不能包含表情符号")
      return
    }
    if mode == "login" {
      busy = true
      model.login(username: username, password: password) { result in
        guard revision == attempt, endpoint == model.store.endpoint else { return }
        busy = false
        if case .failure(let error) = result { message = error.localizedDescription }
      }
      return
    }
    guard password == confirmation else {
      message = t("两次输入的密码不一致")
      return
    }
    busy = true
    let registering = mode == "register"
    let submittedUsername = username
    model.authRequest(
      path: registering ? "/register" : "/reset-password",
      body: [
        "username": registering ? username : "", "name": name, "email": email, "code": code,
        "password": password, "confirmPassword": confirmation,
      ].filter { registering || !["username", "name"].contains($0.key) }
    ) { result in
      guard revision == attempt, endpoint == model.store.endpoint else { return }
      busy = false
      switch result {
      case .success(let response):
        guard response.object?["ok"] == .boolean(true) else {
          message = t("响应缺少数据")
          return
        }
        autoFilled = false
        username = registering ? submittedUsername : email
        if registering, role != "customer" {
          preservingRegisteredAccount = true
          role = "customer"
        }
        switchMode("login")
        password = ""
        visible = false
        autoFilled = false
        message = t(registering ? "注册成功，请登录" : "密码已重置，请登录")
      case .failure(let error):
        message = error.localizedDescription
      }
    }
  }
}
