//
//  MediaFoundationTests.swift
//  RepairDesktopTests
//
//  Created by Jobs on 2026年11月18日，星期三.
//

import CryptoKit
import Foundation

@main
@MainActor
struct MediaFoundationTests {
    private static let png = Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jmeQAAAAASUVORK5CYII=")!

    private static func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
        guard condition() else {
            throw WBError.invalidResponse("测试断言失败：" + message)
        }
    }

    private static func rejects(_ message: String, _ work: () throws -> Void) throws {
        do {
            try work()
        } catch {
            return
        }
        throw WBError.invalidResponse("测试断言失败：" + message)
    }

    private static func file(_ id: String = "proof-1", size: Int64 = 1) -> [String: WBJSON] {
        [
            "id": .string(id), "name": .string("synthetic.png"), "mime": .string("image/png"),
            "size": .integer(size), "uploaderId": .string("user-warehouse"),
            "createdAt": .string("2026-11-18T01:00:00Z"), "stage": .string("borrow"),
            "quantity": .integer(1),
        ]
    }

    private static func loan(_ files: [[String: WBJSON]]) -> WBJSON {
        var raw = WBFixture.loan().object!
        raw["files"] = .array(files.map(WBJSON.object))
        return .object(raw)
    }

    private static func attachment(data: Data? = nil) -> [String: Any] {
        let original = data ?? png
        return ["name": "synthetic.png", "mime": "image/png", "dataBase64": original.base64EncodedString()]
    }

    private static func evidence(_ id: String = "file-1", digest: String? = nil) -> WBJSON {
        .object([
            "id": .string(id), "name": .string("synthetic.png"), "mime": .string("image/png"),
            "kind": .string("image"), "sha256": .string(digest ?? SHA256.hash(data: png).map { String(format: "%02x", $0) }.joined()),
            "deleted": .boolean(false), "public": .boolean(true), "stage": .string("pending_intake"),
            "uploaderId": .string("user-admin"), "createdAt": .string("2026-11-18T01:00:00Z"),
        ])
    }

    private static func loanMetadataBoundaries() throws {
        let valid = try WBContract.loan(loan([file()]))
        try expect(valid.files.count == 1 && valid.files[0].string("name") == "synthetic.png", "合法元数据丢失")
        _ = try WBContract.loan(WBFixture.loan())
        for leaked in [WBJSON.string("private-original"), .null] {
            var item = file()
            item["dataBase64"] = leaked
            try rejects("真实借还响应接受了私有原件字段") {
                _ = try WBContract.loan(loan([item]))
            }
        }
        try rejects("接受了重复的图片编号") {
            _ = try WBContract.loan(loan([file(), file()]))
        }
        for bytes: Int64 in [0, 8 * 1024 * 1024 + 1] {
            try rejects("单图大小限制失效") {
                _ = try WBContract.loan(loan([file(size: bytes)]))
            }
        }
        let exact = (0..<4).map { file("proof-\($0)", size: 8 * 1024 * 1024) }
        _ = try WBContract.loan(loan(exact))
        try rejects("总图片字节数超过32MiB仍被接受") {
            _ = try WBContract.loan(loan(exact + [file("extra", size: 1)]))
        }
        try rejects("超过8张图片仍被接受") {
            _ = try WBContract.loan(loan((0..<9).map { file("proof-\($0)") }))
        }
        for (key, value) in [
            ("mime", WBJSON.string("text/plain")), ("stage", .string("unknown")),
            ("quantity", .integer(3)), ("createdAt", .string("invalid-date")),
            ("size", .number(1)),
        ] {
            var item = file()
            item[key] = value
            try rejects("非法图片字段被接受：" + key) {
                _ = try WBContract.loan(loan([item]))
            }
        }
        var returned = file()
        returned["stage"] = .string("return")
        try rejects("归还图片没有成色也被接受") {
            _ = try WBContract.loan(loan([returned]))
        }
        returned["condition"] = .string("good")
        _ = try WBContract.loan(loan([returned]))
    }

    private static func demoPartialReturnsConserveInventory() throws {
        let demo = WBDemoState(username: "warehouse")
        let originalPart = demo.parts[0]
        let payload: [String: Any] = [
            "partId": originalPart.id, "quantity": 3, "borrowerId": "ios-demo-engineer",
            "dueAt": "2099-12-31T15:59:59Z", "note": "合成借出事实", "attachments": [attachment()],
        ]
        try demo.createLoan(payload: payload)
        let index = demo.loans.count - 1
        let id = demo.loans[index].id
        demo.loans[index].transfers = [WBRecord(raw: ["quantity": .integer(2)])]
        try expect(demo.parts[0].available == originalPart.available - 3, "借出未扣实际数量")
        try demo.returnLoan(id: id, version: 1, payload: ["quantity": 1, "condition": "good", "attachments": [attachment()]])
        try expect(demo.loans[index].outstanding == 2 && demo.loans[index].returnedGood == 1, "部分完好归还数量错误")
        try expect(demo.parts[0].available == originalPart.available - 2 && demo.parts[0].quarantine == originalPart.quarantine, "完好归还错误变更库存成色")
        try expect(demo.loans[index].transfers.reduce(Int64(0)) { $0 + $1.int("quantity") } == 1, "部分归还未减少独立跟踪数量")
        try demo.returnLoan(id: id, version: 2, payload: ["quantity": 1, "condition": "quarantine", "attachments": [attachment()]])
        let returned = demo.loans[index]
        try expect(returned.quantity == returned.outstanding + returned.returnedGood + returned.returnedQuarantine + returned.consumed + returned.disposed, "部分归还不守恒")
        try expect(returned.outstanding == 1 && returned.returnedGood == 1 && returned.returnedQuarantine == 1 && returned.transfers.isEmpty, "两次部分归还台账错误")
        try expect(demo.parts[0].available == originalPart.available - 2 && demo.parts[0].quarantine == originalPart.quarantine + 1, "隔离归还未进隔离库存")
        try expect(returned.files.count == 3 && returned.files.last?.string("stage") == "return" && returned.files.last?.int("quantity") == 1, "实际归还图片与数量未关联")
        let partsBefore = demo.parts
        let loansBefore = demo.loans
        try rejects("超过尚欠的归还被接受") {
            try demo.returnLoan(id: id, version: returned.version, payload: ["quantity": 2, "condition": "good", "attachments": [attachment()]])
        }
        try expect(demo.parts == partsBefore && demo.loans == loansBefore, "失败归还留下库存或图片半状态")
    }

    private static func demoMergedProofLimitsAreAtomic() throws {
        let demo = WBDemoState(username: "warehouse")
        var bytes = png
        bytes.append(Data(repeating: 0, count: 8 * 1024 * 1024 - bytes.count))
        let big = attachment(data: bytes)
        let before = demo.parts[0]
        try demo.createLoan(payload: [
            "partId": before.id, "quantity": 2, "borrowerId": "ios-demo-engineer",
            "dueAt": "2099-12-31T15:59:59Z", "note": "合成总量边界", "attachments": [big, big, big, big],
        ])
        let current = demo.loans.last!
        try expect(current.files.reduce(Int64(0)) { $0 + $1.int("size") } == 32 * 1024 * 1024, "合法32MiB边界未保留")
        let partsBefore = demo.parts
        let loansBefore = demo.loans
        try rejects("归还追加图片令总量超过32MiB仍成功") {
            try demo.returnLoan(id: current.id, version: current.version, payload: ["quantity": 1, "condition": "good", "attachments": [attachment()]])
        }
        try expect(demo.parts == partsBefore && demo.loans == loansBefore, "图片总量失败仍改变归还库存")
        try rejects("补录图片令总量超过32MiB仍成功") {
            try demo.addLoanFiles(id: current.id, version: current.version, payload: ["stage": "borrow", "quantity": 2, "attachments": [attachment()]])
        }
        try expect(demo.parts == partsBefore && demo.loans == loansBefore, "图片补录失败仍改变版本或图片")
        let compact = WBDemoState(username: "warehouse")
        try compact.createLoan(payload: [
            "partId": compact.parts[0].id, "quantity": 2, "borrowerId": "ios-demo-engineer",
            "dueAt": "2099-12-31T15:59:59Z", "note": "合成图片数量边界", "attachments": Array(repeating: attachment(), count: 8),
        ])
        let countLimited = compact.loans.last!
        let compactBefore = compact.loans
        let compactParts = compact.parts
        try rejects("借还合并超过8图仍成功") {
            try compact.returnLoan(id: countLimited.id, version: countLimited.version, payload: ["quantity": 1, "condition": "good", "attachments": [attachment()]])
        }
        try expect(compact.loans == compactBefore && compact.parts == compactParts, "图数超限仍改变台账")
    }

    private static func unknownWrite(_ result: Result<WBOrder, Error>?) -> Bool {
        guard case .failure(let error)? = result, let failure = error as? WBError else {
            return false
        }
        if case .unknownWrite = failure {
            return true
        }
        return false
    }

    private static func initialMediaRequiresConfirmedOriginals() throws {
        let (store, transport) = try WBFixture.signedIn()
        var input = WBOrderInput().byType("mail").byCustomer("合成客户").byCustomerId("user-customer")
            .byCompanyId("company-a").byDevice("合成设备").byDescription("合成附件回执验证")
        input.files = [attachment()]
        var raw = WBFixture.order("wo-created-with-media").object!
        raw["type"] = .string(input.type)
        raw["device"] = .string(input.device)
        raw["description"] = .string(input.description)
        var result: Result<WBOrder, Error>?
        store.createOrder(input: input) { result = $0 }
        raw["evidence"] = .array([])
        let missing = try transport.reply("/orders", .success(.object(raw)))
        try expect(unknownWrite(result), "新建响应缺少附件回执仍报告成功")
        try expect(!store.orders.contains { $0.id == "wo-created-with-media" }, "未确认附件的工单被采纳")
        store.createOrder(input: input) { result = $0 }
        raw["evidence"] = .array([evidence(digest: String(repeating: "0", count: 64))])
        let wrongSHA = try transport.reply("/orders", .success(.object(raw)))
        try expect(unknownWrite(result), "回执SHA与原件不符仍报告成功")
        try expect(missing.headers["Idempotency-Key"] == wrongSHA.headers["Idempotency-Key"], "未知附件提交重试更换了请求键")
        store.createOrder(input: input) { result = $0 }
        raw["evidence"] = .array([evidence()])
        let confirmed = try transport.reply("/orders", .success(.object(raw)))
        guard case .success(let saved)? = result else {
            throw WBError.invalidResponse("正确附件回执未确认成功")
        }
        try expect(saved.id == "wo-created-with-media" && saved.evidence.count == 1, "成功响应未保留附件元数据")
        try expect(missing.headers["Idempotency-Key"] == confirmed.headers["Idempotency-Key"], "原意图核对成功前更换了请求键")
        try transport.reply("/bootstrap", .success(WBFixture.bootstrap(orders: [.object(raw)])))
        try expect(!store.isBusy, "附件写入后忙态未收尾")
    }

    private static func initialMediaReceiptsAreOneToOne() throws {
        var raw = WBFixture.order().object!
        raw["evidence"] = .array([evidence()])
        let oneReceipt = try WBContract.order(.object(raw), full: true)
        try WBInitialMedia.confirm(order: oneReceipt, submitted: [attachment()])
        try rejects("同一附件回执被用于确认两个提交原件") {
            try WBInitialMedia.confirm(order: oneReceipt, submitted: [attachment(), attachment()])
        }
        var deleted = evidence().object!
        deleted["deleted"] = .boolean(true)
        raw["evidence"] = .array([.object(deleted)])
        let deletedOrder = try WBContract.order(.object(raw), full: true)
        try rejects("已删除的附件回执仍用于新建确认") {
            try WBInitialMedia.confirm(order: deletedOrder, submitted: [attachment()])
        }
        raw["evidence"] = .array([evidence("first"), evidence("second")])
        let distinctReceipts = try WBContract.order(.object(raw), full: true)
        try WBInitialMedia.confirm(order: distinctReceipts, submitted: [attachment(), attachment()])
    }

    static func main() {
        let cases: [(String, () throws -> Void)] = [
            ("真实借还元数据、私有原件拒绝、ID与限额", loanMetadataBoundaries),
            ("演示部分归还、完好隔离库存与独立跟踪守恒", demoPartialReturnsConserveInventory),
            ("演示借还合并图片32MiB与8图原子失败", demoMergedProofLimitsAreAtomic),
            ("初始媒体回执缺失或SHA不符保持未知且原键重试", initialMediaRequiresConfirmedOriginals),
            ("初始媒体回执一一对应及删除记录拒绝", initialMediaReceiptsAreOneToOne),
        ]
        var failures = 0
        for (name, run) in cases {
            do {
                try run()
                print("PASS " + name)
            } catch {
                failures += 1
                print("FAIL " + name + ": " + error.localizedDescription)
            }
        }
        print("RESULT media-groups=\(cases.count) failures=\(failures) skips=0")
        if failures > 0 {
            exit(1)
        }
    }
}
