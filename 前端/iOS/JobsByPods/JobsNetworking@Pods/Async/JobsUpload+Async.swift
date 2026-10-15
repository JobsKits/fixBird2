//
//  JobsUpload+Async.swift
//  JobsNetworking
//
//  Created by Jobs on 2026年5月13日，星期三.
//

#if canImport(_Concurrency)
import Foundation

@available(iOS 13.0, *)
public extension JobsUploadCapable {
    func upload<T: Decodable>(
        _ request: JobsUploadRequest,
        as type: T.Type
    ) async throws -> T {
        let box = JobsAsyncResultBox<T>()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                guard box.install(continuation) else { return }
                let token = upload(request, as: type) { result in
                    box.complete(result)
                }
                box.install(token)
            }
        } onCancel: {
            box.cancel()
        }
    }
}
#endif
