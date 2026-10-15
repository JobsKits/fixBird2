//
//  JobsDefaultAgent.swift
//  JobsNetworking
//
//  Created by Jobs on 2026年5月13日，星期三.
//

import Foundation
import Alamofire

public final class JobsDefaultAgent: JobsAgent, @unchecked Sendable {
    public let config: JobsRequestConfig
    public let headerHook: JobsHeaderHook
    let client: HTTPClient
    private let memoryCache: JobsCacheStore
    private let diskCache: JobsCacheStore

    public init(
        config: JobsRequestConfig,
        headerHook: JobsHeaderHook = EmptyHeaderHook(),
        memoryCache: JobsCacheStore = JobsMemoryCache(),
        diskCache: JobsCacheStore = JobsDiskCache()
    ) {
        self.config = config
        self.headerHook = headerHook
        self.memoryCache = memoryCache
        self.diskCache = diskCache
        self.client = AlamofireClient(config: config)
    }

    init(
        config: JobsRequestConfig,
        headerHook: JobsHeaderHook = EmptyHeaderHook(),
        memoryCache: JobsCacheStore = JobsMemoryCache(),
        diskCache: JobsCacheStore = JobsDiskCache(),
        client: HTTPClient
    ) {
        self.config = config
        self.headerHook = headerHook
        self.memoryCache = memoryCache
        self.diskCache = diskCache
        self.client = client
    }

    @discardableResult
    public func send<T: Decodable>(
        _ request: JobsRequest,
        as type: T.Type,
        completion: @escaping (Result<T, JobsError>) -> Void
    ) -> JobsRequestToken {
        observe(request, as: type, onEvent: { _ in }, completion: completion)
    }

    @discardableResult
    public func observe<T: Decodable>(
        _ request: JobsRequest,
        as type: T.Type,
        onEvent: @escaping (Result<(T, JobsResponseSource), JobsError>) -> Void,
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
        let event: (Result<(T, JobsResponseSource), JobsError>) -> Void = { value in
            guard !token.isCancelled, !token.isFinished else { return }
            onEvent(value)
        }
        perform(request, as: type, token: token, onEvent: event, completion: finish)
        return token
    }

    private func perform<T: Decodable>(
        _ request: JobsRequest,
        as type: T.Type,
        token: JobsRequestToken,
        onEvent: @escaping (Result<(T, JobsResponseSource), JobsError>) -> Void,
        completion: @escaping (Result<T, JobsError>) -> Void
    ) {
        do {
            let prepared = try prepareRequest(request)
            let cacheKey = makeCacheKey(for: request, prepared: prepared)
            let policy = request.cachePolicy
            switch policy {
            /// 合并处理 .disabled、.networkOnly 分支
            case .disabled, .networkOnly:
                fetchNetwork(request, prepared: prepared, cacheKey: cacheKey, as: type, token: token, attempt: 0, onEvent: onEvent, completion: completion)
            /// 处理 .cacheOnly 分支
            case .cacheOnly:
                if let cached = loadCache(key: cacheKey), let decoded: T = decodeCache(cached, request: request, url: prepared.url, as: type) {
                    onEvent(.success((decoded, .cache)))
                    completion(.success(decoded))
                } else {
                    completion(.failure(.cacheMiss))
                }
            /// 处理 .cacheElseLoad 分支
            case let .cacheElseLoad(ttl):
                if let cached = loadCache(key: cacheKey), let decoded: T = decodeCache(cached, request: request, url: prepared.url, as: type) {
                    onEvent(.success((decoded, .cache)))
                    completion(.success(decoded))
                } else {
                    fetchNetwork(request, prepared: prepared, cacheKey: cacheKey, cacheTTL: ttl, as: type, token: token, attempt: 0, onEvent: onEvent, completion: completion)
                }
            /// 处理 .staleWhileRevalidate 分支
            case let .staleWhileRevalidate(ttl):
                if let cached = loadCache(key: cacheKey, allowExpired: true), let decoded: T = decodeCache(cached, request: request, url: prepared.url, as: type) {
                    onEvent(.success((decoded, .cache)))
                }
                fetchNetwork(request, prepared: prepared, cacheKey: cacheKey, cacheTTL: ttl, as: type, token: token, attempt: 0, onEvent: onEvent, completion: completion)
            }
        } catch let error as JobsError {
            completion(.failure(error))
        } catch {
            completion(.failure(.unknown(underlying: error.localizedDescription)))
        }
    }

