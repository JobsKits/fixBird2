//
//  BaseWebView+UIDelegate.swift
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
import SafariServices
import JobsByUIKit
import JobsSwiftDSL
import SnapKit

#if canImport(UniformTypeIdentifiers)
import UniformTypeIdentifiers
#endif

extension BaseWebView: WKUIDelegate {
    @MainActor
    public func webView(_ webView: WKWebView,
                        runJavaScriptAlertPanelWithMessage message: String,
                        initiatedByFrame frame: WKFrameInfo,
                        completionHandler: @escaping () -> Void) {
        UIAlertController
            .makeAlert("提示".tr, message)
            .byAddOK { _ in completionHandler() }
            .byData("Jobs")
            .onResult { name in print("回来了 \(String(describing: name))") }
            .byPresent(presentingVC)
    }

    @MainActor
    public func webView(_ webView: WKWebView,
                        runJavaScriptConfirmPanelWithMessage message: String,
                        initiatedByFrame frame: WKFrameInfo,
                        completionHandler: @escaping (Bool) -> Void) {
        UIAlertController
            .makeAlert("确认".tr, message)
            .byAddCancel { _ in completionHandler(false) }
            .byAddOK { _ in completionHandler(true) }
            .byData("Jobs")
            .onResult { name in print("回来了 \(String(describing: name))") }
            .byPresent(presentingVC)
    }

    @MainActor
    public func webView(_ webView: WKWebView,
                        runJavaScriptTextInputPanelWithPrompt prompt: String,
                        defaultText: String?,
                        initiatedByFrame frame: WKFrameInfo,
                        completionHandler: @escaping (String?) -> Void) {
        UIAlertController
            .makeAlert("确认".tr, prompt)
            .byAddTextField { tf in
                tf.byText(defaultText)
            }
            .byAddCancel { _ in completionHandler(nil) }
            .byAddOK { _ in completionHandler(nil) }
            .byData("Jobs")
            .onResult { name in print("回来了 \(String(describing: name))") }
            .byPresent(presentingVC)
    }
    /// iOS 18.4+ 自定义文件选择
    @available(iOS 18.4, *)
    @MainActor
    public func webView(_ webView: WKWebView,
                        runOpenPanelWith parameters: WKOpenPanelParameters,
                        initiatedByFrame frame: WKFrameInfo,
                        completionHandler: @escaping ([URL]?) -> Void) {
        var types: [UTType] = [.item]
        if parameters.allowsDirectories { types = [.folder] }
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: types)
        picker.byAllowsMultipleSelection(parameters.allowsMultipleSelection)
        let proxy = DocumentPickerDelegateProxy { [weak self] urls in
            completionHandler(urls)
            self?.docPickerDelegate = nil
        }
        docPickerDelegate = proxy
        picker.byDelegate(proxy)
        picker.modalPresentationStyle = .formSheet
        presentingVC?.present(picker, animated: true)
    }
}
