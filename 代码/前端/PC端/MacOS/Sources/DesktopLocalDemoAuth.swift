//
//  DesktopLocalDemoAuth.swift
//  RepairDesktop
//
//  Created by Jobs on 2026年11月18日，星期三.
//

import CryptoKit
import Foundation

@MainActor final class DesktopLocalDemoAuth {

    private struct Account {

        var actor: WBActor
        let email: String
        let salt: String
        var hash: SHA256.Digest
    }

    private struct Challenge {

        let code: String
        let issued: Date
        var attempts = 0
    }

    private final class Session {

        weak var store: WBStore?

        init(_ store: WBStore) {
            self.store = store
        }
    }

    private static var realms: [String: DesktopLocalDemoAuth] = [:]
    private var accounts: [String: Account] = [:]
    private var challenges: [String: Challenge] = [:]
    private var sessions: [Session] = []
    var now: () -> Date = Date.init

    static func realm(endpoint: String) -> DesktopLocalDemoAuth {
        if let existing = realms[endpoint] {
            return existing
        }
        let created = DesktopLocalDemoAuth()
        realms[endpoint] = created
        return created
    }

    func perform(path: String,
                 body: [String: Any]) throws -> WBJSON {
        if path == "/auth/email-code" {
            let email = try normalizedEmail(body["email"] as? String ?? "")
            let purpose = body["purpose"] as? String ?? ""
            guard ["register", "reset_password"].contains(purpose) else {
                throw WBError.unavailable("请输入有效邮箱地址")
            }
            challenges = challenges.filter { now().timeIntervalSince($0.value.issued) < 600 }
            let key = email + ":" + purpose
            if let previous = challenges[key], now().timeIntervalSince(previous.issued) < 60 {
                throw WBError.server(429, "rate_limit", "请求过于频繁，请稍后重试")
            }
            guard challenges.count < 1000 else {
                throw WBError.server(429, "rate_limit", "请求过于频繁，请稍后重试")
            }
            let code = String(format: "%06d", Int.random(in: 0...999999))
            challenges[key] = Challenge(code: code, issued: now())
            return try WBFoundation.json(["ok": true, "delivery": "demo", "demoCode": code, "expiresIn": 600, "retryAfter": 60])
        }
        guard path == "/register" || path == "/reset-password" else {
            throw WBError.unavailable("服务连接不可用，请重试")
        }
        let email = try normalizedEmail(body["email"] as? String ?? "")
        let password = body["password"] as? String ?? ""
        guard password.count >= 8, password.utf8.count <= 256, password == body["confirmPassword"] as? String else {
            throw WBError.unavailable("密码须至少8个字符、最多256字节，两次输入须一致")
        }
        guard !DesktopPasswordPolicy.containsEmoji(password),
              !DesktopPasswordPolicy.containsEmoji(body["confirmPassword"] as? String ?? "") else {
            throw WBError.unavailable("密码不能包含表情符号")
        }
        let reset = path == "/reset-password"
        let purpose = reset ? "reset_password" : "register"
        try verify(email: email, purpose: purpose, code: body["code"] as? String ?? "")
        if reset {
            guard var existing = accounts[email] else {
                throw WBError.unavailable("邮箱验证码无效或已过期")
            }
            existing.hash = SHA256.hash(data: Data((existing.salt + password).utf8))
            let old = existing.actor
            existing.actor = WBActor(id: old.id, username: old.username, name: old.name, role: "customer", companyId: old.companyId, status: "active", authVersion: old.authVersion + 1)
            accounts[email] = existing
            for session in sessions {
                if session.store?.actor?.id == old.id {
                    session.store?.logout()
                }
            }
            sessions.removeAll { $0.store == nil }
        } else {
            let username = (body["username"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            var name = (body["name"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard (3...32).contains(username.count), username.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "_" || $0 == "-" }), name.count <= 80 else {
                throw WBError.unavailable("用户名须为3至32个字母、汉字、数字、下划线或短横线，姓名最多80个字符")
            }
            guard accounts.count < 1000, accounts[email] == nil, !WBActor.roles.contains(username), !["customer-peer", "customer-b"].contains(username), !accounts.values.contains(where: { $0.actor.username == username }) else {
                throw WBError.server(409, "account_exists", "该用户名或邮箱已被使用")
            }
            if name.isEmpty {
                name = username
            }
            let salt = UUID().uuidString
            let actor = WBActor(id: "desktop-local-customer-" + UUID().uuidString, username: username, name: name, role: "customer", companyId: "desktop-local-company-" + UUID().uuidString, status: "active", authVersion: 1)
            accounts[email] = Account(actor: actor, email: email, salt: salt, hash: SHA256.hash(data: Data((salt + password).utf8)))
        }
        challenges.removeValue(forKey: email + ":" + purpose)
        return try WBFoundation.json(["ok": true, "message": reset ? "密码已重置，请登录" : "注册成功，请登录"])
    }

    func login(username: String,
               password: String) throws -> WBActor {
        guard !DesktopPasswordPolicy.containsEmoji(password) else {
            throw WBError.unavailable("密码不能包含表情符号")
        }
        let account = username.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard let saved = accounts.values.first(where: { $0.email == account || $0.actor.username == account }),
              saved.hash == SHA256.hash(data: Data((saved.salt + password).utf8)) else {
            throw WBError.server(401, "invalid_credentials", "账号或密码错误")
        }
        return saved.actor
    }

    func registerSession(_ store: WBStore) {
        sessions.removeAll { $0.store == nil || $0.store === store }
        sessions.append(Session(store))
    }

    private func normalizedEmail(_ value: String) throws -> String {
        let email = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard email.utf8.count <= 254, email.range(of: "^[^\\s@]+@[^\\s@]+\\.[^\\s@]+$", options: .regularExpression) != nil else {
            throw WBError.unavailable("请输入有效邮箱地址")
        }
        return email
    }

    private func verify(email: String,
                        purpose: String,
                        code: String) throws {
        let key = email + ":" + purpose
        guard var challenge = challenges[key], now().timeIntervalSince(challenge.issued) < 600, challenge.attempts < 5 else {
            throw WBError.unavailable("邮箱验证码无效或已过期")
        }
        challenge.attempts += 1
        challenges[key] = challenge
        guard challenge.code == code else {
            throw WBError.unavailable("邮箱验证码无效或已过期")
        }
    }
}