    private func fetchNetwork<T: Decodable>(
        _ request: JobsRequest,
        prepared: JobsPreparedRequest,
        cacheKey: JobsCacheKey,
        cacheTTL: TimeInterval? = nil,
        as type: T.Type,
        token: JobsRequestToken,
        attempt: Int,
        onEvent: @escaping (Result<(T, JobsResponseSource), JobsError>) -> Void,
        completion: @escaping (Result<T, JobsError>) -> Void
    ) {
        guard !token.isCancelled, !token.isFinished else { return }
        logStart(request, attempt: attempt)
        config.observer.willSend(request)
        client.perform(prepared, token: token) { [self] result in
            if token.isCancelled {
                completion(.failure(.cancelled))
                return
            }
            switch result {
            /// 处理 .success 分支
            case .success(let (data, response)):
                let event = JobsResponseEvent(source: .network, request: request, response: response, data: data)
                self.config.observer.didReceive(event)
                do {
                    let decoded: T = try self.validateAndDecode(data: data, response: response, request: request, as: type)
                    if let cacheTTL {
                        self.storeCache(data: data, response: response, key: cacheKey, ttl: cacheTTL)
                    }
                    self.logSuccess(request, response: response, data: data, source: .network)
                    onEvent(.success((decoded, .network)))
                    completion(.success(decoded))
                } catch let jobsError as JobsError {
                    self.handle(error: jobsError, request: request, prepared: prepared, cacheKey: cacheKey, cacheTTL: cacheTTL, as: type, token: token, attempt: attempt, onEvent: onEvent, completion: completion)
                } catch {
                    let wrapped = JobsError.unknown(underlying: error.localizedDescription)
                    self.handle(error: wrapped, request: request, prepared: prepared, cacheKey: cacheKey, cacheTTL: cacheTTL, as: type, token: token, attempt: attempt, onEvent: onEvent, completion: completion)
                }
            /// 处理 .failure 分支
            case .failure(let error):
                self.handle(error: error, request: request, prepared: prepared, cacheKey: cacheKey, cacheTTL: cacheTTL, as: type, token: token, attempt: attempt, onEvent: onEvent, completion: completion)
            }
        }
    }

    private func handle<T: Decodable>(
        error: JobsError,
        request: JobsRequest,
        prepared: JobsPreparedRequest,
        cacheKey: JobsCacheKey,
        cacheTTL: TimeInterval?,
        as type: T.Type,
        token: JobsRequestToken,
        attempt: Int,
        onEvent: @escaping (Result<(T, JobsResponseSource), JobsError>) -> Void,
        completion: @escaping (Result<T, JobsError>) -> Void
    ) {
        guard !token.isCancelled, !token.isFinished else { return }
        let policy = request.retryPolicy ?? config.defaultRetryPolicy
        let context = JobsRetryContext(request: request, attempt: attempt, error: error)
        let decision = policy.decision(for: context)
        if decision.shouldRetry {
            config.logger.log(.warn, "Retrying request", meta: [
                "requestId": request.trace.requestId,
                "attempt": String(attempt + 1),
                "delay": String(format: "%.3f", decision.delay),
                "error": error.localizedDescription
            ])
            token.scheduleRetry(after: decision.delay) { [self] in
                self.fetchNetwork(request, prepared: prepared, cacheKey: cacheKey, cacheTTL: cacheTTL, as: type, token: token, attempt: attempt + 1, onEvent: onEvent, completion: completion)
            }
            return
        }
        config.observer.didFail(request: request, error: error)
        config.logger.log(.error, "Request failed", meta: [
            "requestId": request.trace.requestId,
            "traceId": request.trace.traceId,
            "error": error.localizedDescription
        ])
        onEvent(.failure(error))
        completion(.failure(error))
    }

