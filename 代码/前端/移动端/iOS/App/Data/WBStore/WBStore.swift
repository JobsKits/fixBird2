//
//  WBStore.swift
//  RepairWorkbench
//
//  Created by Jobs on 2026年10月15日，星期四.
//

import Foundation

@MainActor
final class WBStore {
    static let shared = WBStore()

    private(set) var actor: WBActor?
    private(set) var orders: [WBOrder] = []
    private(set) var metrics = WBMetrics()
    private(set) var parts: [WBPart] = []
    private(set) var loans: [WBLoan] = []
    private(set) var settings = WBSettings()
    private(set) var sourceLabel = "尚未登录 · 独立演示"
    private(set) var isDemo = true
    private(set) var lastMessage = "请登录或选择合成账号体验"
    private(set) var isBusy = false
    private(set) var hasMore = false
    private(set) var endpoint: String
    private(set) var timeout: TimeInterval
    let canConfigureEndpoint: Bool

    private let transport: WBTransport
    private var sessionActor: WBActor?
    private var token: String?
    private var credentials: (username: String, password: String)?
    private var generation = 0
    private var readRevision = 0
    private var busyCount = 0
    private var page = 1
    private var query = ""
    private var statusFilter = ""
    private var observers: [UUID: () -> Void] = [:]
    private var detailCache: [String: WBOrder] = [:]
    private var intents: [String: String] = [:]
    private var demo = WBDemoState(username: "customer")

    init(transport: WBTransport? = nil, environment: WBEnvironment? = nil) {
        self.transport = transport ?? WBJobsTransport()
        let environment = environment ?? WBEnvironment.current()
        endpoint = (try? WBEnvironment.validate(environment.endpoint, requireHTTPS: !environment.editable)) ?? ""
        timeout = environment.timeout.isFinite ? min(30, max(0.5, environment.timeout)) : 2.5
        canConfigureEndpoint = environment.editable
    }

    var demoAccounts: [WBActor] {
        WBActor.roles.map {
            WBDemoState(username: $0).actor
        }
    }

    @discardableResult
    func observe(_ callback: @escaping () -> Void) -> UUID {
        let id = UUID()
        observers[id] = callback
        callback()
        return id
    }

    nonisolated func removeObserver(_ id: UUID) {
        Task { @MainActor [weak self] in
            self?.observers.removeValue(forKey: id)
        }
    }

    private func publish() {
        Array(observers.values).forEach {
            $0()
        }
    }

    private func begin() -> Int {
        busyCount += 1
        isBusy = true
        publish()
        return generation
    }

    private func end(_ captured: Int) {
        guard captured == generation else {
            return
        }
        busyCount = max(0, busyCount - 1)
        isBusy = busyCount > 0
        publish()
    }

    private func clearIdentity() {
        generation += 1
        readRevision += 1
        actor = nil
        sessionActor = nil
        token = nil
        credentials = nil
        detailCache.removeAll()
        intents.removeAll()
        orders.removeAll()
        parts.removeAll()
        loans.removeAll()
        settings = WBSettings()
        metrics = WBMetrics()
        hasMore = false
        busyCount = 0
        isBusy = false
        isDemo = true
        sourceLabel = "未登录 · 独立演示"
    }

    func configureEndpoint(_ value: String, timeout requestedTimeout: TimeInterval) throws {
        guard canConfigureEndpoint else {
            throw WBError.unavailable("Release 服务地址由 WBProductionAPIURL 配置，只允许 HTTPS")
        }
        let value = try WBEnvironment.validate(value, requireHTTPS: false)
        guard requestedTimeout.isFinite, (0.5...30).contains(requestedTimeout) else {
            throw WBError.unavailable("请求超时须为0.5至30秒")
        }
        clearIdentity()
        endpoint = value
        timeout = requestedTimeout
        WBEnvironment.saveDebug(endpoint: value, timeout: timeout)
        lastMessage = "服务地址已保存，请重新登录；旧会话已清除"
        publish()
    }

    func enterDemo(role: String) {
        let username = WBActor.roles.contains(role) ? role : "customer"
        login(username: username, password: "Demo-Repair-2026!") {
            _ in
        }
    }

