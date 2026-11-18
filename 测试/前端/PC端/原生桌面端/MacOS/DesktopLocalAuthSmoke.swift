//
//  DesktopLocalAuthSmoke.swift
//  RepairDesktopTests
//
//  Created by Jobs on 2026年11月18日，星期三.
//

import Foundation

@main struct DesktopLocalAuthSmoke {

    @MainActor static func main() async throws {
        let mode = CommandLine.arguments[1]
        let model = DesktopModel()
        model.refreshDemoAvailability()
        for _ in 0..<200 {
            try await Task.sleep(nanoseconds: 10_000_000)
            if model.localDemoAvailable || mode == "production" {
                break
            }
        }
        if mode == "production" {
            try await Task.sleep(nanoseconds: 100_000_000)
            precondition(!model.localDemoAvailable)
            do {
                _ = try await request(model, "/auth/email-code", ["email": "no-demo@example.test", "purpose": "register"])
                fatalError("Production must not generate a local demo code")
            } catch {}
            print("PASS local auth: explicit production denies transport fallback")
            return
        }
        precondition(model.localDemoAvailable)
        let realm = DesktopLocalDemoAuth.realm(endpoint: model.store.endpoint)
        let email = "new-local@example.test"
        let issued = try realm.perform(path: "/auth/email-code", body: ["email": email, "purpose": "register"])
        let body: [String: Any] = ["email": email, "username": "local_registered", "name": "本地新客户", "code": issued.object!["demoCode"]!.string!, "password": "LocalPassword1!", "confirmPassword": "LocalPassword1!"]
        if mode == "rejection" {
            _ = try realm.perform(path: "/register", body: body)
            do {
                _ = try await request(model, "/register", body)
                fatalError("401 must never fall back to local registration")
            } catch let failure as WBError {
                precondition(failure.isUnauthorized)
            }
            do {
                try await login(model, username: "local_registered", password: "LocalPassword1!")
                fatalError("401 must never fall back to an existing local account")
            } catch {
                precondition(model.store.actor == nil)
            }
            print("PASS local auth: genuine HTTP401 rejects registration and cached local credentials")
            return
        }
        // The UI-facing API still tries the unavailable server before using its isolated realm.
        _ = try await request(model, "/register", body)
        do {
            try await login(model, username: "local_registered", password: "incorrect-password")
            fatalError("Wrong local password accepted")
        } catch {
            precondition(model.store.actor == nil)
        }
        try await login(model, username: "local_registered", password: "LocalPassword1!")
        let actor = model.store.actor!
        precondition(actor.role == "customer" && actor.id.hasPrefix("desktop-local-customer-") && model.store.orders.isEmpty && model.store.loans.isEmpty)
        model.store.refresh()
        try await Task.sleep(nanoseconds: 150_000_000)
        precondition(model.store.actor?.matches(actor) == true && model.store.orders.isEmpty)
        let order: WBOrder = try await withCheckedThrowingContinuation { continuation in
            model.store.createOrder(input: WBOrderInput().byCustomer(actor.name).byDevice("本地客户自己的设备").byDescription("仅独立演示")) {
                continuation.resume(with: $0)
            }
        }
        precondition(order.customerId == actor.id && order.companyId == actor.companyId && model.store.orders.count == 1)
        model.store.refresh()
        try await Task.sleep(nanoseconds: 150_000_000)
        precondition(model.store.actor?.matches(actor) == true && model.store.orders.count == 1)
        let reset = try await request(model, "/auth/email-code", ["email": email, "purpose": "reset_password"])
        _ = try await request(model, "/reset-password", ["email": email, "code": reset.object!["demoCode"]!.string!, "password": "LocalPassword2!", "confirmPassword": "LocalPassword2!"])
        precondition(model.store.actor == nil)
        do {
            try await login(model, username: email, password: "LocalPassword1!")
            fatalError("Old password survived reset")
        } catch {
            precondition(model.store.actor == nil)
        }
        try await login(model, username: email, password: "LocalPassword2!")
        precondition(model.store.actor?.id == actor.id && model.store.actor!.authVersion > actor.authVersion)

        let clocked = DesktopLocalDemoAuth()
        var clock = Date()
        clocked.now = { clock }
        let sample = try clocked.perform(path: "/auth/email-code", body: ["email": "rate@example.test", "purpose": "register"])
        do {
            _ = try clocked.perform(path: "/auth/email-code", body: ["email": "rate@example.test", "purpose": "register"])
            fatalError("60-second cooldown escaped")
        } catch {}
        let sampleCode = sample.object!["demoCode"]!.string!
        var invalid = body
        invalid["email"] = "rate@example.test"
        invalid["code"] = sampleCode == "999999" ? "000000" : "999999"
        for _ in 0..<5 {
            do {
                _ = try clocked.perform(path: "/register", body: invalid)
                fatalError("Wrong code accepted")
            } catch {}
        }
        invalid["code"] = sampleCode
        do {
            _ = try clocked.perform(path: "/register", body: invalid)
            fatalError("Five-attempt budget escaped")
        } catch {}
        let expiring = try clocked.perform(path: "/auth/email-code", body: ["email": "expiry@example.test", "purpose": "register"])
        invalid["email"] = "expiry@example.test"
        invalid["code"] = expiring.object!["demoCode"]!.string!
        clock = clock.addingTimeInterval(601)
        do {
            _ = try clocked.perform(path: "/register", body: invalid)
            fatalError("10-minute expiry escaped")
        } catch {}
        print("PASS local auth: API-first offline register/login/reset, wrong-password rejection, isolated empty customer, refresh identity, session revocation, cooldown/attempt/expiry")
    }

    @MainActor static func request(_ model: DesktopModel,
                                  _ path: String,
                                  _ body: [String: Any]) async throws -> WBJSON {
        return try await withCheckedThrowingContinuation { continuation in
            model.authRequest(path: path, body: body) {
                continuation.resume(with: $0)
            }
        }
    }

    @MainActor static func login(_ model: DesktopModel,
                                username: String,
                                password: String) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            model.login(username: username, password: password) {
                continuation.resume(with: $0)
            }
        }
    }
}
