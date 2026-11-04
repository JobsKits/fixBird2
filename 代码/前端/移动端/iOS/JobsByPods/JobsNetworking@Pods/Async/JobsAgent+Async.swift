//
//  JobsAgent+Async.swift
//  JobsNetworking
//
//  Created by Jobs on 2026年5月13日，星期三.
//

#if canImport(_Concurrency)
import Foundation

@available(iOS 13.0, *)
public extension JobsAgent {
    func send<T: Decodable>(
        _ request: JobsRequest,
        as type: T.Type
    ) async throws -> T {
        let box = JobsAsyncResultBox<T>()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                guard box.install(continuation) else { return }
                let token = send(request, as: type) { result in
                    box.complete(result)
                }
                box.install(token)
            }
        } onCancel: {
            box.cancel()
        }
    }

    func observe<T: Decodable>(
        _ request: JobsRequest,
        as type: T.Type
    ) -> AsyncThrowingStream<(T, JobsResponseSource), Error> {
        AsyncThrowingStream { continuation in
            let token = observe(request, as: type, onEvent: { result in
                switch result {
                /// 处理 .success 分支
                case .success(let tuple):
                    continuation.yield(tuple)
                /// 处理 .failure 分支
                case .failure(let error):
                    continuation.finish(throwing: error)
                }
            }, completion: { result in
                if case .failure(let error) = result {
                    continuation.finish(throwing: error)
                } else {
                    continuation.finish()
                }
            })
            continuation.onTermination = { _ in
                token.cancel()
            }
        }
    }
}
#endif
