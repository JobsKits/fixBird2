//
//  WBInitialMedia.swift
//  RepairWorkbench
//
//  Created by Jobs on 2026年11月18日，星期三.
//

import Foundation

#if canImport(CryptoKit)
    import CryptoKit
#endif

enum WBInitialMedia {

    static func confirm(order: WBOrder,
                        submitted: [[String: Any]]) throws {
        var matched = Set<String>()
        for file in submitted {
            guard let name = file["name"] as? String,
                  let mime = file["mime"] as? String else {
                throw WBError.invalidResponse("设备附件提交内容无法核对")
            }
            let digest: String
            let size: Int64
            if let uploadID = file["uploadId"] as? String, !uploadID.isEmpty,
               let bytes = file["size"] as? NSNumber, bytes.int64Value > 0,
               let sha = file["sha256"] as? String, sha.count == 64,
               sha.allSatisfy({ "0123456789abcdef".contains($0) }) {
                digest = sha
                size = bytes.int64Value
            } else if let encoded = file["dataBase64"] as? String, let data = Data(base64Encoded: encoded) {
                #if canImport(CryptoKit)
                    digest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
                #else
                    digest = ""
                #endif
                size = Int64(data.count)
            } else {
                throw WBError.invalidResponse("设备附件提交内容无法核对")
            }
            guard let evidence = order.evidence.first(where: { item in
                !matched.contains(item.id) && item.string("name") == name && item.string("mime") == mime
                    && item.string("kind") == (mime.hasPrefix("video/") ? "video" : "image")
                    && !item.bool("deleted") && (digest.isEmpty || item.string("sha256") == digest)
                    && (file["uploadId"] == nil || item.int("size") == size)
            }) else {
                throw WBError.invalidResponse("服务端未确认全部设备附件，保留原请求意图以便核对重试")
            }
            matched.insert(evidence.id)
        }
    }
}
