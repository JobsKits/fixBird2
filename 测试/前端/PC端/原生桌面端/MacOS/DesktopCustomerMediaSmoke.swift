//
//  DesktopCustomerMediaSmoke.swift
//  RepairDesktopTests
//
//  Created by Jobs on 2026年11月18日，星期三.
//

import Foundation

@main struct DesktopCustomerMediaSmoke {

    @MainActor static func main() async throws {
        guard CommandLine.arguments.count == 4,
              let components = URLComponents(string: CommandLine.arguments[1]),
              components.host == "127.0.0.1", let port = components.port, port != 8098 else {
            fatalError("Use an isolated loopback backend, plus synthetic PNG and MP4 paths")
        }
        let store = WBStore(transport: WBJobsTransport(), environment: WBEnvironment(endpoint: CommandLine.arguments[1], timeout: 10, editable: true))
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            store.login(username: "admin", password: "1234") {
                continuation.resume(with: $0)
            }
        }
        let suffix = UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(10)
        let created = try await call(store, body: ["operation": "customer", "name": "原生客户目录夹具", "companyName": "第一企业", "username": "native_" + suffix, "password": "NativePassword!", "confirmPassword": "NativePassword!"])
        let profileID = created.object!["customerId"]!.string!
        let company = try await call(store, body: ["operation": "company", "customerId": profileID, "name": "第二企业"])
        let companyID = company.object!["companyId"]!.string!
        let account = try await call(store, body: ["operation": "account", "customerId": profileID, "companyId": companyID, "username": "second_" + suffix, "password": "NativePassword!", "confirmPassword": "NativePassword!"])
        let accountID = account.object!["accountId"]!.string!
        let directory = try await call(store)
        let profile = directory.object!["customers"]!.array!.first { $0.object?["id"]?.string == profileID }!
        precondition(profile.object!["accounts"]!.array!.count == 2 && profile.object!["companies"]!.array!.count == 2)
        let image = try Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[2]))
        let video = try Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[3]))
        var input = WBOrderInput().byCustomer("原生客户目录夹具").byCustomerId(accountID).byCompanyId(companyID).byDevice("原生设备图片视频夹具").byDescription("独立HTTP回归")
        input.files = [
            ["name": "设备.png", "mime": "image/png", "dataBase64": image.base64EncodedString()],
            ["name": "设备.mp4", "mime": "video/mp4", "dataBase64": video.base64EncodedString()],
        ]
        let order: WBOrder = try await withCheckedThrowingContinuation { continuation in
            store.createOrder(input: input) {
                continuation.resume(with: $0)
            }
        }
        precondition(order.customerId == accountID && order.companyId == companyID && order.evidence.count == 2)
        try WBInitialMedia.confirm(order: order, submitted: input.files)
        var stripped = order
        stripped.raw["evidence"] = .array([])
        do {
            try WBInitialMedia.confirm(order: stripped, submitted: input.files)
            fatalError("Missing media confirmation must not succeed")
        } catch {}
        print("PASS native customer directory: new customer, second company/account, linked order with original image/video and SHA confirmation")
    }

    @MainActor static func call(_ store: WBStore,
                               body: [String: Any]? = nil) async throws -> WBJSON {
        return try await withCheckedThrowingContinuation { continuation in
            store.send(path: "/customer-directory", method: body == nil ? "GET" : "POST", body: body, intent: body != nil) {
                continuation.resume(with: $0)
            }
        }
    }
}
