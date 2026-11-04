//
//  JobsDefaultAgent+Upload.swift
//  JobsNetworking
//
//  Created by Jobs on 2026年5月13日，星期三.
//

import Foundation
import Alamofire

extension JobsDefaultAgent: JobsUploadCapable {
    @discardableResult
    public func upload<T: Decodable>(
        _ request: JobsUploadRequest,
        as type: T.Type,
        completion: @escaping (Result<T, JobsError>) -> Void
    ) -> JobsRequestToken {
        let token = JobsRequestToken()
        let client = self.client
        token.setCancel { [weak token] in
            guard let token else { return }
            client.cancel(requestId: token.operationID)
            token.finish { completion(.failure(.cancelled)) }
        }
        let finish: (Result<T, JobsError>) -> Void = { result in
            token.finish { completion(token.isCancelled ? .failure(.cancelled) : result) }
        }
        let baseURL = effectiveBaseURL
        guard let url = URL(string: request.path, relativeTo: baseURL)?.absoluteURL,
              ["http", "https"].contains(url.scheme?.lowercased() ?? ""), url.host != nil else {
            finish(.failure(.invalidRequest(reason: "Upload URL must contain an http/https host")))
            return token
        }
        doUpload(request, url: url, as: type, token: token, attempt: 0, completion: finish)
        return token
    }

    private func doUpload<T: Decodable>(
        _ request: JobsUploadRequest,
        url: URL,
        as type: T.Type,
        token: JobsRequestToken,
        attempt: Int,
        completion: @escaping (Result<T, JobsError>) -> Void
    ) {
        guard !token.isCancelled, !token.isFinished else { return }
        let timeout = request.timeout ?? config.timeout
        guard timeout.isFinite, timeout > 0 else {
            completion(.failure(.invalidRequest(reason: "Timeout must be finite and positive")))
            return
        }
        for value in request.form.values {
            if let reason = value.validationError {
                completion(.failure(.invalidRequest(reason: reason)))
                return
            }
        }
        var headers = request.headers
        let fakeRequest = JobsRequest(path: request.path, method: request.method, headers: request.headers, timeout: request.timeout, trace: request.trace)
        headers.merge(headerHook.headers(for: fakeRequest)) { _, new in new }
        headers[config.traceHeaderKeys.requestId] = request.trace.requestId
        headers[config.traceHeaderKeys.traceId] = request.trace.traceId
        headers[config.traceHeaderKeys.spanId] = request.trace.spanId
        var afHeaders: HTTPHeaders = [:]
        headers.forEach { afHeaders.add(name: $0.key, value: $0.value) }
        let parts: [JobsMultipartPart]
        do {
            parts = try request.files.map { spec in
                switch spec {
                case let .file(fileURL, name, fileName, mimeType):
                    let values = try fileURL.resourceValues(forKeys: [.isRegularFileKey, .isReadableKey])
                    guard fileURL.isFileURL, values.isRegularFile == true, values.isReadable == true else {
                        throw JobsError.invalidRequest(reason: "Upload file must be a readable regular file: \(fileURL.lastPathComponent)")
                    }
                    let handle = try FileHandle(forReadingFrom: fileURL)
                    handle.closeFile()
                    return JobsMultipartPart(name: name, fileName: fileName, mimeType: mimeType, fileURL: fileURL)
                case let .data(data, name, fileName, mimeType):
                    return JobsMultipartPart(name: name, fileName: fileName, mimeType: mimeType, data: data)
                }
            }
        } catch let error as JobsError {
            completion(.failure(error))
            return
        } catch {
            completion(.failure(.invalidRequest(reason: "Upload file could not be opened: \(error.localizedDescription)")))
            return
        }
        client.uploadMultipart(
            url: url,
            method: request.method,
            headers: afHeaders,
            form: request.form,
            parts: parts,
            trace: request.trace,
            timeout: timeout,
            token: token
        ) { [self] result in
            guard !token.isCancelled, !token.isFinished else { return }
            switch result {
            /// 处理 .success 分支
            case .success(let (data, response)):
                do {
                    let fakeRequest = JobsRequest(path: request.path, method: request.method, headers: request.headers, timeout: request.timeout, trace: request.trace)
                    let decoded: T = try self.validateAndDecode(data: data, response: response, request: fakeRequest, as: type)
                    completion(.success(decoded))
                } catch let error as JobsError {
                    self.retryUploadIfNeeded(request, url: url, as: type, token: token, attempt: attempt, error: error, completion: completion)
                } catch {
                    self.retryUploadIfNeeded(request, url: url, as: type, token: token, attempt: attempt, error: .unknown(underlying: error.localizedDescription), completion: completion)
                }
            /// 处理 .failure 分支
            case .failure(let error):
                self.retryUploadIfNeeded(request, url: url, as: type, token: token, attempt: attempt, error: error, completion: completion)
            }
        }
    }

    private func retryUploadIfNeeded<T: Decodable>(
        _ request: JobsUploadRequest,
        url: URL,
        as type: T.Type,
        token: JobsRequestToken,
        attempt: Int,
        error: JobsError,
        completion: @escaping (Result<T, JobsError>) -> Void
    ) {
        guard !token.isCancelled, !token.isFinished else { return }
        let baseRequest = JobsRequest(path: request.path, method: request.method, headers: request.headers, timeout: request.timeout, trace: request.trace)
        let policy = request.retryPolicy ?? config.defaultRetryPolicy
        let decision = policy.decision(for: .init(request: baseRequest, attempt: attempt, error: error))
        guard decision.shouldRetry else {
            completion(.failure(error))
            return
        }
        token.scheduleRetry(after: decision.delay) { [self] in
            self.doUpload(request, url: url, as: type, token: token, attempt: attempt + 1, completion: completion)
        }
    }
}
