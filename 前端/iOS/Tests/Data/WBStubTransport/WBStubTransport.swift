//
//  WBStubTransport.swift
//  RepairWorkbenchTests
//
//  Created by Jobs on 2026年10月15日，星期四.
//

import Foundation

#if canImport(RepairWorkbench)
    @testable import RepairWorkbench
#endif

@MainActor
final class WBStubTransport: WBTransport {
    struct Pending {
        let request: WBRequest
        let completion: (Result<WBJSON, WBError>) -> Void
    }

    var requests: [WBRequest] = []
    var pending: [Pending] = []

    func send(_ request: WBRequest, completion: @escaping (Result<WBJSON, WBError>) -> Void) {
        requests.append(request)
        pending.append(Pending(request: request, completion: completion))
    }

    @discardableResult
    func reply(_ path: String, _ result: Result<WBJSON, WBError>, last: Bool = false) throws -> WBRequest {
        let index =
            last
            ? pending.lastIndex(where: {
                $0.request.path == path
            })
            : pending.firstIndex(where: {
                $0.request.path == path
            })
        guard let index else {
            throw WBError.invalidResponse("测试未找到等待请求：" + path)
        }
        let value = pending.remove(at: index)
        value.completion(result)
        return value.request
    }
}
