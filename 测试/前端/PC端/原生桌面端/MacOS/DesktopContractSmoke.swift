//
//  DesktopContractSmoke.swift
//  RepairDesktopTests
//
//  Created by Jobs on 2026年11月18日，星期三.
//

import Foundation

@main
struct DesktopContractSmoke {
    @MainActor static func main() async throws {
        let endpoint = CommandLine.arguments[1]
        let store = WBStore(transport: WBJobsTransport(), environment: WBEnvironment(endpoint: endpoint, timeout: 2.5, editable: true))
        try await login(store, name: "admin", password: "1234")
        precondition(store.actor?.role == "admin" && !store.isDemo)
        precondition(!store.orders.isEmpty)
        let first = try await detail(store, id: store.orders[0].id)
        precondition(!first.isSummary)
        let input = WBOrderInput().byType("mail").byCustomer(first.customer).byCustomerId(first.customerId).byCompanyId(first.companyId).byDevice("原生桌面合成验收设备").byDescription("本地隔离服务：客户端真实传输合同验收")
        let created: WBOrder = try await withCheckedThrowingContinuation { continuation in
            store.createOrder(input: input) { continuation.resume(with: $0) }
        }
        precondition(created.device == input.device && !created.id.hasPrefix("ios-demo-"))
        let changed: WBOrder = try await withCheckedThrowingContinuation { continuation in
            store.perform(order: created, action: "remark", payload: ["remark": "Mac原生真实HTTP验收"]) { continuation.resume(with: $0) }
        }
        precondition(changed.version > created.version && changed.remark == "Mac原生真实HTTP验收")
        do {
            try await login(store, name: "admin", password: "invalid-password")
            fatalError("401 must not enter demo")
        } catch {
            precondition(store.actor == nil)
        }
        let offline = WBStore(transport: WBJobsTransport(), environment: WBEnvironment(endpoint: "http://127.0.0.1:1", timeout: 0.5, editable: true))
        try await login(offline, name: "admin", password: "Demo-Repair-2026!")
        precondition(offline.isDemo && offline.orders.allSatisfy { $0.id.hasPrefix("ios-demo-") })
        print("PASS: Mac native HTTP login/full detail/create/action/version/401 isolation/offline synthetic fallback")
    }

    @MainActor static func login(_ store: WBStore, name: String, password: String) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            store.login(username: name, password: password) { continuation.resume(with: $0) }
        }
    }

    @MainActor static func detail(_ store: WBStore, id: String) async throws -> WBOrder {
        try await withCheckedThrowingContinuation { continuation in
            store.loadOrder(id: id) { continuation.resume(with: $0) }
        }
    }
}
