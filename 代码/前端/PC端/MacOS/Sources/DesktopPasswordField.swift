//
//  DesktopPasswordField.swift
//  RepairDesktop
//
//  Created by Jobs on 2026年11月18日，星期三.
//

import SwiftUI

struct DesktopPasswordField: View {
  let title: String
  let showTitle: String
  let hideTitle: String
  @Binding var text: String
  @Binding var visible: Bool
  var rejectionTitle = "密码不能包含表情符号"
  var onRejectionChange: (Bool) -> Void = { _ in }
  @FocusState private var focused: Bool
  @State private var rejectedEmoji = false

  private var filteredText: Binding<String> {
    Binding(
      get: { text },
      set: { proposed in
        let accepted = DesktopPasswordPolicy.removingEmoji(proposed)
        if proposed != accepted {
          rejectedEmoji = true
          onRejectionChange(true)
        } else if proposed != text {
          rejectedEmoji = false
          onRejectionChange(false)
        }
        text = accepted
      }
    )
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      HStack(spacing: 8) {
        Group {
          if visible {
            TextField(title, text: filteredText)
          } else {
            SecureField(title, text: filteredText)
          }
        }
        .textFieldStyle(.plain)
        .focused($focused)
        .accessibilityLabel(title)
        Button {
          visible.toggle()
          focused = true
        } label: {
          Image(systemName: visible ? "eye" : "eye.slash")
            .frame(width: 40, height: 42)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(visible ? hideTitle : showTitle)
        .accessibilityLabel(visible ? hideTitle : showTitle)
        .accessibilityValue(visible ? showTitle : hideTitle)
      }
      .padding(.leading, 10)
      .frame(minHeight: 42)
      .background(.background)
      .overlay(RoundedRectangle(cornerRadius: 6).stroke(.secondary.opacity(0.35)))
      if rejectedEmoji {
        Text(rejectionTitle).font(.caption).foregroundStyle(.red)
      }
    }
  }
}
