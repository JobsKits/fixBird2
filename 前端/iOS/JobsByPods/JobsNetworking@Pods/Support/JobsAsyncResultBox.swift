//
//  JobsAsyncResultBox.swift
//  JobsNetworking
//
//  Created by Jobs on 2026年10月5日，星期一.
//

#if canImport(_Concurrency)
    import Foundation

    /// token 安装、同步完成、任务提前取消都争抢同一个终态。
    @available(iOS 13.0, *)
    final class JobsAsyncResultBox<Value>: @unchecked Sendable {
        private let lock = NSLock()
        private var token: JobsRequestToken?
        private var continuation: CheckedContinuation<Value, Error>?
        private var cancelled = false
        private var finished = false

        func install(_ continuation: CheckedContinuation<Value, Error>) -> Bool {
            lock.lock()
            if cancelled {
                finished = true
                lock.unlock()
                continuation.resume(throwing: JobsError.cancelled)
                return false
            }
            let retiredContinuation = self.continuation
            self.continuation = continuation
            lock.unlock()
            withExtendedLifetime(retiredContinuation) {}
            return true
        }

        func install(_ token: JobsRequestToken) {
            lock.lock()
            let shouldCancel = cancelled
            let retiredToken = self.token
            if !finished {
                self.token = token
            }
            lock.unlock()
            withExtendedLifetime(retiredToken) {}
            if shouldCancel {
                token.cancel()
            }
        }

        func complete(_ result: Result<Value, JobsError>) {
            lock.lock()
            guard !finished else {
                lock.unlock()
                return
            }
            finished = true
            let continuation = self.continuation
            self.continuation = nil
            let retiredToken = token
            token = nil
            lock.unlock()
            withExtendedLifetime(retiredToken) {}
            switch result {
            case .success(let value):
                continuation?.resume(returning: value)
            case .failure(let error):
                continuation?.resume(throwing: error)
            }
        }

        func cancel() {
            lock.lock()
            guard !finished else {
                lock.unlock()
                return
            }
            cancelled = true
            let token = self.token
            self.token = nil
            let continuation = self.continuation
            if continuation != nil {
                finished = true
            }
            self.continuation = nil
            lock.unlock()
            continuation?.resume(throwing: JobsError.cancelled)
            token?.cancel()
        }
    }
#endif