    func login(username: String, password: String, completion: @escaping (Result<Void, Error>) -> Void) {
        clearIdentity()
        credentials = (username.trimmingCharacters(in: .whitespacesAndNewlines), password)
        let captured = begin()
        authenticate { result in
            guard captured == self.generation else {
                completion(.failure(WBError.stale))
                return
            }
            switch result {
            /// 真实认证后再读取全局概览。
            case .success:
                self.refresh {
                    self.end(captured)
                    if self.actor != nil {
                        completion(.success(()))
                    } else {
                        completion(.failure(WBError.server(401, "unauthenticated", "会话已失效，请重新登录")))
                    }
                }
            /// 失败保留原错误语义，不能视作成功。
            case .failure(let error):
                if error.isUnauthorized || error.isBusinessRejection {
                    self.clearIdentity()
                    self.lastMessage = error.localizedDescription
                    self.publish()
                    completion(.failure(error))
                    return
                }
                guard Self.isSyntheticUsername(username), !password.isEmpty else {
                    self.clearIdentity()
                    self.lastMessage = "登录未完成；可选择合成账号体验独立演示"
                    self.publish()
                    completion(.failure(error))
                    return
                }
                self.useDemo(username: username, message: "API登录未验证，已进入独立合成演示；刷新继续尝试服务")
                self.end(captured)
                completion(.success(()))
            }
        }
    }

    private static func isSyntheticUsername(_ username: String) -> Bool {
        WBActor.roles.contains(username) || ["customer-peer", "customer-b"].contains(username)
    }

    private func authenticate(completion: @escaping (Result<Void, WBError>) -> Void) {
        if token != nil, sessionActor != nil {
            completion(.success(()))
            return
        }
        guard let credentials else {
            completion(.failure(.unavailable("请先登录")))
            return
        }
        send(
            path: "/login",
            method: "POST",
            body: ["username": credentials.username, "password": credentials.password],
            authenticated: false
        ) { result in
            do {
                let value = try result.get()
                let raw = try WBContract.object(value)
                let token = try WBContract.text(raw, "token", nonempty: true)
                let actor = try WBContract.actor(raw["actor"] ?? .null)
                self.token = token
                self.sessionActor = actor
                self.actor = actor
                completion(.success(()))
            } catch let error as WBError {
                completion(.failure(error))
            } catch {
                completion(.failure(.invalidResponse("登录响应无效")))
            }
        }
    }

    func logout() {
        let oldToken = token
        if oldToken != nil {
            send(path: "/logout", method: "POST", body: [:]) {
                _ in
            }
        }
        clearIdentity()
        lastMessage = "已退出，私有缓存与请求意图已清除"
        publish()
    }

    func refresh() {
        refresh(completion: {})
    }

    private func refresh(completion: @escaping () -> Void) {
        readRevision += 1
        let revision = readRevision
        let captured = begin()
        authenticate { result in
            if captured == self.generation, case .failure(let error) = result, error.isUnauthorized {
                self.readFailed(error)
            }
            guard captured == self.generation, revision == self.readRevision else {
                self.end(captured)
                completion()
                return
            }
            switch result {
            /// 概览与首屏读取均受当前认证锚点保护。
            case .success:
                self.send(path: "/bootstrap") { response in
                    if captured == self.generation, case .failure(let error) = response, error.isUnauthorized {
                        self.readFailed(error)
                    }
                    guard captured == self.generation, revision == self.readRevision else {
                        self.end(captured)
                        completion()
                        return
                    }
                    do {
                        try self.applyBootstrap(try response.get())
                        if self.query.isEmpty && self.statusFilter.isEmpty {
                            self.end(captured)
                            completion()
                        } else {
                            self.readPage(1, append: false) { _ in
                                self.end(captured)
                                completion()
                            }
                        }
                    } catch let error as WBError {
                        self.readFailed(error)
                        self.end(captured)
                        completion()
                    } catch {
                        self.readFailed(.invalidResponse("概览响应不完整"))
                        self.end(captured)
                        completion()
                    }
                }
            /// 失败保留原错误语义，不能视作成功。
            case .failure(let error):
                self.readFailed(error)
                self.end(captured)
                completion()
            }
        }
    }

    func setQuery(_ value: String, status: String = "") {
        query = value
        statusFilter = status
        refresh()
    }