    private func prepareRequest(_ request: JobsRequest) throws -> JobsPreparedRequest {
        let baseURL = effectiveBaseURL
        guard var absoluteURL = URL(string: request.path, relativeTo: baseURL)?.absoluteURL,
              ["http", "https"].contains(absoluteURL.scheme?.lowercased() ?? ""), absoluteURL.host != nil else {
            throw JobsError.invalidRequest(reason: "Request URL must contain an http/https host")
        }
        let timeout = request.timeout ?? config.timeout
        guard timeout.isFinite, timeout > 0 else { throw JobsError.invalidRequest(reason: "Timeout must be finite and positive") }
        for value in Array(request.query?.values ?? [:].values) + Array(request.body?.values ?? [:].values) {
            if let reason = value.validationError { throw JobsError.invalidRequest(reason: reason) }
        }
        let rule = JobsEncodingRule.encoding(for: request)
        try JobsEncodingRule.validate(request, encoding: rule)
        if case .urlQuery = rule { } else if let query = request.query, !query.isEmpty {
            var urlRequest = URLRequest(url: absoluteURL)
            urlRequest = try URLEncoding(destination: .queryString).encode(urlRequest, with: query.normalizedJSONObject())
            guard let encodedURL = urlRequest.url else { throw JobsError.invalidRequest(reason: "Query URL encoding failed") }
            absoluteURL = encodedURL
        }
        var headers: [String: String] = ["Accept": "application/json"]
        headers.merge(request.headers) { _, new in new }
        headers.merge(headerHook.headers(for: request)) { _, new in new }
        headers[config.traceHeaderKeys.requestId] = request.trace.requestId
        headers[config.traceHeaderKeys.traceId] = request.trace.traceId
        headers[config.traceHeaderKeys.spanId] = request.trace.spanId
        var afHeaders: HTTPHeaders = [:]
        headers.forEach { afHeaders.add(name: $0.key, value: $0.value) }
        switch rule {
        /// 处理 .urlQuery 分支
        case .urlQuery:
            return JobsPreparedRequest(
                url: absoluteURL,
                method: request.method,
                parameters: request.query?.normalizedJSONObject(),
                encoding: URLEncoding(destination: .queryString),
                headers: afHeaders,
                timeout: request.timeout ?? config.timeout,
                rawBody: nil,
                trace: request.trace
            )
        /// 处理 .jsonBody 分支
        case .jsonBody:
            afHeaders.add(name: "Content-Type", value: "application/json")
            return JobsPreparedRequest(
                url: absoluteURL,
                method: request.method,
                parameters: request.body?.normalizedJSONObject(),
                encoding: JSONEncoding.default,
                headers: afHeaders,
                timeout: request.timeout ?? config.timeout,
                rawBody: nil,
                trace: request.trace
            )
        /// 处理 .formURLEncoded 分支
        case .formURLEncoded:
            afHeaders.add(name: "Content-Type", value: "application/x-www-form-urlencoded; charset=utf-8")
            return JobsPreparedRequest(
                url: absoluteURL,
                method: request.method,
                parameters: request.body?.normalizedJSONObject(),
                encoding: URLEncoding(destination: .httpBody),
                headers: afHeaders,
                timeout: request.timeout ?? config.timeout,
                rawBody: nil,
                trace: request.trace
            )
        /// 处理 .rawData 分支
        case .rawData(let data):
            return JobsPreparedRequest(
                url: absoluteURL,
                method: request.method,
                parameters: nil,
                encoding: nil,
                headers: afHeaders,
                timeout: request.timeout ?? config.timeout,
                rawBody: data,
                trace: request.trace
            )
        /// 处理 .multipart 分支
        case .multipart:
            throw JobsError.invalidRequest(reason: "Use upload(_:as:completion:) for multipart requests")
        }
    }

    private func makeCacheKey(for request: JobsRequest, prepared: JobsPreparedRequest) -> JobsCacheKey {
        JobsCacheKey.make(
            method: request.method,
            url: prepared.url,
            query: request.query,
            body: request.body,
            version: config.version,
            userScope: config.userScope,
            rawBody: prepared.rawBody,
            encoding: String(describing: JobsEncodingRule.encoding(for: request)),
            headers: prepared.headers.dictionary.filter { !Set([config.traceHeaderKeys.requestId, config.traceHeaderKeys.traceId, config.traceHeaderKeys.spanId]).contains($0.key) }
        )
    }

    private func loadCache(key: JobsCacheKey, allowExpired: Bool = false) -> JobsCachedValue? {
        memoryCache.get(key: key, allowExpired: allowExpired) ?? diskCache.get(key: key, allowExpired: allowExpired)
    }

