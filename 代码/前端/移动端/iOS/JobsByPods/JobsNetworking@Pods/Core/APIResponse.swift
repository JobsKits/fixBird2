//
//  APIResponse.swift
//  JobsNetworking
//
//  Created by Jobs on 2026年5月13日，星期三.
//

import Foundation

public protocol JobsAPIResponseType {}

public struct APIResponse<T: Decodable>: Decodable, JobsAPIResponseType {
    public let code: Int
    public let msg: String?
    public let data: T?

    public var isSuccess: Bool {
        code == 0 || code == 200
    }

    enum CodingKeys: String, CodingKey {
        case code
        case msg
        case message
        case data
    }

    public init(code: Int, msg: String?, data: T?) {
        self.code = code
        self.msg = msg
        self.data = data
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        code = try container.decode(Int.self, forKey: .code)
        msg = try container.decodeIfPresent(String.self, forKey: .msg)
            ?? container.decodeIfPresent(String.self, forKey: .message)
        data = try container.decodeIfPresent(T.self, forKey: .data)
    }
}

extension APIResponse: JobsEnvelopeDecodable {
    public typealias Payload = T
    public var jobsCode: Int { code }
    public var jobsMessage: String? { msg }
    public var jobsPayload: T? { data }
}
