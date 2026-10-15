//
//  HTTPClient.swift
//  JobsNetworking
//
//  Created by Jobs on 2026年5月13日，星期三.
//

import Foundation
import Alamofire

protocol HTTPClient: Sendable {
    func perform(
        _ request: JobsPreparedRequest,
        token: JobsRequestToken,
        completion: @escaping (Result<(Data, HTTPURLResponse), JobsError>) -> Void
    )

    func download(
        absoluteURL: URL,
        headers: HTTPHeaders,
        destinationURL: URL,
        trace: JobsTrace,
        timeout: TimeInterval?,
        token: JobsRequestToken,
        completion: @escaping (Result<(URL, HTTPURLResponse), JobsError>) -> Void
    )

    func uploadMultipart(
        url: URL,
        method: HTTPMethod,
        headers: HTTPHeaders,
        form: [String: JobsValue],
        parts: [JobsMultipartPart],
        trace: JobsTrace,
        timeout: TimeInterval?,
        token: JobsRequestToken,
        completion: @escaping (Result<(Data, HTTPURLResponse), JobsError>) -> Void
    )

    func cancel(requestId: String)
}

final class AlamofireClient: HTTPClient, @unchecked Sendable {
    private let session: Session
    private let lock = NSLock()
    private var requests: [String: Request] = [:]

    init(config: JobsRequestConfig) {
        let sessionConfiguration = URLSessionConfiguration.default
        sessionConfiguration.timeoutIntervalForRequest = config.timeout
        if let sslPinning = config.sslPinning, !sslPinning.pinnedHosts.isEmpty {
            var evaluators: [String: ServerTrustEvaluating] = [:]
            for host in sslPinning.pinnedHosts {
                switch sslPinning.mode {
                /// 处理 .certificates 分支
                case .certificates:
                    evaluators[host] = PinnedCertificatesTrustEvaluator(
                        acceptSelfSignedCertificates: sslPinning.allowsSelfSigned,
                        performDefaultValidation: true,
                        validateHost: sslPinning.validatesHost
                    )
                /// 处理 .publicKeys 分支
                case .publicKeys:
                    evaluators[host] = PublicKeysTrustEvaluator(
                        performDefaultValidation: true,
                        validateHost: sslPinning.validatesHost
                    )
                }
            }
            session = Session(
                configuration: sessionConfiguration,
                serverTrustManager: ServerTrustManager(evaluators: evaluators)
            )
        } else {
            session = Session(configuration: sessionConfiguration)
        }
    }

    func perform(
        _ request: JobsPreparedRequest,
        token: JobsRequestToken,
        completion: @escaping (Result<(Data, HTTPURLResponse), JobsError>) -> Void
    ) {
        guard !token.isCancelled, !token.isFinished else {
            completion(.failure(.cancelled))
            return
        }
        let method = Alamofire.HTTPMethod(rawValue: request.method.rawValue)
        let afRequest: DataRequest
        if let rawBody = request.rawBody {
            var urlRequest = URLRequest(url: request.url)
            urlRequest.httpMethod = request.method.rawValue
            urlRequest.timeoutInterval = request.timeout ?? 30
            urlRequest.httpBody = rawBody
            request.headers.forEach { header in
                urlRequest.setValue(header.value, forHTTPHeaderField: header.name)
            }
            afRequest = session.request(urlRequest)
        } else {
            afRequest = session.request(
                request.url,
                method: method,
                parameters: request.parameters,
                encoding: request.encoding ?? URLEncoding.default,
                headers: request.headers,
                requestModifier: { urlRequest in
                    if let timeout = request.timeout {
                        urlRequest.timeoutInterval = timeout
                    }
                }
            )
        }
        remember(afRequest, token: token)
        afRequest.responseData { [weak self, weak afRequest] response in
            self?.forget(id: token.operationID, request: afRequest)
            switch response.result {
            /// 处理 .success 分支
            case .success(let data):
                guard let http = response.response else {
                    completion(.failure(.emptyResponse))
                    return
                }
                completion(.success((data, http)))
            /// 处理 .failure 分支
            case .failure(let error):
                if error.isExplicitlyCancelledError {
                    completion(.failure(.cancelled))
                } else {
                    completion(.failure(.transport(underlying: error.localizedDescription)))
                }
            }
        }
    }

