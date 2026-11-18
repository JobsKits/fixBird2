//
//  DesktopPasswordPolicy.swift
//  RepairDesktop
//
//  Created by Jobs on 2026年11月18日，星期三.
//

import Foundation

enum DesktopPasswordPolicy {
  private struct Table: Decodable {
    let properties: [String: [[UInt32]]]
  }

  private static let ranges: [[UInt32]] = {
    guard let url = Bundle.main.url(forResource: "password-emoji-ranges", withExtension: "json"),
      let data = try? Data(contentsOf: url),
      let table = try? JSONDecoder().decode(Table.self, from: data)
    else {
      return []
    }
    return table.properties["Emoji"] ?? []
  }()

  static func containsEmoji(_ value: String) -> Bool {
    value.contains(where: isEmoji)
  }

  static func removingEmoji(_ value: String) -> String {
    value.filter { !isEmoji($0) }
  }

  private static func isEmoji(_ character: Character) -> Bool {
    let scalars = character.unicodeScalars
    if scalars.contains(where: { $0.value == 0xFE0F || $0.value == 0x20E3 }) {
      return true
    }
    let bases = scalars.filter { scalar in
      scalar.value > 0x7F && (ranges.isEmpty
        ? scalar.properties.isEmoji
        : ranges.contains { $0.count == 2 && $0[0] <= scalar.value && scalar.value <= $0[1] })
    }
    if bases.contains(where: { ![0xA9, 0xAE, 0x2122].contains($0.value) }) {
      return true
    }
    // Text ©/®/™ stay valid; joining or emoji tag sequences do not.
    return !bases.isEmpty && scalars.contains {
      $0.value == 0x200D || (0xE0020...0xE007F).contains($0.value)
    }
  }
}
