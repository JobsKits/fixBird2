//
//  DesktopCustomerDirectory.swift
//  RepairDesktop
//
//  Created by Jobs on 2026年11月18日，星期三.
//

import Foundation
import SwiftUI

struct DesktopCustomerCompany: Identifiable {

    let id: String
    let name: String
}

struct DesktopCustomerProfile: Identifiable {

    let id: String
    let name: String
    var accounts: [WBActor]
    var companies: [DesktopCustomerCompany]
}

@MainActor final class DesktopCustomerDirectory: ObservableObject {

    @Published var profiles: [DesktopCustomerProfile] = []
    @Published var canManage = false
    @Published var busy = false
    @Published var error = ""
    @Published var revision = 0
    private var requestRevision = 0
    private var selected: (customer: String, account: String, company: String)?
    private var pendingBody: [String: Any]?
    private static var demoProfiles: [String: [DesktopCustomerProfile]] = [:]

    var selection: (customer: String, account: String, company: String)? {
        return selected
    }

    var pendingCreation: [String: Any]? {
        return pendingBody
    }

    func load(store: WBStore) {
        guard let actor = store.actor else {
            return
        }
        requestRevision += 1
        let ticket = requestRevision
        let endpoint = store.endpoint
        let source = store.isDemo
        busy = true
        error = ""
        selected = nil
        if source {
            let key = endpoint + ":" + actor.id
            profiles = Self.demoProfiles[key] ?? Self.seedDemo(store: store)
            Self.demoProfiles[key] = profiles
            canManage = ["admin", "dispatcher"].contains(actor.role)
            busy = false
            revision += 1
            return
        }
        store.send(path: "/customer-directory") { [weak self, weak store] result in
            guard let self, let store, self.requestRevision == ticket,
                  store.endpoint == endpoint, store.isDemo == source, store.actor?.matches(actor) == true else {
                return
            }
            self.busy = false
            do {
                try self.apply(try result.get(), actor: actor)
            } catch {
                self.error = error.localizedDescription
                if let failure = error as? WBError, failure.isUnauthorized {
                    store.logout()
                }
            }
        }
    }

    func create(_ body: [String: Any],
                store: WBStore,
                completion: @escaping (Result<Void, Error>) -> Void) {
        guard !["password", "confirmPassword"].contains(where: {
            DesktopPasswordPolicy.containsEmoji(body[$0] as? String ?? "")
        }) else {
            completion(.failure(WBError.unavailable("密码不能包含表情符号")))
            return
        }
        guard let actor = store.actor, ["admin", "dispatcher"].contains(actor.role), !busy else {
            completion(.failure(WBError.unavailable("仅公司负责人或调度可新建客户档案")))
            return
        }
        if let pendingBody, !NSDictionary(dictionary: pendingBody).isEqual(to: body) {
            completion(.failure(WBError.unknownWrite("提交结果未知；输入及原请求意图保留，请核对后重试")))
            return
        }
        let endpoint = store.endpoint
        let source = store.isDemo
        requestRevision += 1
        let ticket = requestRevision
        busy = true
        if source {
            do {
                try createDemo(body, store: store, actor: actor)
                busy = false
                completion(.success(()))
            } catch {
                busy = false
                completion(.failure(error))
            }
            return
        }
        let frozen = pendingBody ?? body
        pendingBody = frozen
        store.send(path: "/customer-directory", method: "POST", body: frozen, intent: true) { [weak self, weak store] result in
            guard let self, let store, self.requestRevision == ticket,
                  store.endpoint == endpoint, store.isDemo == source, store.actor?.matches(actor) == true else {
                completion(.failure(WBError.stale))
                return
            }
            self.busy = false
            do {
                try self.apply(try result.get(), actor: actor)
                self.pendingBody = nil
                completion(.success(()))
            } catch {
                if let failure = error as? WBError {
                    if failure.isUnauthorized || failure.isBusinessRejection || failure == .stale {
                        self.pendingBody = nil
                    }
                    if failure.isUnauthorized {
                        store.logout()
                    }
                }
                completion(.failure(error))
            }
        }
    }

