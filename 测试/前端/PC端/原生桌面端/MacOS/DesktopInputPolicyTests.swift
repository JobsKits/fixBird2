//
//  DesktopInputPolicyTests.swift
//  RepairDesktopTests
//
//  Created by Jobs on 2026年11月18日，星期三.
//

import Foundation

@main struct DesktopInputPolicyTests {
  static func main() throws {
    let source = Bundle.main.url(forResource: "password-emoji-ranges", withExtension: "json")!
    let raw = try JSONSerialization.jsonObject(with: Data(contentsOf: source)) as! [String: Any]
    let properties = raw["properties"] as! [String: [[Int]]]
    var assertions = 0
    func check(_ condition: Bool) {
      precondition(condition, "Assertion \(assertions)")
      assertions += 1
    }
    for range in properties["Emoji"]! {
      for codepoint in range[0]...range[1] {
        let expected = codepoint > 127 && ![0xA9, 0xAE, 0x2122].contains(codepoint)
        check(DesktopPasswordPolicy.containsEmoji(String(UnicodeScalar(codepoint)!)) == expected)
      }
    }
    for value in ["😄", "🌹", "❤", "☀", "☹", "🇨🇳", "👨‍👩‍👧‍👦", "👍🏽", "1️⃣", "#️⃣", "*️⃣", "©️", "©‍", "©︎‍", "©́‍", "©‌‍", "®‍", "™‍"] {
      check(DesktopPasswordPolicy.containsEmoji(value))
      check(DesktopPasswordPolicy.removingEmoji("Ab#*9" + value + "中文") == "Ab#*9中文")
    }
    for value in ["Ab#*0123456789!", "中文日本語한국어", "MotDePasseÉté", "གསང་ཨང་", "©®™", "123क्‍ष", "©123क्‍ष", "®123क्‍ष", "™123क्‍ष", "©text\u{E0061}"] {
      check(!DesktopPasswordPolicy.containsEmoji(value))
      check(DesktopPasswordPolicy.removingEmoji(value) == value)
    }
    let missing = "missing"
    let full = DesktopTimestamp.format("2026-11-18T08:05:59.5397490+00:00", language: "zh-Hans", missing: missing)
    check(full.contains("2026") && full.contains("16:05"))
    check(DesktopTimestamp.format("2026-11-18T16:05:59+08:00", language: "zh-Hans", missing: missing) == full)
    check(DesktopTimestamp.format("", language: "zh-Hans", missing: missing) == missing)
    check(DesktopTimestamp.format("invalid", language: "zh-Hans", missing: missing) == missing)
    check(DesktopTimestamp.format("2026-11-18T08:05:59Z", language: "en", missing: missing) != full)
    print("PASS native password Unicode coverage, grapheme filtering, ordinary text and Shanghai timestamps:", assertions)
  }
}
