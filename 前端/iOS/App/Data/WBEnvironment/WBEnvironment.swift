//
//  WBEnvironment.swift
//  RepairWorkbench
//
//  Created by Jobs on 2026年10月15日，星期四.
//

import Foundation

#if canImport(JobsSwiftFoundation)
    import JobsSwiftFoundation
#endif

struct WBEnvironment {
    let endpoint: String
    let timeout: TimeInterval
    let editable: Bool

    static func current() -> WBEnvironment {
        #if DEBUG
            let arguments = ProcessInfo.processInfo.arguments
            var value = UserDefaults.standard.string(forKey: "wb.debug.endpoint") ?? "http://127.0.0.1:8098"
            if let position = arguments.firstIndex(of: "--wb-api-url"), position + 1 < arguments.count {
                value = arguments[position + 1]
            }
            let savedTimeout = UserDefaults.standard.double(forKey: "wb.debug.timeout")
            return WBEnvironment(endpoint: value, timeout: savedTimeout > 0 ? savedTimeout : 2.5, editable: true)
        #else
            let value = Bundle.main.object(forInfoDictionaryKey: "WBProductionAPIURL") as? String ?? ""
            let valid = (try? validate(value, requireHTTPS: true)) ?? ""
            return WBEnvironment(endpoint: valid, timeout: 2.5, editable: false)
        #endif
    }

    static func validate(_ input: String, requireHTTPS: Bool) throws -> String {
        let value = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.isEmpty {
            return ""
        }
        guard let url = URLComponents(string: value), let scheme = url.scheme?.lowercased(),
            ["http", "https"].contains(scheme), !requireHTTPS || scheme == "https", url.host?.isEmpty == false,
            url.user == nil, url.password == nil, url.query == nil, url.fragment == nil,
            url.path.isEmpty || url.path == "/"
        else {
            throw WBError.unavailable("服务地址须为不含凭据、路径或查询的 HTTP(S) 地址")
        }
        return value.hasSuffix("/") ? String(value.dropLast()) : value
    }

    static func saveDebug(endpoint: String, timeout: TimeInterval) {
        #if DEBUG
            #if canImport(JobsSwiftFoundation)
                UserDefaults.standard.setString(endpoint, forKey: "wb.debug.endpoint")
                UserDefaults.standard.setDouble(timeout, forKey: "wb.debug.timeout")
            #else
                UserDefaults.standard.set(endpoint, forKey: "wb.debug.endpoint")
                UserDefaults.standard.set(timeout, forKey: "wb.debug.timeout")
            #endif
        #endif
    }
}
