//
//  DesktopTimestamp.swift
//  RepairDesktop
//
//  Created by Jobs on 2026年11月18日，星期三.
//

import Foundation

enum DesktopTimestamp {
  static func format(_ value: String, language: String, missing: String) -> String {
    let parser = ISO8601DateFormatter()
    parser.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    let fractional = parser.date(from: value)
    parser.formatOptions = [.withInternetDateTime]
    guard let date = fractional ?? parser.date(from: value) else {
      return missing
    }
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: language)
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.timeZone = TimeZone(identifier: "Asia/Shanghai")
    formatter.setLocalizedDateFormatFromTemplate("yyyyMMMdHHmm")
    return formatter.string(from: date)
  }
}
