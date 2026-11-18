//
//  DesktopAction.swift
//  RepairDesktop
//
//  Created by Jobs on 2026年11月18日，星期三.
//

import AppKit
import SwiftUI

struct DesktopAction: Decodable {
    let title: String
    let fields: [Field]
    struct Field: Decodable {
        let key: String
        let title: String
        let kind: String
        let value: String
        let options: [String]
    }

    static let all: [String: DesktopAction] = {
        let url = Bundle.main.url(forResource: "actions", withExtension: "json")!
        return (try? JSONDecoder.desktopMake().decode([String: DesktopAction].self, from: Data(contentsOf: url)))
            ?? [:]
    }()
}

extension JSONDecoder {
    static func desktopMake() -> JSONDecoder {
        JSONDecoder()
    }
}
