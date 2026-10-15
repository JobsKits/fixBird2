//
//  WBFieldKind.swift
//  WoodpeckerWorkbench
//
//  Created by Jobs on 2026年10月15日，星期四.
//

import Foundation

enum WBFieldKind {
    case text
    case multiline
    case money
    case integer
    case date
    case dateTime
    case choice([(String, String)])
    case multiple([(String, String)])
}
