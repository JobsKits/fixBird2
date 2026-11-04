//
//  WBFixture.swift
//  RepairWorkbenchTests
//
//  Created by Jobs on 2026年10月15日，星期四.
//

import Foundation

#if canImport(RepairWorkbench)
    @testable import RepairWorkbench
#endif

@MainActor
enum WBFixture {
    static let environment = WBEnvironment(endpoint: "http://127.0.0.1:18099", timeout: 0.5, editable: true)

    static func actor(_ role: String = "admin") -> WBJSON {
        .object([
            "id": .string("user-" + role),
            "username": .string(role),
            "name": .string("测试" + role),
            "role": .string(role),
            "companyId": .string("company-a"),
            "status": .string("active"),
            "authVersion": .integer(1),
        ])
    }

    static func login(_ role: String = "admin") -> WBJSON {
        .object(["token": .string("test-token-" + role), "actor": actor(role)])
    }

    static func order(_ id: String = "wo-real-1", version: Int = 1) -> WBJSON {
        var raw = WBDemoState(username: "admin").orders[0].raw
        raw["id"] = .string(id)
        raw["version"] = .integer(Int64(version))
        raw["customerId"] = .string("user-customer")
        raw["companyId"] = .string("company-a")
        raw["ownerId"] = .string("user-dispatcher")
        raw["assigneeId"] = .string("user-engineer")
        raw["allowedActions"] = .array([.string("remark"), .string("rework")])
        return .object(raw)
    }

    static func page(_ orders: [WBJSON], total: Int? = nil) -> WBJSON {
        let count = total ?? orders.count
        return .object([
            "items": .array(orders),
            "total": .integer(Int64(count)),
            "page": .integer(1),
            "pageSize": .integer(30),
            "totalPages": .integer(Int64((count + 29) / 30)),
        ])
    }

    static func bootstrap(_ role: String = "admin", orders: [WBJSON]? = nil) -> WBJSON {
        let orders = orders ?? [order()]
        let pageRaw = page(orders).object ?? [:]
        return .object([
            "actor": actor(role),
            "orders": .array(orders),
            "orderPage": .object(pageRaw),
            "metrics": .object([
                "openCount": .integer(Int64(orders.count)),
                "settlingCount": .integer(0),
                "remainingCents": .integer(0),
                "readyCount": .integer(0),
                "tasksCount": .integer(0),
                "blockedCount": .integer(0),
            ]),
            "parts": .array([]),
            "loans": .array([]),
            "settings": .object([
                "companyAddress": .string("测试地址"),
                "companyReceiver": .string("测试联系人"),
                "companyPhone": .string("13800000000"),
                "reminderHours": .integer(24),
                "remarkLimit": .integer(2000),
                "demo": .boolean(true),
            ]),
        ])
    }

    static func loan() -> WBJSON {
        .object([
            "id": .string("loan-real-1"),
            "version": .integer(1),
            "orderId": .string("wo-real-1"),
            "partId": .string("part-1"),
            "partName": .string("配件"),
            "quantity": .integer(2),
            "returnedGood": .integer(1),
            "returnedQuarantine": .integer(0),
            "consumed": .integer(0),
            "disposed": .integer(0),
            "outstanding": .integer(1),
            "borrowerId": .string("user-engineer"),
            "dueAt": .string("2099-12-31T15:59:59Z"),
            "transfers": .null,
        ])
    }

    static func signedIn(_ role: String = "admin") throws -> (WBStore, WBStubTransport) {
        let transport = WBStubTransport()
        let store = WBStore(transport: transport, environment: environment)
        var result: Result<Void, Error>?
        store.login(username: role, password: "in-memory-test") { value in
            result = value
        }
        try transport.reply("/login", .success(login(role)))
        try transport.reply("/bootstrap", .success(bootstrap(role)))
        guard case .success? = result else {
            throw WBError.invalidResponse("测试登录未完成")
        }
        return (store, transport)
    }
}
