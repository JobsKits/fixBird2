//
//  JobsWorkflow.swift
//  JobsNetworking
//
//  Created by Jobs on 2026年5月13日，星期三.
//

#if canImport(_Concurrency)
import Foundation

@available(iOS 13.0, *)
public enum JobsBatchFailurePolicy: Sendable {
    case failFast
    case collect
}

@available(iOS 13.0, *)
public struct JobsBatchResult<Value: Sendable>: Sendable {
    public let values: [Value]
    public let errors: [JobsError]

    public init(values: [Value], errors: [JobsError]) {
        self.values = values
        self.errors = errors
    }
}

@available(iOS 13.0, *)
public enum JobsWorkflow {
    public static func concurrent<Value: Sendable>(
        _ tasks: [@Sendable () async throws -> Value],
        failurePolicy: JobsBatchFailurePolicy = .failFast
    ) async throws -> JobsBatchResult<Value> {
        switch failurePolicy {
        /// 处理 .failFast 分支
        case .failFast:
            let values = try await withThrowingTaskGroup(of: (Int, Value).self) { group in
                for (index, task) in tasks.enumerated() {
                    group.addTask { (index, try await task()) }
                }
                var output = Array<Value?>(repeating: nil, count: tasks.count)
                for try await (index, value) in group {
                    output[index] = value
                }
                return output.compactMap { $0 }
            }
                return .init(values: values, errors: [])
        /// 处理 .collect 分支
        case .collect:
            return await withTaskGroup(of: Result<(Int, Value), JobsError>.self) { group in
                for (index, task) in tasks.enumerated() {
                    group.addTask {
                        do {
                            return .success((index, try await task()))
                        } catch let error as JobsError {
                            return .failure(error)
                        } catch {
                            return .failure(.unknown(underlying: error.localizedDescription))
                        }
                    }
                }
                var values = Array<Value?>(repeating: nil, count: tasks.count)
                var errors: [JobsError] = []
                for await result in group {
                    switch result {
                    /// 处理 .success 分支
                    case .success(let pair):
                        values[pair.0] = pair.1
                    /// 处理 .failure 分支
                    case .failure(let error):
                        errors.append(error)
                    }
                }
                return .init(values: values.compactMap { $0 }, errors: errors)
            }
        }
    }

    public static func chain<State: Sendable>(
        initial: State,
        steps: [@Sendable (State) async throws -> State]
    ) async throws -> State {
        var state = initial
        for step in steps {
            try Task.checkCancellation()
            state = try await step(state)
        }
                return state
    }

    public static func chain<State: Sendable>(
        seed: State,
        _ steps: [@Sendable (State) async throws -> State]
    ) async throws -> State {
        try await chain(initial: seed, steps: steps)
    }
}
#endif
