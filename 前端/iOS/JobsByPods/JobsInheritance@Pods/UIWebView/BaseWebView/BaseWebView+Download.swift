//
//  BaseWebView+Download.swift
//  JobsInheritance
//
//  Created by Jobs on 2026年5月13日，星期三.
//

#if os(OSX)
import AppKit
#elseif os(iOS) || os(tvOS)
import UIKit
#endif

import WebKit

// ===== 下载（iOS 14.5+）=====
@available(iOS 14.5, *)
extension BaseWebView: WKDownloadDelegate {
    @MainActor
    public func download(_ download: WKDownload,
                         decideDestinationUsing response: URLResponse,
                         suggestedFilename: String,
                         completionHandler: @escaping (URL?) -> Void) {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(suggestedFilename)
        completionHandler(url)
    }

    @MainActor
    public func downloadDidFinish(_ download: WKDownload) {
        emitEvent("downloadFinish", payload: ["ok": true])
    }

    @MainActor
    public func download(_ download: WKDownload,
                         didFailWithError error: Error,
                         resumeData: Data?) {
        emitEvent("downloadError", payload: ["message": error.localizedDescription])
    }
}
// ===== 文档选择器代理（强引用由外层保持）=====
final class DocumentPickerDelegateProxy: NSObject, UIDocumentPickerDelegate {
    private let onFinish: ([URL]?) -> Void

    init(_ onFinish: @escaping ([URL]?) -> Void) {
        self.onFinish = onFinish
    }

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        onFinish(urls)
    }

    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        onFinish(nil)
    }
}
