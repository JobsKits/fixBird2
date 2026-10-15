//
//  WBDataScenarios.swift
//  RepairWorkbenchTests
//
//  Created by Jobs on 2026年10月15日，星期四.
//

import Foundation

#if canImport(RepairWorkbench)
    @testable import RepairWorkbench
#endif

@MainActor
enum WBDataScenarios {
    static func expect(_ condition: @autoclosure () throws -> Bool, _ message: String) throws {
        guard try condition() else {
            throw WBError.invalidResponse("测试断言失败：" + message)
        }
    }

    static func rejects(_ work: () throws -> Void) throws {
        do {
            try work()
        } catch {
            return
        }
        throw WBError.invalidResponse("测试断言失败：非法合同被接受")
    }

    static func unquotedAndNullCollections() throws {
        var raw = WBFixture.order().object ?? [:]
        raw["cash"] = .null
        raw["acceptanceRecords"] = .null
        let order = try WBContract.order(.object(raw), full: true)
        try expect(order.quote.version == 0 && order.cash.isEmpty, "未报价v0与Go nil集合应有效")
        try expect(WBFoundation.amount(-1) == "¥−0.01", "金额不得使用浮点舍入")
    }

    static func rejectsCriticalMissingFields() throws {
        for key in ["id", "version", "customerId", "companyId", "quote", "summary", "allowedActions"] {
            var raw = WBFixture.order().object ?? [:]
            raw.removeValue(forKey: key)
            try rejects {
                _ = try WBContract.order(.object(raw))
            }
        }
        for key in [
            "id", "amountCents", "kind", "verified", "handedOver", "purpose", "receipt", "collector", "occurredAt",
        ] {
            var cash: [String: WBJSON] = [
                "id": .string("cash-1"), "amountCents": .integer(1), "kind": .string("receipt"),
                "verified": .boolean(false), "handedOver": .boolean(false), "purpose": .string("收款"),
                "receipt": .string("凭据"), "collector": .string("user-admin"),
                "occurredAt": .string("2026-10-15T12:00:00Z"),
            ]
            cash.removeValue(forKey: key)
            var raw = WBFixture.order().object ?? [:]
            raw["cash"] = .array([.object(cash)])
            try rejects {
                _ = try WBContract.order(.object(raw))
            }
        }
        var raw = WBFixture.order().object ?? [:]
        var summary = raw["summary"]?.object ?? [:]
        summary["missing"] = .null
        raw["summary"] = .object(summary)
        try rejects {
            _ = try WBContract.order(.object(raw))
        }
    }

    static func loanConservation() throws {
        try expect(try WBContract.loan(WBFixture.loan()).blockingQuantity == 1, "合法借用应解析")
        for key in ["quantity", "outstanding", "returnedGood", "borrowerId"] {
            var raw = WBFixture.loan().object ?? [:]
            raw.removeValue(forKey: key)
            try rejects {
                _ = try WBContract.loan(.object(raw))
            }
        }
        var raw = WBFixture.loan().object ?? [:]
        raw["outstanding"] = .integer(2)
        try rejects {
            _ = try WBContract.loan(.object(raw))
        }
    }

    static func login401DoesNotFallback() throws {
        let transport = WBStubTransport()
        let store = WBStore(transport: transport, environment: WBFixture.environment)
        var succeeded = false
        store.login(username: "admin", password: "wrong") { result in
            if case .success = result {
                succeeded = true
            }
        }
        try transport.reply("/login", .failure(.server(401, "unauthorized", "拒绝")))
        try expect(!succeeded && store.actor == nil && store.orders.isEmpty && !store.isBusy, "401不得伪造演示认证")
    }

    static func protected401ClearsPrivateData() throws {
        let (store, transport) = try WBFixture.signedIn()
        store.refresh()
        try transport.reply("/bootstrap", .failure(.server(401, "unauthorized", "失效")))
        try expect(
            store.actor == nil && store.orders.isEmpty && store.parts.isEmpty && store.loans.isEmpty && !store.isBusy,
            "当前会话401必须清私有数据"
        )
    }

