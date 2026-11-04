//
//  BaseWebView+Navigation.swift
//  JobsInheritance
//
//  Created by Jobs on 2026年5月13日，星期三.
//

#if os(OSX)
import AppKit
#elseif os(iOS) || os(tvOS)
import UIKit
#endif

import SafariServices
import WebKit
import JobsSwiftDSL

extension BaseWebView: WKNavigationDelegate {
    @MainActor
    public func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        bridgePageGeneration &+= 1
        progressView.byHidden(false)
    }

    @MainActor
    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // 真实 UA 回传给前端
        webView.evaluateJavaScript("navigator.userAgent") { [weak self] v, _ in
            let ua = v as? String ?? ""
            self?.emitEvent("nativeReady", payload: [
                "ua": ua,
                "title": webView.title ?? ""
            ])
        }
        // 如果外部在当前视图上装了 NavBar 且未自定义标题，则默认绑定 webView.title
        if let nb = self.jobsNavBar, nb.titleProvider == nil {
            nb.bind(webView: webView)
            nb.refresh()
        }
    }

    @MainActor
    public func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        webView.reload()
    }

    @MainActor
    public func webView(_ webView: WKWebView,
                        decidePolicyFor action: WKNavigationAction,
                        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = action.request.url else {
            decisionHandler(.cancel)
            return
        }
        let scheme = (url.scheme ?? "").lowercased()
        let isMain = (action.targetFrame?.isMainFrame == true)
        // 0) 外部 scheme（weixin:// 等）
        let standardSchemes: Set<String> = ["http", "https", "file", "about", "data", "javascript"]
        if !standardSchemes.contains(scheme) || externalSchemes.contains(scheme) {
            if UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            }
            decisionHandler(.cancel)
            return
        }
        if !allowedHosts.isEmpty {
            if let h = url.host?.lowercased(), !allowedHosts.contains(h) {
                decisionHandler(.cancel)
                return
            }
        }
        // 0.5) 主文档一律强制无缓存（若未带标记头则重载为无缓存请求）
        if alwaysFreshMainDocument,
           isMain,
           action.request.value(forHTTPHeaderField: Self.noCacheHeader) != "1" {
            decisionHandler(.cancel)
            webView.load(makeNoCache(action.request))
            return
        }
        // 1) Safari 兜底（通用规则）
        if isMain, let rule = safariFallbackRule, rule(url) {
            decisionHandler(.cancel)
            presentSafari(with: url)
            return
        }
        // 2) 主文档：可选 URL 重写
        if isMain, let newURL = urlRewriter?(url), newURL != url {
            let now = Date()
            if now.timeIntervalSince(lastRewriteAt) > rewriteBurstWindow {
                rewriteCount = 0
            }
            rewriteCount += 1
            lastRewriteAt = now
            if rewriteCount <= rewriteBurstLimit {
                decisionHandler(.cancel)
                webView.load(makeNoCache(URLRequest(url: newURL)))
                return
            }
        }
        // 3) UA 动态切换（仅主文档）
        if isMain {
            let desired = normalizeSuffix(uaSuffixProvider?(action.request))
            if desired != lastAppliedUASuffix {
                lastAppliedUASuffix = desired
                webView.configuration.applicationNameForUserAgent = desired
                webView.byCustomUserAgent(nil)
                decisionHandler(.cancel)
                webView.load(makeNoCache(action.request))
                return
            }
        }
        // 4) target=_blank 的 in-place 处理
        if action.targetFrame == nil {
            if openBlankInPlace {
                webView.load(makeNoCache(action.request))
            } else {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            }
            decisionHandler(.cancel)
            return
        }
        // 5) Host 白名单
        decisionHandler(.allow)
    }

    @available(iOS 14.5, *)
    @MainActor
    public func webView(_ webView: WKWebView,
                        navigationResponse: WKNavigationResponse,
                        didBecome download: WKDownload) {
        download.delegate = self
    }

    @MainActor
    public func webView(_ webView: WKWebView,
                        didFailProvisionalNavigation navigation: WKNavigation!,
                        withError error: Error) {
        let ns = error as NSError
        print("⛔️ Provisional fail: \(ns.domain) [\(ns.code)] \(ns.localizedDescription)")
    }
}
// MARK: - Safari
private extension BaseWebView {
    @MainActor
    func presentSafari(with url: URL) {
        SFSafariViewController(url: url)
            .byModalPresentationStyle(.pageSheet)
            .byData(3.14)
            .onResult { name in
                print("回来了 \(String(describing: name))")
            }
            .byPresent(presentingVC)
            .byCompletion {
                print("结束")
            }
    }
}
