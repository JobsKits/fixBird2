//
//  JobsDownloadValidator.swift
//  JobsNetworking
//
//  Created by Jobs on 2026年10月5日，星期一.
//

import Foundation
import CommonCrypto

enum JobsDownloadValidator {
    static func validate(_ url: URL, response: HTTPURLResponse, request: JobsDownloadRequest, token: JobsRequestToken? = nil) throws {
        if token?.isCancelled == true {
            throw JobsError.cancelled
        }
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        let actualCount = (attributes[.size] as? NSNumber)?.int64Value ?? -1
        var expectedCount = request.expectedByteCount
        if expectedCount == nil,
           response.value(forHTTPHeaderField: "Content-Encoding") == nil,
           response.expectedContentLength >= 0 {
            expectedCount = response.expectedContentLength
        }
        if let expectedCount, expectedCount != actualCount {
            throw JobsError.invalidRequest(reason: "Downloaded byte count differs from expected length")
        }
        if let expectedHash = request.expectedSHA256 {
            guard try sha256(url, isCancelled: {
                token?.isCancelled == true
            }) == expectedHash.lowercased() else {
                throw JobsError.invalidRequest(reason: "Downloaded SHA256 differs from expected digest")
            }
        }
    }

    static func sha256(_ url: URL, isCancelled: () -> Bool = {
        false
    }) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer {
            handle.closeFile()
        }
        var context = CC_SHA256_CTX()
        CC_SHA256_Init(&context)
        while true {
            if isCancelled() {
                throw JobsError.cancelled
            }
            let chunk: Data
            if #available(iOS 13.0, macOS 10.15.4, *) {
                chunk = try handle.read(upToCount: 1_024 * 1_024) ?? Data()
            } else {
                chunk = handle.readData(ofLength: 1_024 * 1_024)
            }
            if chunk.isEmpty {
                break
            }
            chunk.withUnsafeBytes { bytes in
                _ = CC_SHA256_Update(&context, bytes.baseAddress, CC_LONG(chunk.count))
            }
        }
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        CC_SHA256_Final(&hash, &context)
        return hash.map {
            String(format: "%02x", $0)
        }.joined()
    }
}
