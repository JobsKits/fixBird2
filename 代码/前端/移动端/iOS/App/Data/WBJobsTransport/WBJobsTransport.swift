//
//  WBJobsTransport.swift
//  RepairWorkbench
//
//  Created by Jobs on 2026年10月15日，星期四.
//

import Foundation

#if canImport(JobsNetworking)
    import JobsNetworking
#endif

@MainActor
final class WBJobsTransport: WBTransport {
    func send(_ request: WBRequest, completion: @escaping (Result<WBJSON, WBError>) -> Void) {
        #if canImport(JobsNetworking)
            guard let url = URL(string: request.endpoint), !request.endpoint.isEmpty else {
                completion(.failure(.unavailable("服务地址尚未配置")))
                return
            }
            let noRetry = JobsRetryPolicy(maxRetries: 0, initialDelay: 0, multiplier: 1)
            let config = JobsRequestConfig(
                baseURL: url,
                timeout: request.timeout,
                version: "",
                userScope: "RepairWorkbench",
                defaultRetryPolicy: noRetry,
                logger: JobsLogger(isEnabled: false),
                envelopeStrategy: .none
            )
            let agent = JobsDefaultAgent(config: config)
            var headers = request.headers
            let encoding: JobsParameterEncoding?
            if let body = request.body {
                do {
                    // Go 对请求原文计算幂等摘要，重试必须保持同一 JSON 字节序列。
                    encoding = .rawData(try WBFoundation.data(body))
                    headers["Content-Type"] = "application/json"
                } catch {
                    completion(.failure(.unavailable("请求内容无法编码为有效 JSON")))
                    return
                }
            } else {
                encoding = nil
            }
            let networkRequest = JobsRequest(
                path: "/api/v38" + request.path,
                method: request.method == "POST" ? .post : .get,
                headers: headers,
                timeout: request.timeout,
                encoding: encoding,
                cachePolicy: .disabled,
                retryPolicy: noRetry
            )
            agent.send(networkRequest, as: WBJSON.self) { result in
                let converted: Result<WBJSON, WBError>
                switch result {
                /// 错误状态保留服务端拒绝语义，禁止转成保存成功。
                case .success(let value):
                    converted = .success(value)
                /// 失败保留原错误语义，不能视作成功。
                case .failure(let error):
                    switch error {
                    /// 按当前枚举分支转换已验证的数据。
                    case .http(let status, let data), .server(let status, let data):
                        let raw = data.flatMap {
                            try? WBFoundation.decode($0).object
                        }
                        converted = .failure(
                            .server(
                                status,
                                raw?["error"]?.string ?? "http_error",
                                raw?["message"]?.string ?? "服务返回 HTTP \(status)"
                            )
                        )
                    /// 按当前枚举分支转换已验证的数据。
                    case .decode:
                        converted = .failure(.invalidResponse("JSON 无法解析"))
                    /// 按当前枚举分支转换已验证的数据。
                    case .invalidRequest(let reason):
                        converted = .failure(.unavailable(reason))
                    /// 其余分支保留明确的保守处理。
                    default:
                        converted = .failure(.transport("网络请求未完成，请检查服务连接"))
                    }
                }
                DispatchQueue.main.async {
                    completion(converted)
                }
            }
        #else
            completion(.failure(.unavailable("JobsNetworking 尚未挂载，当前仅提供独立演示")))
        #endif
    }
}