    static func lateLoginCannotReplaceIdentity() throws {
        let transport = WBStubTransport()
        let store = WBStore(transport: transport, environment: WBFixture.environment)
        store.login(username: "admin", password: "first") {
            _ in
        }
        store.login(username: "customer", password: "second") {
            _ in
        }
        try transport.reply("/login", .success(WBFixture.login("customer")), last: true)
        try transport.reply("/bootstrap", .success(WBFixture.bootstrap("customer")))
        try transport.reply("/login", .success(WBFixture.login("admin")))
        try expect(store.actor?.role == "customer" && !store.isBusy, "旧身份登录回调不得覆盖当前身份")
    }

    static func lateOldSession401IsIgnored() throws {
        let (store, transport) = try WBFixture.signedIn()
        store.refresh()
        store.logout()
        store.login(username: "customer", password: "second") {
            _ in
        }
        try transport.reply("/login", .success(WBFixture.login("customer")))
        try transport.reply("/bootstrap", .success(WBFixture.bootstrap("customer")), last: true)
        try transport.reply("/bootstrap", .failure(.server(401, "unauthorized", "旧失效")))
        try expect(store.actor?.role == "customer" && !store.isDemo, "旧身份401不得注销当前身份")
    }

    static func fallbackAndRecoveryAreIsolated() throws {
        let (store, transport) = try WBFixture.signedIn()
        store.refresh()
        try transport.reply("/bootstrap", .failure(.transport("断网")))
        try expect(
            store.isDemo
                && store.orders.allSatisfy {
                    $0.id.hasPrefix("ios-demo-")
                },
            "回退必须是独立合成ID"
        )
        store.refresh()
        let request = try transport.reply("/bootstrap", .success(WBFixture.bootstrap()))
        try expect(request.headers["Authorization"] == "Bearer test-token-admin", "只在内存保留真实会话用于恢复")
        try expect(
            !store.isDemo
                && store.orders.map {
                    $0.id
                } == ["wo-real-1"],
            "恢复后替换整个授权数据集"
        )
    }

    static func emptyRealListIsNotFailure() throws {
        let (store, transport) = try WBFixture.signedIn()
        store.refresh()
        try transport.reply("/bootstrap", .success(WBFixture.bootstrap(orders: [])))
        try expect(store.orders.isEmpty && !store.isDemo && !store.hasMore, "合法空列表不得注入演示工单")
    }

    static func actorMismatchIsRejected() throws {
        let (store, transport) = try WBFixture.signedIn()
        store.refresh()
        try transport.reply("/bootstrap", .success(WBFixture.bootstrap("customer")))
        try expect(
            store.isDemo
                && store.orders.allSatisfy {
                    $0.id.hasPrefix("ios-demo-")
                },
            "错误2xx身份不得显示作真实数据"
        )
    }

    static func overlappingRefreshBalancesBusy() throws {
        let (store, transport) = try WBFixture.signedIn()
        store.refresh()
        store.refresh()
        try transport.reply("/bootstrap", .success(WBFixture.bootstrap()), last: true)
        try transport.reply("/bootstrap", .failure(.transport("旧失败")))
        try expect(!store.isBusy && !store.isDemo, "被淘汰刷新须归还busy计数")
    }

    static func queryLateSuccessIsIgnored() throws {
        let (store, transport) = try WBFixture.signedIn()
        store.setQuery("A")
        try transport.reply("/bootstrap", .success(WBFixture.bootstrap()))
        store.setQuery("B")
        try transport.reply("/bootstrap", .success(WBFixture.bootstrap()))
        try transport.reply(
            "/orders?page=1&pageSize=30&q=B&status=",
            .success(WBFixture.page([WBFixture.order("wo-B")]))
        )
        try transport.reply(
            "/orders?page=1&pageSize=30&q=A&status=",
            .success(WBFixture.page([WBFixture.order("wo-A")]))
        )
        try expect(
            store.orders.map {
                $0.id
            } == ["wo-B"] && !store.isBusy,
            "旧筛选结果不得覆盖新结果"
        )
    }

