//
//  DesktopOrderFilterSmoke.swift
//  RepairDesktopTests
//
//  Created by Jobs on 2026年11月18日，星期三.
//

import Foundation

@MainActor
private final class FilterTransport: WBTransport {

    typealias Reply = (Result<WBJSON, WBError>) -> Void
    var offline = false
    var holdLists = false
    var holdDetails = false
    var lists: [(WBRequest, Reply)] = []
    var detail: Reply?
    var paths: [String] = []
    let seed = WBDemoState(username: "admin")
    let intake: [WBOrder]
    let execution: WBOrder

    init() {
        let fixture = WBDemoState(username: "admin")
        intake = (0..<31).map { index in
            var order = fixture.orders[0]
            order.raw["id"] = .string("private-intake-id-\(index)")
            order.raw["number"] = .string("PUBLIC-PUMP-\(index)")
            order.raw["device"] = .string("Pump Controller \(index)")
            return order
        }
        var order = fixture.orders[2]
        order.raw["id"] = .string("private-execution-id")
        order.raw["number"] = .string("PUBLIC-ALPHA")
        order.raw["device"] = .string("Alpha Board")
        execution = order
    }

    var actor: [String: Any] {
        ["id": seed.actor.id, "username": "admin", "name": seed.actor.name, "role": "admin",
         "companyId": seed.actor.companyId, "status": "active", "authVersion": 1]
    }

    func send(_ request: WBRequest, completion: @escaping Reply) {
        paths.append(request.path)
        if offline {
            completion(.failure(.transport("isolated offline filter fixture")))
        } else if request.path == "/login" {
            completion(.success(try! WBFoundation.json(["token": "filter-test-token", "actor": actor])))
        } else if request.path == "/bootstrap" {
            let orders = [execution] + intake
            completion(.success(try! WBFoundation.json([
                "actor": actor, "orders": orders.prefix(30).map { $0.raw.mapValues(\.any) },
                "parts": [], "loans": [],
                "settings": ["companyAddress": "fixture", "companyReceiver": "fixture", "companyPhone": "fixture",
                             "reminderHours": 24, "remarkLimit": 2000, "demo": true],
                "metrics": ["openCount": 32, "settlingCount": 0, "remainingCents": 50000,
                            "readyCount": 0, "tasksCount": 32, "blockedCount": 0],
                "orderPage": ["page": 1, "pageSize": 30, "total": 32, "totalPages": 2],
            ])))
        } else if request.path.hasPrefix("/orders?") {
            if holdLists {
                lists.append((request, completion))
            } else {
                completion(.success(page(request)))
            }
        } else if request.path.hasPrefix("/orders/") {
            if holdDetails {
                detail = completion
            } else {
                let id = String(request.path.dropFirst("/orders/".count))
                let order = ([execution] + intake).first { $0.id == id }!
                completion(.success(.object(order.raw)))
            }
        } else {
            completion(.failure(.unavailable("Unexpected test route: " + request.path)))
        }
    }

    func page(_ request: WBRequest) -> WBJSON {
        let items = URLComponents(string: "http://fixture" + request.path)!.queryItems!
        let status = items.first { $0.name == "status" }?.value ?? ""
        let query = items.first { $0.name == "q" }?.value ?? ""
        let page = Int(items.first { $0.name == "page" }!.value!)!
        var orders: [WBOrder]
        if status == "pending_intake" {
            orders = intake
        } else if status == "pending_execution" {
            orders = [execution]
        } else {
            orders = [execution] + intake
        }
        // Fixed server fixtures keep expectations independent of the desktop predicate.
        if query == "pump" {
            orders = status == "pending_execution" ? [] : intake
        } else if query == "alpha" {
            orders = status == "pending_intake" ? [] : [execution]
        } else if !query.isEmpty {
            orders = []
        }
        return try! WBFoundation.json([
            "items": Array(orders.dropFirst((page - 1) * 30).prefix(30)).map { $0.raw.mapValues(\.any) },
            "total": orders.count, "page": page, "pageSize": 30, "totalPages": (orders.count + 29) / 30,
        ])
    }
}

@main
struct DesktopOrderFilterSmoke {