    func loadMore() {
        guard hasMore, !isBusy, !isDemo else {
            return
        }
        let captured = begin()
        readPage(page + 1, append: true) { _ in
            self.end(captured)
        }
    }

    private func readPage(_ wantedPage: Int, append: Bool, completion: @escaping (Result<Void, WBError>) -> Void) {
        let captured = generation
        let revision = readRevision
        let requestedQuery = query
        let requestedStatus = statusFilter
        let encodedQuery =
            query.addingPercentEncoding(
                withAllowedCharacters: .urlQueryAllowed.subtracting(CharacterSet(charactersIn: "&=+#"))
            ) ?? ""
        let path = "/orders?page=\(wantedPage)&pageSize=30&q=\(encodedQuery)&status=\(statusFilter)"
        send(path: path) { result in
            if captured == self.generation, case .failure(let error) = result, error.isUnauthorized {
                self.readFailed(error)
            }
            guard captured == self.generation, revision == self.readRevision, requestedQuery == self.query,
                requestedStatus == self.statusFilter
            else {
                completion(.failure(.stale))
                return
            }
            do {
                let raw = try WBContract.object(try result.get())
                let items = try WBContract.array(raw, "items").map {
                    try WBContract.order($0)
                }
                let total = try WBContract.integer(raw, "total")
                let returnedPage = try WBContract.integer(raw, "page", minimum: 1)
                let size = try WBContract.integer(raw, "pageSize", minimum: 1)
                let pages = try WBContract.integer(raw, "totalPages")
                guard returnedPage == wantedPage, size == 30, items.count <= size, items.count <= total,
                    pages == (total + size - 1) / size
                else {
                    throw WBError.invalidResponse("分页关联不正确")
                }
                let combined = append ? self.orders + items : items
                var seen = Set<String>()
                self.orders = combined.filter {
                    seen.insert($0.id).inserted
                }
                self.page = wantedPage
                self.hasMore = returnedPage < pages
                self.lastMessage = "已读取当前授权工单"
                self.publish()
                completion(.success(()))
            } catch let error as WBError {
                self.readFailed(error)
                completion(.failure(error))
            } catch {
                self.readFailed(.invalidResponse("列表响应不完整"))
                completion(.failure(.invalidResponse("列表响应不完整")))
            }
        }
    }

    private func applyBootstrap(_ value: WBJSON) throws {
        let raw = try WBContract.object(value)
        let returnedActor = try WBContract.actor(raw["actor"] ?? .null)
        guard let sessionActor, returnedActor.matches(sessionActor) else {
            throw WBError.invalidResponse("概览身份与当前登录不匹配")
        }
        let newOrders = try WBContract.array(raw, "orders").map {
            try WBContract.order($0)
        }
        let newParts = try WBContract.array(raw, "parts").map {
            try WBContract.part($0)
        }
        let newLoans = try WBContract.array(raw, "loans").map {
            try WBContract.loan($0)
        }
        let newSettings = try WBContract.settings(raw["settings"] ?? .null)
        let newMetrics = try WBContract.metrics(raw["metrics"] ?? .null)
        let orderPage = try WBContract.object(raw["orderPage"] ?? .null)
        let pages = try WBContract.integer(orderPage, "totalPages")
        let total = try WBContract.integer(orderPage, "total")
        let returnedPage = try WBContract.integer(orderPage, "page", minimum: 1)
        let pageSize = try WBContract.integer(orderPage, "pageSize", minimum: 1)
        guard returnedPage == 1, pageSize == 30, newOrders.count <= total, newOrders.count <= pageSize,
            pages == (total + pageSize - 1) / pageSize
        else {
            throw WBError.invalidResponse("概览分页关联不正确")
        }
        orders = newOrders
        parts = newParts
        loans = newLoans
        settings = newSettings
        metrics = newMetrics
        actor = returnedActor
        isDemo = false
        sourceLabel = "API服务端 · 合成业务存储"
        lastMessage = "当前登录授权资料已更新"
        page = 1
        hasMore = pages > 1
        detailCache.removeAll()
        publish()
    }

    private func readFailed(_ error: WBError) {
        guard error != .stale else {
            return
        }
        if error.isUnauthorized {
            clearIdentity()
            lastMessage = "会话已失效，请重新登录；旧授权资料已清除"
            publish()
            return
        }
        useDemo(
            username: credentials?.username ?? sessionActor?.username ?? "customer",
            message: "读取未完成，显示独立合成样例；真实会话不自动重放写操作"
        )
    }