    static func queryLateFailureIsIgnored() throws {
        let (store, transport) = try WBFixture.signedIn()
        store.setQuery("A")
        try transport.reply("/bootstrap", .success(WBFixture.bootstrap()))
        store.setQuery("B")
        try transport.reply("/bootstrap", .success(WBFixture.bootstrap()))
        try transport.reply("/orders?page=1&pageSize=30&q=B&status=", .success(WBFixture.page([])))
        try transport.reply("/orders?page=1&pageSize=30&q=A&status=", .failure(.transport("旧失败")))
        try expect(store.orders.isEmpty && !store.isDemo && !store.isBusy, "旧筛选失败不得将新结果转演示")
    }

    static func obsoleteCurrent401StillRevokes() throws {
        let (store, transport) = try WBFixture.signedIn()
        store.setQuery("A")
        try transport.reply("/bootstrap", .success(WBFixture.bootstrap()))
        store.setQuery("B")
        try transport.reply("/bootstrap", .success(WBFixture.bootstrap()))
        try transport.reply("/orders?page=1&pageSize=30&q=B&status=", .success(WBFixture.page([])))
        try transport.reply("/orders?page=1&pageSize=30&q=A&status=", .failure(.server(401, "expired", "失效")))
        try expect(store.actor == nil && store.orders.isEmpty && !store.isBusy, "同身份旧筛选401仍须撤销会话")
    }

    static func unknownWriteRetainsIdempotency() throws {
        let (store, transport) = try WBFixture.signedIn()
        let original = store.orders[0]
        let payload: [String: Any] = ["remark": "保留原意图"]
        let path = "/orders/wo-real-1/actions"
        store.perform(order: original, action: "remark", payload: payload) {
            _ in
        }
        let first = try transport.reply(path, .failure(.transport("超时")))
        store.loadOrder(id: original.id) {
            _ in
        }
        try transport.reply("/orders/wo-real-1", .success(WBFixture.order()))
        store.perform(order: original, action: "remark", payload: payload) {
            _ in
        }
        let second = try transport.reply(path, .success(WBFixture.order(version: 2)))
        try expect(first.headers["Idempotency-Key"] == second.headers["Idempotency-Key"], "未知结果重试必须复用原幂等键")
        try transport.reply("/bootstrap", .success(WBFixture.bootstrap()))
        store.perform(order: original, action: "remark", payload: payload) {
            _ in
        }
        let third = try transport.reply(path, .failure(.server(422, "rejected", "拒绝")))
        try expect(first.headers["Idempotency-Key"] != third.headers["Idempotency-Key"], "已确认成功的新意图必须换键")
        try expect(!store.isDemo, "业务拒绝不得改成本地成功")
    }

    static func unchangedVersionIsNotSuccess() throws {
        let (store, transport) = try WBFixture.signedIn()
        var success = false
        store.perform(order: store.orders[0], action: "remark", payload: ["remark": "改动"]) { result in
            if case .success = result {
                success = true
            }
        }
        try transport.reply("/orders/wo-real-1/actions", .success(WBFixture.order()))
        try expect(!success && store.orders[0].version == 1 && !store.isDemo, "错误2xx不推进版本不得报保存成功")
    }

    static func reworkRequiresOriginalContext() throws {
        let (store, transport) = try WBFixture.signedIn()
        var success = false
        store.perform(order: store.orders[0], action: "rework", payload: ["note": "返修", "free": true]) { result in
            if case .success = result {
                success = true
            }
        }
        try transport.reply("/orders/wo-real-1/actions", .success(WBFixture.order("wo-child")))
        try expect(!success && store.orders.count == 1, "错误2xx返修子单须关联原单")
    }

    static func lateWriteDoesNotMixDemoDataset() throws {
        let (store, transport) = try WBFixture.signedIn()
        store.perform(order: store.orders[0], action: "remark", payload: ["remark": "延迟"]) {
            _ in
        }
        store.refresh()
        try transport.reply("/bootstrap", .failure(.transport("断网")))
        try transport.reply("/orders/wo-real-1/actions", .success(WBFixture.order(version: 2)))
        try expect(
            store.isDemo
                && store.orders.allSatisfy {
                    $0.id.hasPrefix("ios-demo-")
                },
            "晚到真实写结果不得插入演示数据集"
        )
        try transport.reply("/bootstrap", .success(WBFixture.bootstrap()))
        try expect(!store.isDemo, "重新读取确认后可恢复真实来源")
    }

