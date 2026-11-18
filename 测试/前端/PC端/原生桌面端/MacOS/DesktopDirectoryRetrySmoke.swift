//
//  DesktopDirectoryRetrySmoke.swift
//  RepairDesktopTests
//
//  Created by Jobs on 2026年11月18日，星期三.
//

import Foundation

@main struct DesktopDirectoryRetrySmoke {

    @MainActor static func main() async throws {
        let store = WBStore(transport: WBJobsTransport(), environment: WBEnvironment(endpoint: CommandLine.arguments[1], timeout: 3, editable: true))
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            store.login(username: "admin", password: "1234") {
                continuation.resume(with: $0)
            }
        }
        let directory = DesktopCustomerDirectory()
        directory.load(store: store)
        for _ in 0..<300 {
            if !directory.busy {
                break
            }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        precondition(directory.canManage && directory.error.isEmpty)
        let suffix = UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(10)
        let body: [String: Any] = ["operation": "customer", "name": "目录未知写夹具_" + suffix, "companyName": "夹具企业", "username": "retry_" + suffix, "password": "FixturePassword!", "confirmPassword": "FixturePassword!"]
        do {
            try await create(directory, store: store, body: body)
            fatalError("Proxy must discard the first successful response")
        } catch {}
        precondition(directory.pendingCreation != nil)
        var changed = body
        changed["username"] = "another_" + suffix
        do {
            try await create(directory, store: store, body: changed)
            fatalError("Unknown intent must freeze its original body")
        } catch {}
        precondition(NSDictionary(dictionary: directory.pendingCreation!).isEqual(to: body))
        try await create(directory, store: store, body: body)
        precondition(directory.pendingCreation == nil)
        precondition(directory.profiles.filter { $0.name == body["name"] as? String }.count == 1)
        print("PASS directory unknown write: committed-but-lost response, changed body refused, original-key retry returns one resource")
    }

    @MainActor static func create(_ directory: DesktopCustomerDirectory,
                                 store: WBStore,
                                 body: [String: Any]) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            directory.create(body, store: store) {
                continuation.resume(with: $0)
            }
        }
    }
}