    private func useDemo(username: String, message: String) {
        demo = WBDemoState(username: Self.isSyntheticUsername(username) ? username : "customer")
        actor = demo.actor
        orders = demo.orders
        parts = demo.parts
        loans = demo.loans
        settings = demo.settings
        metrics = demo.metrics
        isDemo = true
        sourceLabel = "独立合成演示 · 不代表真实履约"
        lastMessage = message
        detailCache.removeAll()
        page = 1
        hasMore = false
        publish()
    }

    func loadOrder(id: String, completion: @escaping (Result<WBOrder, Error>) -> Void) {
        if isDemo {
            let captured = generation
            probeDemo { result in
                guard captured == self.generation else {
                    completion(.failure(WBError.stale))
                    return
                }
                switch result {
                /// 按当前枚举分支转换已验证的数据。
                case .success:
                    completion(.failure(WBError.stale))
                /// 失败保留原错误语义，不能视作成功。
                case .failure(let error):
                    guard error != .stale, !error.isUnauthorized, !error.isBusinessRejection,
                        let order = self.demo.orders.first(where: {
                            $0.id == id
                        })
                    else {
                        completion(.failure(error))
                        return
                    }
                    completion(.success(order))
                }
            }
            return
        }
        let captured = begin()
        send(path: "/orders/" + id) { result in
            defer {
                self.end(captured)
            }
            do {
                let order = try WBContract.order(try result.get(), full: true)
                guard order.id == id else {
                    throw WBError.invalidResponse("详情工单不匹配")
                }
                self.detailCache[id] = order
                completion(.success(order))
            } catch let error as WBError {
                if error == .stale {
                    completion(.failure(error))
                    return
                }
                if error.isUnauthorized {
                    self.readFailed(error)
                }
                self.lastMessage = error.localizedDescription
                completion(.failure(error))
            } catch {
                completion(.failure(error))
            }
        }
    }

    func createOrder(input: WBOrderInput, completion: @escaping (Result<WBOrder, Error>) -> Void) {
        if isDemo {
            demoMutation(completion: completion) {
                try self.demo.create(input)
            }
            return
        }
        writeOrder(path: "/orders", body: input.payload, submittedOrder: nil, completion: completion)
    }

    func perform(
        order: WBOrder,
        action: String,
        payload: [String: Any],
        completion: @escaping (Result<WBOrder, Error>) -> Void
    ) {
        guard order.can(action) else {
            completion(.failure(WBError.unavailable("当前角色或阶段不允许此动作")))
            return
        }
        if isDemo {
            demoMutation(completion: completion) {
                try self.demo.perform(id: order.id, action: action, payload: payload)
            }
            return
        }
        guard !order.id.hasPrefix("ios-demo-") else {
            completion(.failure(WBError.stale))
            return
        }
        writeOrder(
            path: "/orders/" + order.id + "/actions",
            body: ["type": action, "version": order.version, "payload": payload],
            submittedOrder: order,
            completion: completion
        )
    }

    private func writeOrder(
        path: String,
        body: [String: Any],
        submittedOrder: WBOrder?,
        completion: @escaping (Result<WBOrder, Error>) -> Void
    ) {
        let captured = begin()
        send(path: path, method: "POST", body: body, intent: true) { result in
            defer {
                self.end(captured)
            }
            do {
                let order = try WBContract.order(try result.get(), full: true)
                if let original = submittedOrder {
                    if body["type"] as? String == "rework" {
                        guard order.id != original.id, order.text("originalOrderId") == original.id else {
                            throw WBError.invalidResponse("未返回正确关联的新返修子单")
                        }
                    } else {
                        guard order.id == original.id, order.version > original.version else {
                            throw WBError.invalidResponse("写响应未确认本次版本推进")
                        }
                    }
                }
                if submittedOrder == nil {
                    let expectedCustomer =
                        self.sessionActor?.role == "customer" ? self.sessionActor?.id : body["customerId"] as? String
                    guard order.type == body["type"] as? String, order.device == body["device"] as? String,
                        order.description == body["description"] as? String, order.customerId == expectedCustomer
                    else {
                        throw WBError.invalidResponse("新建响应与原提交客户、设备或需求不匹配")
                    }
                }
                self.releaseIntent(path: path, body: body)
                guard !self.isDemo else {
                    self.lastMessage = "服务端已确认先前提交，当前仍显示独立样例；正在重新读取授权数据"
                    self.publish()
                    completion(.failure(WBError.stale))
                    self.refresh()
                    return
                }
                self.detailCache[order.id] = order
                if let index = self.orders.firstIndex(where: {
                    $0.id == order.id
                }) {
                    self.orders[index] = order
                } else {
                    self.orders.insert(order, at: 0)
                }
                self.lastMessage = "服务端已确认保存"
                self.publish()
                completion(.success(order))
                self.refresh()
            } catch let error as WBError {
                self.writeFailed(error)
                completion(
                    .failure(
                        error.isBusinessRejection || error.isUnauthorized || error == .stale
                            ? error : WBError.unknownWrite(error.localizedDescription)
                    )
                )
            } catch {
                self.writeFailed(.unknownWrite(error.localizedDescription))
                completion(.failure(WBError.unknownWrite(error.localizedDescription)))
            }
        }
    }

