//
//  JobsEnvelope.swift
//  JobsNetworking
//
//  Created by Jobs on 2026年5月13日，星期三.
//

import Foundation

public struct JobsEnvelope<Payload: Decodable>: Decodable {
    public let code: Int
    public let message: String?
    public let data: Payload?

    public init(code: Int, message: String?, data: Payload?) {
        self.code = code
        self.message = message
        self.data = data
    }
}

public protocol JobsEnvelopeDecodable: Decodable {
    associatedtype Payload: Decodable
    var jobsCode: Int { get }
    var jobsMessage: String? { get }
    var jobsPayload: Payload? { get }
}

extension JobsEnvelope: JobsEnvelopeDecodable {
    public var jobsCode: Int { code }
    public var jobsMessage: String? { message }
    public var jobsPayload: Payload? { data }
}

extension JobsEnvelope: Sendable where Payload: Sendable {}
