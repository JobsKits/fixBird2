//
//  WKWebView.swift
//  JobsByWebKit
//
//  Created by Jobs on 2026年5月13日，星期三.
//

#if os(OSX)
import AppKit
#elseif os(iOS) || os(tvOS)
import UIKit
#endif

import WebKit
import JobsSwiftBlock
import JobsSwiftBaseDefines

extension WKWebView {
    @discardableResult
    public func byScrollView(_ block: (UIScrollView) -> Void) -> Self {
        block(self.scrollView)
        return self
    }

    @discardableResult
    public func loadURL(_ urlString: String) -> Self {
        guard let url = URL(string: urlString) else { return self }
        let request = URLRequest(url: url)
        self.load(request)
        return self
    }

    @discardableResult
    public func loadRequest(_ request: URLRequest) -> Self {
        self.load(request)
        return self
    }
    /// iOS 16.4+ 开启 Web Inspector
    /// - Parameter enabled: 是否开启；传 nil 时不做任何处理
    @discardableResult
    public func byInspectable(_ enabled: Bool? = true) -> Self {
        guard let enabled else { return self }
        if #available(iOS 16.4, *) {
            isInspectable = enabled
        };return self
    }
    /// 设置 customUserAgent
    /// - Parameter userAgent: 传 nil 时不做处理
    @discardableResult
    public func byCustomUserAgent(_ userAgent: String? = nil) -> Self {
        guard let userAgent else { return self }
        self.customUserAgent = userAgent
        return self
    }

    @discardableResult
    public func byConfiguration(_ block: (WKWebViewConfiguration) -> Void) -> Self {
        block(self.configuration)
        return self
    }

    @discardableResult
    public func byNavigationDelegate(_ delegate: WKNavigationDelegate?) -> Self {
        self.navigationDelegate = delegate
        return self
    }

    @discardableResult
    public func byUIDelegate(_ delegate: WKUIDelegate?) -> Self {
        self.uiDelegate = delegate
        return self
    }

    @discardableResult
    public func byAllowsBackForwardNavigationGestures(_ enabled: Bool) -> Self {
        self.allowsBackForwardNavigationGestures = enabled
        return self
    }
    /// 统一开关：iOS14+ 走 allowsContentJavaScript；更低版本回落到 preferences.javaScriptEnabled
    @discardableResult
    public func byAllowsJavaScript(_ enabled: Bool) -> Self {
        if #available(iOS 14.0, *) {
            configuration.defaultWebpagePreferences.allowsContentJavaScript = enabled
        } else {
            configuration.preferences.javaScriptEnabled = enabled
        };return self
    }
}
@MainActor
extension WKWebView {
    /// fire-and-forget：不关心回调
    public func jobsEval(_ js: String) {
        if #available(iOS 15.0, *) {
            onMainAsync { [weak self] in
                guard let self else { return }
                try? await self.evaluateJavaScript(js)
            }
        } else {
            self.evaluateJavaScript(js, completionHandler: nil)
        }
    }
    /// 带回调（@Sendable 友好）
    public func jobsEval(_ js: String,
                         completion: JobsByAnyErrMASendableBlock?) {
        if #available(iOS 15.0, *) {
            onMainAsync { [weak self] in
                guard let self else { return }
                do {
                    let result = try await self.evaluateJavaScript(js)
                    completion?(result, nil)
                } catch {
                    completion?(nil, error)
                }
            }
        } else {
            self.evaluateJavaScript(js, completionHandler: completion)
        }
    }
}
