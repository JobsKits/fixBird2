//
//  DesktopFileTransfer.swift
//  RepairDesktop
//
//  Created by Jobs on 2026年11月18日，星期三.
//

import Foundation

// URLSession owns the body stream; only the small JSON receipt is accumulated in memory.
final class DesktopFileTransfer: NSObject, URLSessionDataDelegate, URLSessionDownloadDelegate, @unchecked Sendable {

    private let lock = NSLock()
    private var task: URLSessionTask?
    private var cancelled = false
    private var receipt = Data()
    private var output: DesktopMediaFile?
    private var downloadFailure: Error?
    private var continuation: CheckedContinuation<(Data, DesktopMediaFile?), Error>?
    private var progress: (@Sendable (Int64, Int64) -> Void)?
    private var session: URLSession?

    func upload(request: WBRequest, media: DesktopDeviceMedia,
                progress: @escaping @Sendable (Int64, Int64) -> Void) async throws -> [String: Any] {
        var wire = try Self.wire(request)
        wire.setValue(media.mime, forHTTPHeaderField: "Content-Type")
        wire.setValue(media.name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed.subtracting(CharacterSet(charactersIn: "/%?#"))), forHTTPHeaderField: "X-File-Name")
        wire.setValue(String(media.size), forHTTPHeaderField: "Content-Length")
        let result = try await run(wire: wire, file: media.url, progress: progress)
        guard let object = try JSONSerialization.jsonObject(with: result.0) as? [String: Any],
              let id = object["id"] as? String, !id.isEmpty,
              object["name"] as? String == media.name, object["mime"] as? String == media.mime,
              (object["size"] as? NSNumber)?.int64Value == media.size,
              object["sha256"] as? String == media.sha256 else {
            throw WBError.invalidResponse("文件原件校验失败")
        }
        return object
    }

    func download(request: WBRequest,
                  progress: @escaping @Sendable (Int64, Int64) -> Void) async throws -> DesktopMediaFile {
        let result = try await run(wire: Self.wire(request), file: nil, progress: progress)
        guard let file = result.1 else {
            throw WBError.invalidResponse("文件原件校验失败")
        }
        return file
    }

    private static func wire(_ request: WBRequest) throws -> URLRequest {
        guard let url = URL(string: request.endpoint + "/api/v38" + request.path) else {
            throw WBError.unavailable("服务地址尚未配置")
        }
        // This is an inactivity timeout, not a limit on total file transfer duration.
        var wire = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: max(request.timeout, 30))
        wire.httpMethod = request.method
        wire.allHTTPHeaderFields = request.headers
        return wire
    }

    private func run(wire: URLRequest, file: URL?,
                     progress: @escaping @Sendable (Int64, Int64) -> Void) async throws -> (Data, DesktopMediaFile?) {
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                lock.lock()
                if cancelled {
                    lock.unlock()
                    continuation.resume(throwing: CancellationError())
                    return
                }
                self.continuation = continuation
                self.progress = progress
                let configuration = URLSessionConfiguration.ephemeral
                configuration.timeoutIntervalForRequest = wire.timeoutInterval
                configuration.timeoutIntervalForResource = 7 * 24 * 60 * 60
                let session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
                self.session = session
                let next: URLSessionTask
                if let file {
                    next = session.uploadTask(with: wire, fromFile: file)
                } else {
                    next = session.downloadTask(with: wire)
                }
                task = next
                lock.unlock()
                next.resume()
            }
        } onCancel: {
            self.cancel()
        }
    }

    func cancel() {
        lock.lock()
        cancelled = true
        let active = task
        lock.unlock()
        active?.cancel()
    }

    func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest,
                    completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(nil)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64,
                    totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
        progress?(totalBytesSent, totalBytesExpectedToSend)
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        guard receipt.count + data.count <= 256 * 1024 else {
            downloadFailure = WBError.invalidResponse("文件原件校验失败")
            dataTask.cancel()
            return
        }
        receipt.append(data)
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64,
                    totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        progress?(totalBytesWritten, totalBytesExpectedToWrite)
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        do {
            let directory = FileManager.default.temporaryDirectory.appendingPathComponent("repair-download-" + UUID().uuidString)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let filename = downloadTask.response?.suggestedFilename ?? "attachment"
            let file = DesktopMediaFile(url: directory.appendingPathComponent(URL(fileURLWithPath: filename).lastPathComponent))
            try FileManager.default.moveItem(at: location, to: file.url)
            output = file
        } catch {
            downloadFailure = error
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        let result: Result<(Data, DesktopMediaFile?), Error>
        if let failure = downloadFailure {
            result = .failure(failure)
        } else if let error {
            result = .failure((error as NSError).code == NSURLErrorCancelled ? CancellationError() : WBError.transport("网络请求未完成，请检查服务连接"))
        } else if let http = task.response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            let value = (try? JSONSerialization.jsonObject(with: receipt)) as? [String: Any]
            result = .failure(WBError.server(http.statusCode, value?["error"] as? String ?? "http_error", value?["message"] as? String ?? "HTTP \(http.statusCode)"))
        } else if task.response is HTTPURLResponse {
            result = .success((receipt, output))
        } else {
            result = .failure(WBError.invalidResponse("文件原件校验失败"))
        }
        lock.lock()
        let pending = continuation
        continuation = nil
        self.task = nil
        self.session = nil
        lock.unlock()
        session.finishTasksAndInvalidate()
        pending?.resume(with: result)
    }
}