    private func apply(_ value: WBJSON,
                       actor: WBActor) throws {
        let root = try WBContract.object(value)
        let manage = try WBContract.flag(root, "canManage")
        guard let items = root["customers"]?.array, !manage || ["admin", "dispatcher"].contains(actor.role) else {
            throw WBError.invalidResponse("客户目录授权或内容不正确")
        }
        let received = try items.map { item -> DesktopCustomerProfile in
            let object = try WBContract.object(item)
            guard let accountValues = object["accounts"]?.array, let companyValues = object["companies"]?.array else {
                throw WBError.invalidResponse("客户目录缺少账号或企业")
            }
            let accounts = try accountValues.map { value -> WBActor in
                let account = try WBContract.actor(value)
                guard account.role == "customer", manage || account.id == actor.id && account.companyId == actor.companyId else {
                    throw WBError.invalidResponse("客户目录包含越权账号")
                }
                return account
            }
            let companies = try companyValues.map { value -> DesktopCustomerCompany in
                let company = try WBContract.object(value)
                return DesktopCustomerCompany(id: try WBContract.text(company, "id", nonempty: true), name: try WBContract.text(company, "name", nonempty: true))
            }
            guard accounts.allSatisfy({ account in companies.contains(where: { $0.id == account.companyId }) }) else {
                throw WBError.invalidResponse("客户账号与企业不匹配")
            }
            return DesktopCustomerProfile(id: try WBContract.text(object, "id", nonempty: true), name: try WBContract.text(object, "name", nonempty: true), accounts: accounts, companies: companies)
        }
        profiles = received
        canManage = manage
        if let customer = root["customerId"]?.string {
            selected = (customer, root["accountId"]?.string ?? "", root["companyId"]?.string ?? "")
        }
        revision += 1
    }

    private static func seedDemo(store: WBStore) -> [DesktopCustomerProfile] {
        guard let actor = store.actor else {
            return []
        }
        var rows: [DesktopCustomerProfile] = []
        for order in store.orders {
            if let index = rows.firstIndex(where: { $0.id == "demo-customer-" + order.companyId }) {
                if !rows[index].accounts.contains(where: { $0.id == order.customerId }) {
                    rows[index].accounts.append(WBActor(id: order.customerId, username: order.customerId, name: order.customer, role: "customer", companyId: order.companyId, status: "active", authVersion: 1))
                }
            } else {
                rows.append(DesktopCustomerProfile(id: "demo-customer-" + order.companyId, name: order.customer,
                    accounts: [WBActor(id: order.customerId, username: order.customerId, name: order.customer, role: "customer", companyId: order.companyId, status: "active", authVersion: 1)],
                    companies: [DesktopCustomerCompany(id: order.companyId, name: order.companyId)]))
            }
        }
        if actor.role == "customer" {
            rows = rows.compactMap { row in
                let own = row.accounts.filter { $0.id == actor.id && $0.companyId == actor.companyId }
                return own.isEmpty ? nil : DesktopCustomerProfile(id: row.id, name: row.name, accounts: own, companies: row.companies.filter { $0.id == actor.companyId })
            }
            if rows.isEmpty {
                rows = [DesktopCustomerProfile(id: "demo-customer-" + actor.companyId, name: actor.name, accounts: [actor], companies: [DesktopCustomerCompany(id: actor.companyId, name: actor.companyId)])]
            }
        }
        return rows
    }

    private func createDemo(_ body: [String: Any],
                            store: WBStore,
                            actor: WBActor) throws {
        let operation = body["operation"] as? String ?? ""
        var copy = profiles
        var customerID = body["customerId"] as? String ?? ""
        let name = (body["name"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if operation == "customer" {
            guard !name.isEmpty else {
                throw WBError.unavailable("客户名称必填")
            }
            customerID = "demo-customer-" + UUID().uuidString
            copy.append(DesktopCustomerProfile(id: customerID, name: name, accounts: [], companies: []))
        }
        guard let index = copy.firstIndex(where: { $0.id == customerID }) else {
            throw WBError.unavailable("请选择有效客户档案")
        }
        var companyID = body["companyId"] as? String ?? ""
        var accountID = ""
        if operation == "company" || operation == "customer" {
            let companyName = operation == "company" ? name : body["companyName"] as? String ?? ""
            guard !companyName.isEmpty else {
                throw WBError.unavailable("企业名称必填")
            }
            companyID = "demo-company-" + UUID().uuidString
            copy[index].companies.append(DesktopCustomerCompany(id: companyID, name: companyName))
        }
        if operation == "account" || operation == "customer" {
            let username = (body["username"] as? String ?? "").trimmingCharacters(in: .whitespaces)
            let password = body["password"] as? String ?? ""
            guard username.count >= 3, password.count >= 8, password == body["confirmPassword"] as? String,
                  copy[index].companies.contains(where: { $0.id == companyID }),
                  !copy.flatMap(\.accounts).contains(where: { $0.username.lowercased() == username.lowercased() }) else {
                throw WBError.unavailable("请选本客户企业，填写有效用户名和至少8字符的一致密码")
            }
            accountID = "ios-demo-customer-" + UUID().uuidString
            let requestedName = (body["accountName"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            copy[index].accounts.append(WBActor(id: accountID, username: username, name: requestedName.isEmpty ? copy[index].name : requestedName, role: "customer", companyId: companyID, status: "active", authVersion: 1))
        }
        profiles = copy
        selected = (customerID, accountID, companyID)
        Self.demoProfiles[store.endpoint + ":" + actor.id] = copy
        revision += 1
    }
}