    private func writeFailed(_ error: WBError) {
        guard error != .stale else {
            return
        }
        if error.isUnauthorized {
            readFailed(error)
            return
        }
        lastMessage = error.isBusinessRejection ? error.localizedDescription : "提交结果未知；输入及原请求意图保留，请核对后重试"
        publish()
    }

    private func demoMutation(
        completion: @escaping (Result<WBOrder, Error>) -> Void,
        mutation: @escaping () throws -> WBOrder
    ) {
        let captured = generation
        probeDemo { result in
            guard captured == self.generation else {
                completion(.failure(WBError.stale))
                return
            }
            switch result {
            /// 恢复后要求重新选择真实单据，不把合成ID提交给真实业务。
            case .success:
                completion(.failure(WBError.stale))
            /// 失败保留原错误语义，不能视作成功。
            case .failure(let error):
                guard !error.isUnauthorized, !error.isBusinessRejection, self.actor != nil else {
                    completion(.failure(error))
                    return
                }
                do {
                    let order = try mutation()
                    self.orders = self.demo.orders
                    self.metrics = self.demo.metrics
                    self.parts = self.demo.parts
                    self.loans = self.demo.loans
                    self.lastMessage = "仅独立合成演示已更新，未保存到服务端"
                    self.publish()
                    completion(.success(order))
                } catch {
                    self.lastMessage = error.localizedDescription
                    self.publish()
                    completion(.failure(error))
                }
            }
        }
    }

    private func probeDemo(completion: @escaping (Result<Void, WBError>) -> Void) {
        authenticate { result in
            switch result {
            /// 按当前枚举分支转换已验证的数据。
            case .success:
                self.send(path: "/bootstrap") { result in
                    do {
                        try self.applyBootstrap(try result.get())
                        completion(.success(()))
                    } catch let error as WBError {
                        if error.isUnauthorized {
                            self.readFailed(error)
                        }
                        completion(.failure(error))
                    } catch {
                        completion(.failure(.invalidResponse("概览不可用")))
                    }
                }
            /// 失败保留原错误语义，不能视作成功。
            case .failure(let error):
                if error.isUnauthorized {
                    self.readFailed(error)
                }
                completion(.failure(error))
            }
        }
    }

    func updateSettings(payload: [String: Any], completion: @escaping (Result<Void, Error>) -> Void) {
        guard !isDemo, actor?.role == "admin" else {
            completion(.failure(WBError.unavailable("公司配置首版仅允许已登录的服务端管理员保存")))
            return
        }
        simpleWrite(
            path: "/settings",
            body: payload,
            validate: { value in
                let settings = try WBContract.settings(value)
                guard settings.companyAddress == payload["companyAddress"] as? String,
                    settings.companyReceiver == payload["companyReceiver"] as? String,
                    settings.companyPhone == payload["companyPhone"] as? String
                else {
                    throw WBError.invalidResponse("配置与提交内容不一致")
                }
                let requested = try WBContract.object(WBFoundation.json(payload))
                let returned = try WBContract.object(value)
                for (key, wanted) in requested {
                    let expected: WBJSON = key == "remarkLimit" && wanted.integer == 0 ? .integer(2000) : wanted
                    guard returned[key] == expected else {
                        throw WBError.invalidResponse("公司配置保存结果不匹配")
                    }
                }
                self.settings = settings
            },
            completion: completion
        )
    }

