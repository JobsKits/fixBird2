//
//  Usage.swift
//  JobsNetworking
//
//  Created by Jobs on 2026年5月13日，星期三.
//

import Foundation

struct User: Codable, Sendable {
    let id: Int
    let name: String
}

@available(iOS 13.0, *)
func example(agent: JobsDefaultAgent) async throws {
    let profile = JobsRequest(
        path: "/profile",
        method: .get,
        cachePolicy: .staleWhileRevalidate(ttl: 120)
    )

    for try await (user, source) in agent.observe(profile, as: User.self) {
        print(source, user)
    }

    let finalState = try await JobsWorkflow.chain(initial: 1, steps: [
        { state in state + 1 },
        { state in state * 10 }
    ])
    print(finalState)
}
