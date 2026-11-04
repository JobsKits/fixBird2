//
//  JobsParameterEncoding.swift
//  JobsNetworking
//
//  Created by Jobs on 2026年5月13日，星期三.
//

import Foundation

public enum JobsParameterEncoding: Codable, Sendable {
    case urlQuery
    case jsonBody
    case formURLEncoded
    case multipart
    case rawData(Data)
}
