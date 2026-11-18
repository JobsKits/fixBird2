//
//  DesktopLogo.swift
//  RepairDesktop
//
//  Created by Jobs on 2026年11月18日，星期三.
//

import AppKit
import SwiftUI

struct DesktopLogo: View {
  private static let logo = NSImage.makeRepairLogo()

  var body: some View {
    if let image = Self.logo {
      Image(nsImage: image)
        .resizable()
        .scaledToFit()
        .accessibilityLabel("啄木鸟维修平台")
    }
  }
}

extension NSImage {
  fileprivate static func makeRepairLogo() -> NSImage? {
    guard let url = Bundle.main.url(forResource: "RepairLogo", withExtension: "png") else {
      return nil
    }
    return NSImage(contentsOf: url)
  }
}