    static func offlineBoundariesStayExplicit() throws {
        let state = WBDemoState(username: "admin")
        let original = state.orders[0]
        for action in ["sign_quote", "accept", "cash", "verify_cash", "complete"] {
            try rejects {
                _ = try state.perform(id: original.id, action: action, payload: [:])
            }
        }
        try expect(state.orders[0].version == original.version && state.orders[0].cash.isEmpty, "未覆盖离线动作不得生成签署或票款")
        let transport = WBStubTransport()
        let store = WBStore(transport: transport, environment: WBFixture.environment)
        store.enterDemo(role: "warehouse")
        try transport.reply("/login", .failure(.transport("无服务")))
        var succeeded = false
        store.createLoan(payload: [:]) { result in
            if case .success = result {
                succeeded = true
            }
        }
        try expect(
            !succeeded
                && store.loans.allSatisfy {
                    $0.id.hasPrefix("ios-demo-")
                },
            "离线库存须诚实拒绝服务端过账"
        )
    }

    static func releaseEndpointIsReadOnly() throws {
        try expect(
            try WBEnvironment.validate("https://example.com/", requireHTTPS: true) == "https://example.com",
            "HTTPS标准化"
        )
        for value in [
            "http://example.com", "https://user:secret@example.com", "https://example.com/api",
            "https://example.com?token=x",
        ] {
            try rejects {
                _ = try WBEnvironment.validate(value, requireHTTPS: true)
            }
        }
        let store = WBStore(
            transport: WBStubTransport(),
            environment: WBEnvironment(endpoint: "", timeout: 2.5, editable: false)
        )
        try rejects {
            try store.configureEndpoint("http://127.0.0.1", timeout: 1)
        }
        store.enterDemo(role: "admin")
        try expect(
            store.isDemo && store.actor?.id.hasPrefix("ios-demo-") == true && store.endpoint.isEmpty,
            "未配置生产服务仍可明确进入独立演示"
        )
    }

    static var all: [(String, () throws -> Void)] {
        [
            ("unquotedAndNullCollections", unquotedAndNullCollections),
            ("rejectsCriticalMissingFields", rejectsCriticalMissingFields),
            ("loanConservation", loanConservation),
            ("login401DoesNotFallback", login401DoesNotFallback),
            ("protected401ClearsPrivateData", protected401ClearsPrivateData),
            ("lateLoginCannotReplaceIdentity", lateLoginCannotReplaceIdentity),
            ("lateOldSession401IsIgnored", lateOldSession401IsIgnored),
            ("fallbackAndRecoveryAreIsolated", fallbackAndRecoveryAreIsolated),
            ("emptyRealListIsNotFailure", emptyRealListIsNotFailure),
            ("actorMismatchIsRejected", actorMismatchIsRejected),
            ("overlappingRefreshBalancesBusy", overlappingRefreshBalancesBusy),
            ("queryLateSuccessIsIgnored", queryLateSuccessIsIgnored),
            ("queryLateFailureIsIgnored", queryLateFailureIsIgnored),
            ("obsoleteCurrent401StillRevokes", obsoleteCurrent401StillRevokes),
            ("unknownWriteRetainsIdempotency", unknownWriteRetainsIdempotency),
            ("unchangedVersionIsNotSuccess", unchangedVersionIsNotSuccess),
            ("reworkRequiresOriginalContext", reworkRequiresOriginalContext),
            ("lateWriteDoesNotMixDemoDataset", lateWriteDoesNotMixDemoDataset),
            ("offlineBoundariesStayExplicit", offlineBoundariesStayExplicit),
            ("releaseEndpointIsReadOnly", releaseEndpointIsReadOnly),
        ]
    }
}
