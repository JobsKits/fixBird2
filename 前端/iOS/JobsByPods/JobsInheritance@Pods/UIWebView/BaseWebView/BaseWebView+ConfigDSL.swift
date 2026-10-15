//
//  BaseWebView+ConfigDSL.swift
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

// ===== BaseWebView 专属：Web 配置 DSL =====
extension BaseWebView {
    @discardableResult
    public func byAllowedHosts(_ hosts: [String]) -> Self {
        allowedHosts = Set(hosts.map { $0.lowercased() })
        return self
    }

    @discardableResult
    public func byOpenBlankInPlace(_ inPlace: Bool = true) -> Self {
        openBlankInPlace = inPlace
        return self
    }

    @discardableResult
    @MainActor
    public func byDisableSelectionAndCallout(_ disabled: Bool) -> Self {
        setSelectionDisabled(disabled)
        return self
    }

    @discardableResult
    @MainActor
    public func byInjectDarkStylePatch(_ enable: Bool) -> Self {
        injectDarkStylePatch = enable
        if enable {
            injectDarkCSS()
        };return self
    }
    /// ✅ 按请求动态提供 UA 后缀；返回 nil = 系统默认 UA；非空 = 通过 applicationNameForUserAgent 追加
    @discardableResult
    public func byUserAgentSuffixProvider(_ provider: @escaping (URLRequest) -> String?) -> Self {
        uaSuffixProvider = provider
        return self
    }
    /// 自定义 URL 重写规则（返回 nil 表示不改写）
    @discardableResult
    public func byURLRewriter(_ rewriter: @escaping (URL) -> URL?) -> Self {
        urlRewriter = rewriter
        return self
    }
    /// 自定义 Safari 兜底规则
    @discardableResult
    public func bySafariFallbackRule(_ rule: @escaping (URL) -> Bool) -> Self {
        safariFallbackRule = rule
        return self
    }
    // ===== WKWebViewConfiguration 点语法注入（外部优先）=====
    /// 外部显式设置 dataStore（优先级高于内部默认）
    @discardableResult
    @MainActor
    public func byWebsiteDataStore(_ store: WKWebsiteDataStore) -> Self {
        updateCreationConfiguration { overrideWebsiteDataStore = store }
        return self
    }
    /// 使用持久化数据仓库（共享 Cookie/缓存）
    @discardableResult
    @MainActor
    public func byPersistentStore() -> Self {
        byWebsiteDataStore(.default())
    }
    /// 使用非持久数据仓库（每次全新 session）
    @discardableResult
    @MainActor
    public func byEphemeralStore() -> Self {
        byWebsiteDataStore(.nonPersistent())
    }
    /// 外部注入 WKWebViewConfiguration：在 webView 初始化前回调（外部优先于内部）
    @discardableResult
    @MainActor
    public func byWebViewConfiguration(_ hook: @escaping (WKWebViewConfiguration) -> Void) -> Self {
        updateCreationConfiguration { webViewConfigurationHook = hook }
        return self
    }

    @discardableResult
    public func byBridgeAllowedOrigins(_ origins: [String]) -> Self {
        bridgeAllowedOrigins = Set(origins.map { $0.lowercased() })
        return self
    }

    @discardableResult
    public func byApply(_ block: (BaseWebView) -> Void) -> Self {
        block(self)
        return self
    }
}