    func download(
        absoluteURL: URL,
        headers: HTTPHeaders,
        destinationURL: URL,
        trace: JobsTrace,
        timeout: TimeInterval?,
        token: JobsRequestToken,
        completion: @escaping (Result<(URL, HTTPURLResponse), JobsError>) -> Void
    ) {
        guard !token.isCancelled, !token.isFinished else {
            completion(.failure(.cancelled))
            return
        }
        let temporaryURL = destinationURL.deletingLastPathComponent()
            .appendingPathComponent(".jobs-download-\(UUID().uuidString).tmp")
        let destination: DownloadRequest.Destination = { _, _ in
            (temporaryURL, [.createIntermediateDirectories])
        }
        let request = session.download(
            absoluteURL,
            headers: headers,
            requestModifier: { urlRequest in
                if let timeout {
                    urlRequest.timeoutInterval = timeout
                }
            },
            to: destination
        )
        remember(request, token: token)
        request.response { [weak self, weak request] response in
            self?.forget(id: token.operationID, request: request)
            switch response.result {
            /// 处理 .success 分支
            case .success:
                guard let url = response.fileURL, let http = response.response else {
                    completion(.failure(.emptyResponse))
                    return
                }
                guard (200...299).contains(http.statusCode) else {
                    try? FileManager.default.removeItem(at: url)
                    completion(.failure(.http(statusCode: http.statusCode, data: nil)))
                    return
                }
                completion(.success((url, http)))
            /// 处理 .failure 分支
            case .failure(let error):
                try? FileManager.default.removeItem(at: temporaryURL)
                if error.isExplicitlyCancelledError {
                    completion(.failure(.cancelled))
                } else {
                    completion(.failure(.transport(underlying: error.localizedDescription)))
                }
            }
        }
    }

    func uploadMultipart(
        url: URL,
        method: HTTPMethod,
        headers: HTTPHeaders,
        form: [String: JobsValue],
        parts: [JobsMultipartPart],
        trace: JobsTrace,
        timeout: TimeInterval?,
        token: JobsRequestToken,
        completion: @escaping (Result<(Data, HTTPURLResponse), JobsError>) -> Void
    ) {
        guard !token.isCancelled, !token.isFinished else {
            completion(.failure(.cancelled))
            return
        }
        let request = session.upload(
            multipartFormData: { multipart in
                for (key, value) in form {
                    let normalized = JobsValueNormalizer.normalize(value.raw)
                    let data: Data
                    if let string = normalized as? String {
                        data = Data(string.utf8)
                    } else if let encoded = try? JSONSerialization.data(withJSONObject: normalized, options: [.fragmentsAllowed, .sortedKeys]) {
                        data = encoded
                    } else {
                        data = Data()
                    }
                    multipart.append(data, withName: key)
                }
                for part in parts {
                    if let fileURL = part.fileURL {
                        multipart.append(fileURL, withName: part.name, fileName: part.fileName, mimeType: part.mimeType)
                    } else {
                        multipart.append(part.data, withName: part.name, fileName: part.fileName, mimeType: part.mimeType)
                    }
                }
            },
            to: url,
            method: Alamofire.HTTPMethod(rawValue: method.rawValue),
            headers: headers,
            requestModifier: { urlRequest in
                if let timeout {
                    urlRequest.timeoutInterval = timeout
                }
            }
        )
        remember(request, token: token)
        request.responseData { [weak self, weak request] response in
            self?.forget(id: token.operationID, request: request)
            switch response.result {
            /// 处理 .success 分支
            case .success(let data):
                guard let http = response.response else {
                    completion(.failure(.emptyResponse))
                    return
                }
                completion(.success((data, http)))
            /// 处理 .failure 分支
            case .failure(let error):
                if error.isExplicitlyCancelledError {
                    completion(.failure(.cancelled))
                } else {
                    completion(.failure(.transport(underlying: error.localizedDescription)))
                }
            }
        }
    }

    func cancel(requestId: String) {
        lock.lock()
        let request = requests[requestId]
        lock.unlock()
        request?.cancel()
    }

    private func remember(_ request: Request, token: JobsRequestToken) {
        lock.lock()
        requests[token.operationID] = request
        lock.unlock()
        // 取消可以先于 transport 注册；注册后再核对，避免漏掉底层取消。
        if token.isCancelled || token.isFinished { request.cancel() }
    }

    private func forget(id: String, request: Request?) {
        lock.lock()
        if requests[id] === request { requests[id] = nil }
        lock.unlock()
    }
}
