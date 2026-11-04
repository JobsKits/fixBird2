//
//  JobsPreparedRequest.swift
//  JobsNetworking
//
//  Created by Jobs on 2026年5月13日，星期三.
//

import Foundation
import Alamofire

struct JobsPreparedRequest {
    let url: URL
    let method: HTTPMethod
    let parameters: Parameters?
    let encoding: ParameterEncoding?
    let headers: HTTPHeaders
    let timeout: TimeInterval?
    let rawBody: Data?
    let trace: JobsTrace
}

enum JobsEncodingRule {
    static func encoding(for request: JobsRequest) -> JobsParameterEncoding {
        if let encoding = request.encoding { return encoding }
        switch request.method {
        /// 合并处理 .get、.head、.delete 分支
        case .get, .head, .delete:
            return .urlQuery
        /// 合并处理 .post、.put、.patch 分支
        case .post, .put, .patch:
            return .jsonBody
        }
    }

    static func validate(_ request: JobsRequest, encoding: JobsParameterEncoding) throws {
        switch encoding {
        /// 处理 .urlQuery 分支
        case .urlQuery:
            if let body = request.body, !body.isEmpty {
                throw JobsError.invalidRequest(reason: "URL Query encoding does not allow body payload")
            }
        /// 处理 .multipart 分支
        case .multipart:
            break
        /// 处理 .rawData 分支
        case .rawData:
            if let body = request.body, !body.isEmpty {
                throw JobsError.invalidRequest(reason: "Raw data encoding does not allow a second body payload")
            }
        /// 合并处理 .jsonBody、.formURLEncoded 分支
        case .jsonBody, .formURLEncoded:
            break
        }
    }
}
