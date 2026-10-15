//
//  JobsDefaultAgent+Download.swift
//  JobsNetworking
//
//  Created by Jobs on 2026年5月13日，星期三.
//

import Foundation
import Alamofire

extension JobsDefaultAgent: JobsDownloadCapable {
    @discardableResult
    public func download(
        _ request: JobsDownloadRequest,
        completion: @escaping (Result<URL, JobsError>) -> Void
    ) -> JobsRequestToken {
        let token = JobsRequestToken()
        let client = self.client
        token.setCancel { [weak token] in
            guard let token else { return }
            client.cancel(requestId: token.operationID)
            token.finish { completion(.failure(.cancelled)) }
        }
        let timeout = request.timeout ?? config.timeout
        guard ["http", "https"].contains(request.absoluteURL.scheme?.lowercased() ?? ""),
              request.absoluteURL.host != nil, request.destinationURL.isFileURL,
              timeout.isFinite, timeout > 0 else {
            token.finish { completion(.failure(.invalidRequest(reason: "Download requires HTTP URL, file destination and finite positive timeout"))) }
            return token
        }
        if let count = request.expectedByteCount, count < 0 {
            token.finish { completion(.failure(.invalidRequest(reason: "Expected byte count cannot be negative"))) }
            return token
        }
        if let hash = request.expectedSHA256,
           hash.count != 64 || hash.unicodeScalars.contains(where: { !CharacterSet(charactersIn: "0123456789abcdefABCDEF").contains($0) }) {
            token.finish { completion(.failure(.invalidRequest(reason: "Expected SHA256 must be 64 hexadecimal characters"))) }
            return token
        }
        var headers = request.headers
        let asRequest = JobsRequest(path: request.absoluteURL.absoluteString, method: .get,
            headers: request.headers, timeout: request.timeout, trace: request.trace)
        headers.merge(headerHook.headers(for: asRequest)) { _, new in new }
        headers[config.traceHeaderKeys.requestId] = request.trace.requestId
        headers[config.traceHeaderKeys.traceId] = request.trace.traceId
        headers[config.traceHeaderKeys.spanId] = request.trace.spanId
        var afHeaders: HTTPHeaders = [:]
        headers.forEach { afHeaders.add(name: $0.key, value: $0.value) }
        client.download(absoluteURL: request.absoluteURL, headers: afHeaders,
            destinationURL: request.destinationURL, trace: request.trace, timeout: timeout, token: token) { [self] result in
            switch result {
            case .success(let (temporaryURL, response)):
                DispatchQueue.global(qos: .utility).async { [self] in
                    defer {
                        if temporaryURL != request.destinationURL { try? FileManager.default.removeItem(at: temporaryURL) }
                    }
                    do {
                        guard (200...299).contains(response.statusCode) else {
                            throw JobsError.http(statusCode: response.statusCode, data: nil)
                        }
                        try JobsDownloadValidator.validate(temporaryURL, response: response, request: request, token: token)
                    } catch let error as JobsError {
                        token.finish { completion(token.isCancelled ? .failure(.cancelled) : .failure(error)) }
                        return
                    } catch {
                        token.finish { completion(token.isCancelled ? .failure(.cancelled) : .failure(.transport(underlying: error.localizedDescription))) }
                        return
                    }
                    // 校验结束后才争抢安装终态；取消胜出时绝不改动目标文件。
                    token.finish {
                        guard !token.isCancelled else {
                            completion(.failure(.cancelled))
                            return
                        }
                        do {
                            let manager = FileManager.default
                            if manager.fileExists(atPath: request.destinationURL.path) {
                                _ = try manager.replaceItemAt(request.destinationURL, withItemAt: temporaryURL)
                            } else {
                                try manager.moveItem(at: temporaryURL, to: request.destinationURL)
                            }
                            config.logger.log(.info, "Download success", meta: [
                                "requestId": request.trace.requestId,
                                "status": String(response.statusCode),
                                "file": request.destinationURL.lastPathComponent
                            ])
                            completion(.success(request.destinationURL))
                        } catch {
                            completion(.failure(.transport(underlying: "Installing download failed: \(error.localizedDescription)")))
                        }
                    }
                }
            case .failure(let error):
                token.finish { completion(.failure(error)) }
            }
        }
        return token
    }
}
