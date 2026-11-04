//
//  JobsDownload+Async.swift
//  JobsNetworking
//
//  Created by Jobs on 2026年5月13日，星期三.
//

#if canImport(_Concurrency)
import Foundation

@available(iOS 13.0, *)
public extension JobsDownloadCapable {
    func download(_ request: JobsDownloadRequest) async throws -> URL {
        let box = JobsAsyncResultBox<URL>()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                guard box.install(continuation) else { return }
                let token = download(request) { result in
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
