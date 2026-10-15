//
//  JobsAgent+PromiseKit.swift
//  JobsNetworking
//
//  Created by Jobs on 2026年5月13日，星期三.
//

#if canImport(PromiseKit)
import Foundation
import PromiseKit

public extension JobsAgent {
    func promise<T: Decodable>(_ request: JobsRequest, as type: T.Type) -> Promise<T> {
        Promise { seal in
            _ = send(request, as: type) { result in
                switch result {
                /// 处理 .success 分支
                case .success(let value):
                    seal.fulfill(value)
                /// 处理 .failure 分支
                case .failure(let error):
                    seal.reject(error)
                }
            }
        }
    }
}

public enum JobsPromises {
    public static func whenFulfilled<T>(_ promises: [Promise<T>]) -> Promise<[T]> {
        when(fulfilled: promises)
    }
}
#endif
