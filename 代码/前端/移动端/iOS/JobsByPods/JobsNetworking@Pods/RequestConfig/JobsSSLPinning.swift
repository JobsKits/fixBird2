//
//  JobsSSLPinning.swift
//  JobsNetworking
//
//  Created by Jobs on 2026年5月13日，星期三.
//

import Foundation

public struct JobsSSLPinning: Sendable {
    public enum Mode: Sendable {
        case certificates
        case publicKeys
    }

    public var mode: Mode
    public var pinnedHosts: [String]
    public var validatesHost: Bool
    public var allowsSelfSigned: Bool

    public init(
        mode: Mode = .certificates,
        pinnedHosts: [String],
        validatesHost: Bool = true,
        allowsSelfSigned: Bool = false
    ) {
        self.mode = mode
        self.pinnedHosts = pinnedHosts
        self.validatesHost = validatesHost
        self.allowsSelfSigned = allowsSelfSigned
    }
}