    @MainActor static func main() async throws {
        let offlineTransport = FilterTransport()
        offlineTransport.offline = true
        let offlineStore = makeStore(offlineTransport, demo: true)
        let offline = DesktopModel(store: offlineStore)
        try await login(offlineStore, role: "admin", password: "1234")
        precondition(offlineStore.isDemo && offline.visibleOrders.count == 3)
        let execution = offline.visibleOrders.first { $0.status == "pending_execution" }!
        offline.open(execution)
        precondition(offline.selectedOrderID == execution.id && offline.selected != nil)
        offline.setOrderFilter("", status: "pending_intake")
        precondition(offline.visibleOrders.count == 1 && offline.visibleOrders[0].status == "pending_intake")
        precondition(offline.selected == nil && offline.selectedOrderID == nil)
        precondition(offline.visibleOpenCount == 1 && offline.visibleRemainingCents == 0)
        offline.setOrderFilter("  门禁  ", status: "pending_execution")
        precondition(offline.visibleOrders.count == 1 && offline.visibleOrders[0].id == execution.id)
        precondition(offline.visibleRemainingCents == 50000)
        offlineStore.refresh()
        precondition(offline.visibleOrders.count == 1, "offline refresh lost the filter")
        offline.setOrderFilter("变频", status: "pending_execution")
        precondition(offline.visibleOrders.isEmpty && offline.visibleOpenCount == 0 && offline.visibleRemainingCents == 0)
        offline.setOrderFilter("", status: "completed")
        precondition(offline.visibleOrders.isEmpty)
        offline.setOrderFilter("", status: "")
        precondition(offline.visibleOrders.count == 3 && offline.visibleRemainingCents == 178000)
        offline.setOrderFilter("合成内部交接", status: "")
        precondition(offline.visibleOrders.count == 3, "admin remark must be searchable")
        offline.setOrderFilter("ios-demo-intake", status: "")
        precondition(offline.visibleOrders.isEmpty, "raw ID must not match the API q contract")
        offline.setOrderFilter("不得提交真实附件", status: "")
        precondition(offline.visibleOrders.isEmpty, "customer note must not be searched")
        offline.setOrderFilter("image/png", status: "")
        precondition(offline.visibleOrders.isEmpty, "media metadata must not be searched")
        let engineerStore = makeStore(offlineTransport, demo: true)
        let engineer = DesktopModel(store: engineerStore)
        try await login(engineerStore, role: "engineer", password: "Demo-Repair-2026!")
        engineer.setOrderFilter("合成内部交接", status: "")
        precondition(engineer.visibleOrders.isEmpty, "engineer remark is outside the API search contract")
        print("PASS offline filter: 3 fixtures -> status + trimmed search -> empty -> all, refreshed filters, scoped totals, detail exclusion and role-aware q fields")

        let transport = FilterTransport()
        let store = makeStore(transport, demo: false)
        let model = DesktopModel(store: store)
        try await login(store, role: "admin", password: "fixture")
        precondition(!store.isDemo && model.visibleOrders.count == 30 && store.hasMore)
        transport.holdDetails = true
        model.open(transport.execution)
        let delayedDetail = transport.detail!
        model.setOrderFilter(" PUMP ", status: "pending_intake")
        precondition(model.visibleOrders.count == 30 && model.visibleOrders.allSatisfy { $0.status == "pending_intake" })
        precondition(store.hasMore && model.selectedOrderID == nil)
        delayedDetail(.success(.object(transport.execution.raw)))
        precondition(model.selected == nil && model.selectedOrderID == nil, "excluded delayed detail resurrected")
        precondition(transport.paths.contains("/orders?page=1&pageSize=30&q=pump&status=pending_intake"))
        store.loadMore()
        precondition(model.visibleOrders.count == 31 && !store.hasMore)
        precondition(transport.paths.contains("/orders?page=2&pageSize=30&q=pump&status=pending_intake"))
        model.setOrderFilter("missing-match", status: "pending_intake")
        precondition(model.visibleOrders.isEmpty && !store.hasMore)
        model.setOrderFilter("", status: "")
        precondition(model.visibleOrders.count == 30 && store.hasMore, "all must restore page one, not pretend to load all 32")
        transport.holdLists = true
        model.setOrderFilter("pump", status: "pending_intake")
        model.setOrderFilter("alpha", status: "pending_execution")
        precondition(transport.lists.count == 2)
        let old = transport.lists[0]
        old.1(.success(transport.page(old.0)))
        precondition(model.visibleOrders.allSatisfy { $0.status == "pending_execution" })
        let newest = transport.lists[1]
        newest.1(.success(transport.page(newest.0)))
        precondition(model.visibleOrders.count == 1 && model.visibleOrders[0].id == transport.execution.id)
        transport.holdLists = false
        store.refresh()
        precondition(model.visibleOrders.count == 1 && model.visibleOrders[0].device == "Alpha Board")
        print("PASS API filter: q/status requests, 30+1 matching pagination, empty/reset, stale list/detail rejection and refresh continuity")
    }

    @MainActor private static func makeStore(_ transport: WBTransport, demo: Bool) -> WBStore {
        WBStore(transport: transport,
                environment: WBEnvironment(endpoint: "http://127.0.0.1:1", timeout: 0.5, editable: true),
                allowsSyntheticDemo: demo,
                requiresSyntheticPassword: true)
    }

    @MainActor private static func login(_ store: WBStore, role: String, password: String) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            store.login(username: role, password: password) {
                continuation.resume(with: $0)
            }
        }
    }
}
