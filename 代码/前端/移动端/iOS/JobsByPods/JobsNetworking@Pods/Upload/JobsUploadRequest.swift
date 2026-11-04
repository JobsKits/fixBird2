//
//  JobsUploadRequest.swift
//  JobsNetworking
//
//  Created by Jobs on 2026年5月13日，星期三.
//

import Foundation

public struct JobsUploadRequest: Sendable {
    public var path: String
    public var method: HTTPMethod
    public var files: [JobsUploadFileSpec]
    public var form: [String: JobsValue]
    public var headers: [String: String]
    public var timeout: TimeInterval?
    public var trace: JobsTrace
    public var retryPolicy: JobsRetryPolicy?

    public init(
        path: String,
        method: HTTPMethod = .post,
        files: [JobsUploadFileSpec],
        form: [String: JobsValue] = [:],
        headers: [String: String] = [:],
        timeout: TimeInterval? = nil,
        trace: JobsTrace = JobsTrace(),
        retryPolicy: JobsRetryPolicy? = nil
    ) {
        self.path = path
        self.method = method
        self.files = files
        self.form = form
        self.headers = headers
        self.timeout = timeout
        self.trace = trace
        self.retryPolicy = retryPolicy
    }
}

public enum JobsUploadFileSpec: Sendable {
    case file(url: URL, name: String, fileName: String, mimeType: String)
    case data(data: Data, name: String, fileName: String, mimeType: String)
}

public struct JobsMultipartPart: Sendable {
    public let name: String
    public let fileName: String
    public let mimeType: String
    public let data: Data
    public let fileURL: URL?

    public init(name: String, fileName: String, mimeType: String, data: Data) {
        self.name = name
        self.fileName = fileName
        self.mimeType = mimeType
        self.data = data
        self.fileURL = nil
    }

    public init(name: String, fileName: String, mimeType: String, fileURL: URL) {
        self.name = name
        self.fileName = fileName
        self.mimeType = mimeType
        self.data = Data()
        self.fileURL = fileURL
    }
}
