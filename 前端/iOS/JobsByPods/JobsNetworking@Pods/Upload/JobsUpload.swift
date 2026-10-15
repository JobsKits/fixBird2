//
//  JobsUpload.swift
//  JobsNetworking
//
//  Created by Jobs on 2026年5月13日，星期三.
//

import Foundation

public protocol JobsUploadCapable: JobsAgent {
    @discardableResult
    func upload<T: Decodable>(
        _ request: JobsUploadRequest,
        as type: T.Type,
        completion: @escaping (Result<T, JobsError>) -> Void
    ) -> JobsRequestToken
}