    private func decodeCache<T: Decodable>(_ cached: JobsCachedValue, request: JobsRequest, url: URL, as type: T.Type) -> T? {
        let headers = cached.responseHeaders
        guard let response = HTTPURLResponse(
            url: url,
            statusCode: 200,
            httpVersion: nil,
            headerFields: headers
        ) else {
            return nil
        }
        do {
            let decoded: T = try validateAndDecode(data: cached.data, response: response, request: request, as: type)
            config.observer.didReceive(.init(source: .cache, request: request, response: response, data: cached.data))
            config.logger.log(.debug, "Cache hit", meta: [
                "requestId": request.trace.requestId,
                "traceId": request.trace.traceId
            ])
            return decoded
        } catch {
            return nil
        }
    }

    var effectiveBaseURL: URL {
        #if DEBUG
        return JobsNetworkingDebugEnvironment.shared.resolvedBaseURL(fallback: config.baseURL)
        #else
        return config.baseURL
        #endif
    }

    private func storeCache(data: Data, response: HTTPURLResponse, key: JobsCacheKey, ttl: TimeInterval) {
        guard ttl.isFinite, ttl > 0 else { return }
        let expiry = Date().addingTimeInterval(min(ttl, 31_536_000))
        let headers = response.allHeaderFields.reduce(into: [String: String]()) { partialResult, item in
            if let key = item.key as? String, let value = item.value as? String {
                partialResult[key] = value
            }
        }
        let value = JobsCachedValue(data: data, expiry: expiry, responseHeaders: headers)
        memoryCache.set(key: key, value: value)
        diskCache.set(key: key, value: value)
    }

    func validateAndDecode<T: Decodable>(
        data: Data,
        response: HTTPURLResponse,
        request: JobsRequest,
        as type: T.Type
    ) throws -> T {
        guard (200...299).contains(response.statusCode) else {
            throw JobsError.http(statusCode: response.statusCode, data: data)
        }
        if request.allowsEmptyResponse, data.isEmpty {
            if T.self == EmptyResponse.self, let value = EmptyResponse() as? T {
                return value
            }
        }
        switch config.envelopeStrategy {
        /// 处理 .none 分支
        case .none:
            return try decodePlain(data: data, as: type)
        /// 处理 .standard 分支
        case let .standard(successCodes):
            return try decodeWithEnvelope(data: data, as: type, successCodes: successCodes)
        }
    }

    private func decodePlain<T: Decodable>(data: Data, as type: T.Type) throws -> T {
        if T.self == Data.self, let raw = data as? T {
            return raw
        }
        do {
            return try config.decoder.decode(T.self, from: data)
        } catch {
            throw JobsError.decode(underlying: error.localizedDescription, data: data)
        }
    }

    private func decodeWithEnvelope<T: Decodable>(data: Data, as type: T.Type, successCodes: Set<Int>) throws -> T {
        if T.self == Data.self, let raw = data as? T {
            return raw
        }
        do {
            let envelope = try config.decoder.decode(JobsEnvelope<T>.self, from: data)
            guard successCodes.contains(envelope.code) else {
                throw JobsError.business(code: envelope.code, message: envelope.message ?? "Unknown business error", data: data)
            }
            guard let payload = envelope.data else {
                throw JobsError.emptyResponse
            }
            return payload
        } catch let error as JobsError {
            throw error
        } catch {
            throw JobsError.decode(underlying: error.localizedDescription, data: data)
        }
    }

    private func logStart(_ request: JobsRequest, attempt: Int) {
        config.logger.log(.info, "Send request", meta: [
            "requestId": request.trace.requestId,
            "traceId": request.trace.traceId,
            "spanId": request.trace.spanId,
            "method": request.method.rawValue,
            "path": URLComponents(string: request.path)?.path ?? "<invalid>",
            "attempt": String(attempt)
        ])
    }

    private func logSuccess(_ request: JobsRequest, response: HTTPURLResponse, data: Data, source: JobsResponseSource) {
        config.logger.log(.debug, "Request success", meta: [
            "requestId": request.trace.requestId,
            "status": String(response.statusCode),
            "source": source.rawValue,
            "bytes": String(data.count)
        ])
    }
}

public typealias DefaultJobsAgent = JobsDefaultAgent

public struct EmptyResponse: Codable, Sendable {
    public init() {}
}