    func createLoan(payload: [String: Any], completion: @escaping (Result<Void, Error>) -> Void) {
        guard !isDemo, ["admin", "warehouse"].contains(actor?.role ?? "") else {
            completion(.failure(WBError.unavailable("借出首版仅支持服务端授权仓库或管理员办理，演示不虚构库存过账")))
            return
        }
        simpleWrite(
            path: "/loans",
            body: payload,
            validate: { value in
                let returned = try WBContract.loan(value)
                let requested = try WBContract.object(WBFoundation.json(payload))
                guard returned.orderId == requested["orderId"]?.string, returned.partId == requested["partId"]?.string,
                    returned.borrowerId == requested["borrowerId"]?.string,
                    Int64(returned.quantity) == requested["quantity"]?.integer
                else {
                    throw WBError.invalidResponse("借用响应未关联原工单、配件、借用人或数量")
                }
            },
            completion: completion
        )
    }

    func loanAction(
        loan: WBLoan,
        action: String,
        payload: [String: Any],
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        let role = actor?.role ?? ""
        guard !isDemo, ["admin", "warehouse"].contains(role), action == "return" || role == "admin" else {
            completion(.failure(WBError.unavailable("仅服务端授权人员可办理；耗用、处置及转出须管理员批准")))
            return
        }
        simpleWrite(
            path: "/loans/" + loan.id + "/actions",
            body: ["type": action, "version": loan.version, "payload": payload],
            validate: { value in
                let returned = try WBContract.loan(value)
                guard returned.id == loan.id, returned.version > loan.version else {
                    throw WBError.invalidResponse("借用写响应版本或ID不匹配")
                }
            },
            completion: completion
        )
    }

    private func simpleWrite(
        path: String,
        body: [String: Any],
        validate: @escaping (WBJSON) throws -> Void,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        let captured = begin()
        send(path: path, method: "POST", body: body, intent: true) { result in
            defer {
                self.end(captured)
            }
            do {
                guard !self.isDemo else {
                    throw WBError.unknownWrite("数据来源已变更，请刷新并核对先前提交结果")
                }
                try validate(result.get())
                self.releaseIntent(path: path, body: body)
                self.lastMessage = "服务端已确认保存"
                self.publish()
                completion(.success(()))
                self.refresh()
            } catch let error as WBError {
                self.writeFailed(error)
                completion(
                    .failure(
                        error.isBusinessRejection || error.isUnauthorized || error == .stale
                            ? error : WBError.unknownWrite(error.localizedDescription)
                    )
                )
            } catch {
                completion(.failure(WBError.unknownWrite(error.localizedDescription)))
            }
        }
    }

    private func fingerprint(path: String, body: [String: Any]) -> String {
        let encoded = (try? WBFoundation.data(body).base64EncodedString()) ?? "invalid"
        return path + ":" + encoded
    }

    private func releaseIntent(path: String, body: [String: Any]) {
        intents.removeValue(forKey: fingerprint(path: path, body: body))
    }

    private func send(
        path: String,
        method: String = "GET",
        body: [String: Any]? = nil,
        authenticated: Bool = true,
        intent: Bool = false,
        completion: @escaping (Result<WBJSON, WBError>) -> Void
    ) {
        let captured = generation
        var headers: [String: String] = ["Accept": "application/json"]
        if authenticated, let token {
            headers["Authorization"] = "Bearer " + token
        }
        if intent, let body {
            let fingerprint = fingerprint(path: path, body: body)
            let key = intents[fingerprint] ?? UUID().uuidString
            intents[fingerprint] = key
            headers["Idempotency-Key"] = key
        }
        guard !endpoint.isEmpty else {
            completion(.failure(.unavailable("生产API尚未配置，当前可使用独立合成演示")))
            return
        }
        let request = WBRequest(
            endpoint: endpoint,
            path: path,
            method: method,
            headers: headers,
            body: body,
            timeout: timeout
        )
        transport.send(request) { result in
            guard captured == self.generation else {
                completion(.failure(.stale))
                return
            }
            completion(result)
        }
    }
}
