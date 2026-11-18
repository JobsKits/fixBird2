//
//  WBDemoState+Loans.swift
//  RepairWorkbench
//
//  Created by Jobs on 2026年11月18日，星期三.
//

import Foundation

extension WBDemoState {
    func createLoan(payload: [String: Any]) throws {
        guard ["admin", "warehouse"].contains(actor.role),
            let partID = payload["partId"] as? String,
            let partIndex = parts.firstIndex(where: { $0.id == partID }),
            let count = payload["quantity"] as? Int, count > 0, count <= parts[partIndex].available,
            let borrower = payload["borrowerId"] as? String, borrower == "ios-demo-engineer",
            let due = payload["dueAt"] as? String, !due.isEmpty, WBFoundation.validDate(due),
            let note = payload["note"] as? String, !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            throw WBError.unavailable("请核对填写内容")
        }
        let orderID = payload["orderId"] as? String ?? ""
        guard orderID.isEmpty || orders.contains(where: { $0.id == orderID && $0.status != "completed" }) else {
            throw WBError.unavailable("请重新选择工单")
        }
        let proof = try loanProofs(payload: payload, stage: "borrow", quantity: count, condition: "")
        var loan = WBLoan(
            id: "demo-loan-" + UUID().uuidString, version: 1, orderId: orderID, partId: partID,
            partName: parts[partIndex].name, quantity: count, returnedGood: 0, returnedQuarantine: 0,
            consumed: 0, disposed: 0, outstanding: count, borrowerId: borrower, dueAt: due, transfers: [])
        loan.files = proof
        loan.createdAt = WBFoundation.now()
        parts[partIndex].available -= count
        loans.append(loan)
        refresh()
    }

    func returnLoan(id: String, version: Int, payload: [String: Any]) throws {
        guard ["admin", "warehouse"].contains(actor.role),
            let index = loans.firstIndex(where: { $0.id == id && $0.version == version }),
            let partIndex = parts.firstIndex(where: { $0.id == loans[index].partId }),
            let count = payload["quantity"] as? Int, count > 0, count <= loans[index].outstanding,
            let condition = payload["condition"] as? String, ["good", "quarantine"].contains(condition)
        else {
            throw WBError.unavailable("请核对填写内容")
        }
        let proof = try loanProofs(payload: payload, stage: "return", quantity: count, condition: condition)
        guard validLoanProofTotal(loans[index].files + proof) else {
            throw WBError.unavailable("图片最多8张，单张8MiB，总计32MiB")
        }
        loans[index].files += proof
        loans[index].outstanding -= count
        loans[index].version += 1
        if condition == "good" {
            loans[index].returnedGood += count
            parts[partIndex].available += count
        } else {
            loans[index].returnedQuarantine += count
            parts[partIndex].quarantine += count
        }
        var remaining = count
        loans[index].transfers = loans[index].transfers.map { record in
            var raw = record.raw
            let reduction = min(remaining, Int(record.int("quantity")))
            raw["quantity"] = .integer(record.int("quantity") - Int64(reduction))
            remaining -= reduction
            return WBRecord(raw: raw)
        }.filter { $0.int("quantity") > 0 }
        refresh()
    }

    func addLoanFiles(id: String, version: Int, payload: [String: Any]) throws {
        guard ["admin", "warehouse"].contains(actor.role),
            let index = loans.firstIndex(where: { $0.id == id && $0.version == version }),
            let stage = payload["stage"] as? String, ["borrow", "return"].contains(stage),
            let count = payload["quantity"] as? Int, count > 0, count <= loans[index].quantity
        else {
            throw WBError.unavailable("请核对填写内容")
        }
        let condition = payload["condition"] as? String ?? ""
        if stage == "return" {
            let returned = condition == "good" ? loans[index].returnedGood : condition == "quarantine" ? loans[index].returnedQuarantine : 0
            guard count <= returned else { throw WBError.unavailable("请核对填写内容") }
        }
        let proof = try loanProofs(payload: payload, stage: stage, quantity: count, condition: condition)
        guard validLoanProofTotal(loans[index].files + proof) else {
            throw WBError.unavailable("图片最多8张，单张8MiB，总计32MiB")
        }
        loans[index].files += proof
        loans[index].version += 1
    }

    func installLoanProofsIfAvailable() {
        guard let index = loans.firstIndex(where: { $0.id == "ios-demo-loan" }), loans[index].files.isEmpty else { return }
        for (resource, stage, count, condition) in [("LoanBorrow", "borrow", 2, ""), ("LoanReturn", "return", 1, "good")] {
            if let url = Bundle.main.url(forResource: resource, withExtension: "png"), let data = try? Data(contentsOf: url) {
                let payload: [String: Any] = ["attachments": [["name": resource + ".png", "mime": "image/png", "dataBase64": data.base64EncodedString()]]]
                if let files = try? loanProofs(payload: payload, stage: stage, quantity: count, condition: condition) {
                    loans[index].files += files
                }
            }
        }
    }

    private func loanProofs(payload: [String: Any], stage: String, quantity: Int, condition: String) throws -> [WBRecord] {
        guard let inputs = payload["attachments"] as? [[String: Any]], !inputs.isEmpty, inputs.count <= 8 else {
            throw WBError.unavailable("请至少选择一张图片凭据")
        }
        var total = 0
        return try inputs.map { item in
            guard let name = item["name"] as? String, !name.isEmpty,
                let mime = item["mime"] as? String, ["image/png", "image/jpeg", "image/gif"].contains(mime),
                let encoded = item["dataBase64"] as? String, let data = Data(base64Encoded: encoded),
                !data.isEmpty, data.count <= 8 * 1024 * 1024
            else {
                throw WBError.unavailable("仅支持 PNG、JPEG、GIF 图片")
            }
            total += data.count
            guard total <= 32 * 1024 * 1024 else { throw WBError.unavailable("图片最多8张，单张8MiB，总计32MiB") }
            return WBRecord(raw: [
                "id": .string("demo-proof-" + UUID().uuidString), "name": .string(name), "mime": .string(mime),
                "size": .integer(Int64(data.count)), "uploaderId": .string(actor.id), "createdAt": .string(WBFoundation.now()),
                "stage": .string(stage), "quantity": .integer(Int64(quantity)), "condition": .string(condition),
                "note": .string(payload["note"] as? String ?? ""), "dataBase64": .string(encoded)
            ])
        }
    }

    private func validLoanProofTotal(_ files: [WBRecord]) -> Bool {
        files.count <= 8 && files.reduce(Int64(0)) { $0 + $1.int("size") } <= 32 * 1024 * 1024
    }
}
