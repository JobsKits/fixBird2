//
//  BaseWebView+MobileBridge.swift
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
import JobsSwiftBlock
import JobsSwiftDSL

public extension BaseWebView {
    // ===== 通用 MobileBridge（H5 的 iOSBridge 约定）=====
    struct MobileBridgeConfig {
        public var injectShim: Bool = true                             // 无前端桥时的兜底
        public var tokenProvider: (@Sendable () async -> String?)?     // 异步 token
        public var onNavigateHome: (jobsByVoidBlock)? = nil
        public var onNavigateLogin: (jobsByVoidBlock)? = nil
        public var onNavigateDeposit: (jobsByVoidBlock)? = nil
        public var onCloseWebView: (jobsByVoidBlock)? = nil
        public var onShowToast: ((String) -> Void)? = nil
        public var onUnknownAction: ((String, [String: Any]) -> Void)? = nil
        public init() {}
        public static func defaults() -> Self { .init() }
    }
}
// MARK: - MobileBridgeConfig · 链式 DSL
public extension BaseWebView.MobileBridgeConfig {
    @discardableResult
    func byInjectShim(_ on: Bool = true) -> Self {
        var c = self
        c.injectShim = on
        return c
    }

    @discardableResult
    func byTokenProvider(_ f: (@Sendable () async -> String?)?) -> Self {
        var c = self
        c.tokenProvider = f
        return c
    }

    @discardableResult
    func byShowToast(_ f: @escaping (String) -> Void) -> Self {
        var c = self
        c.onShowToast = f
        return c
    }

    @discardableResult
    func byNavigateHome(_ f: @escaping jobsByVoidBlock) -> Self {
        var c = self
        c.onNavigateHome = f
        return c
    }

    @discardableResult
    func byNavigateLogin(_ f: @escaping jobsByVoidBlock) -> Self {
        var c = self
        c.onNavigateLogin = f
        return c
    }

    @discardableResult
    func byNavigateDeposit(_ f: @escaping jobsByVoidBlock) -> Self {
        var c = self
        c.onNavigateDeposit = f
        return c
    }

    @discardableResult
    func byCloseWebView(_ f: @escaping jobsByVoidBlock) -> Self {
        var c = self
        c.onCloseWebView = f
        return c
    }

    @discardableResult
    func byUnknownAction(_ f: @escaping (String, [String: Any]) -> Void) -> Self {
        var c = self
        c.onUnknownAction = f
        return c
    }
}
// MARK: - useMobileBridge · 闭包构造重载（纯 DSL）
public extension BaseWebView {
    /// 允许：web.useMobileBridge { $0.byTokenProvider{...}.byShowToast{...} }
    @discardableResult
    @MainActor
    func useMobileBridgeBy(_ build: (MobileBridgeConfig) -> MobileBridgeConfig) -> Self {
        let cfg = build(.defaults())
        return useMobileBridge(cfg)
    }
}
