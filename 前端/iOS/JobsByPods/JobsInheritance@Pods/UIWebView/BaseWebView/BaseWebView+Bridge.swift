//
//  BaseWebView+Bridge.swift
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
import JobsSwiftBaseDefines

// ===== ScriptMessageHandler（iOS < 14）=====
extension BaseWebView: WKScriptMessageHandler {
    @MainActor
    public func userContentController(_ userContentController: WKUserContentController,
                                      didReceive message: WKScriptMessage) {
        guard acceptsBridgeMessage(message) else { return }
        let channel = message.jobsChannel
        handleScriptMessage(channel: channel, body: message.body, reply: { _, _ in })
    }
}
// ===== WithReply（iOS 14+）=====
@available(iOS 14.0, *)
extension BaseWebView: WKScriptMessageHandlerWithReply {
    @MainActor
    public func userContentController(_ userContentController: WKUserContentController,
                                      didReceive message: WKScriptMessage,
                                      replyHandler: @escaping (Any?, String?) -> Void) {
        guard acceptsBridgeMessage(message) else {
            replyHandler(nil, "unauthorized bridge origin or frame")
            return
        }
        let channel = message.jobsChannel
        handleScriptMessage(channel: channel, body: message.body, reply: replyHandler)
    }
}
private extension BaseWebView {
    @MainActor
    func acceptsBridgeMessage(_ message: WKScriptMessage) -> Bool {
        guard message.frameInfo.isMainFrame else { return false }
        let origin = message.frameInfo.securityOrigin
        let scheme = origin.protocol.lowercased()
        if scheme == "file" {
            return allowsLocalFileBridge && webView.url?.isFileURL == true
        }
        guard scheme == "https" || scheme == "http" else { return false }
        let host = origin.host.lowercased()
        let port = origin.port == 0 ? (scheme == "https" ? 443 : 80) : origin.port
        let key = "\(scheme)://\(host):\(port)"
        let shortKey = "\(scheme)://\(host)"
        let defaultPort = scheme == "https" ? 443 : 80
        return bridgeAllowedOrigins.contains(key)
            || (port == defaultPort && bridgeAllowedOrigins.contains(shortKey))
    }
}

// ===== 统一消息处理 =====
public extension BaseWebView {
    @MainActor
    func handleScriptMessage(channel: String,
                             body: Any,
                             reply: @escaping (Any?, String?) -> Void) {
        // 1) 先拦截 H5 的 iOSBridge（{action,message?,callback?}）
        if channel == mobileBridgeName {
            handleIOSBridgeMessage(body)
            reply(nil, nil)
            return
        }
        // 2) 前端 console 透传
        if channel == consoleName {
            if let dict = body as? [String: Any],
               let level = dict["level"] as? String,
               let args = dict["args"] {
                print("[JS:\(level)] \(args)")
            }
            reply(nil, nil)
            return
        }
        // 3) 原有的 bridge
        guard channel == bridgeName else {
            reply(nil, "unknown bridge channel")
            return
        }
        let dictBody: [String: Any]
        if let d = body as? [String: Any] {
            dictBody = d
        } else if let s = body as? String,
                  let data = s.data(using: .utf8),
                  let d = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] {
            dictBody = d
        } else {
            reply(nil, "invalid bridge message")
            return
        }
        let api = dictBody["name"] as? String ?? ""
        let payload = dictBody["payload"]
        let reqId = dictBody["id"] as? Int
        guard let handler = handlers[api] else {
            if #available(iOS 14.0, *), reqId == nil {
                reply(["error": "unhandled:\(api)"], nil)
            } else if let reqId {
                jsReturn(id: reqId, value: ["error": "unhandled:\(api)"])
            };return
        }
        let generation = bridgePageGeneration
        let gate = JobsBridgeReplyGate()
        let timeout = bridgeReplyTimeout.isFinite && bridgeReplyTimeout > 0 ? min(bridgeReplyTimeout, 300) : 15
        let timeoutWork = DispatchWorkItem { [weak self] in
            guard gate.take() else { return }
            if #available(iOS 14.0, *), reqId == nil {
                reply(nil, "native bridge request timed out")
            } else if let self, self.bridgePageGeneration == generation, let reqId {
                self.jsReturn(id: reqId, value: ["error": "timeout"])
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + timeout, execute: timeoutWork)
        handler(payload) { [weak self] value in
            guard gate.take() else { return }
            timeoutWork.cancel()
            DispatchQueue.main.async {
                guard let self, self.bridgePageGeneration == generation else {
                    if #available(iOS 14.0, *), reqId == nil { reply(nil, "bridge page changed") }
                    return
                }
                if #available(iOS 14.0, *), reqId == nil {
                    reply(value, nil)
                } else if let reqId {
                    self.jsReturn(id: reqId, value: value)
                }
            }
        }
    }

    @MainActor
    func jsReturn(id: Int, value: Any?) {
        let js = "window.__nativeReturn && window.__nativeReturn(\(id), \(Self.toJSONLiteral(value)));"
        webView.jobsEval(js)
    }
}

// MARK: - iOSBridge（MobileBridge）
extension BaseWebView {
    @MainActor
    func handleIOSBridgeMessage(_ body: Any) {
        guard let dict = body as? [String: Any] else { return }
        let action = (dict["action"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let callback = (dict["callback"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !action.isEmpty else { return }
        // 1) 查找注册的处理器
        if let handler = mobileActionHandlers[action] {
            let generation = bridgePageGeneration
            let gate = JobsBridgeReplyGate()
            handler(dict) { [weak self] value in
                guard gate.take() else { return }
                DispatchQueue.main.async {
                    guard let self, self.bridgePageGeneration == generation, !callback.isEmpty else { return }
                    let js = """
                    try { (window[\(Self.quote(callback))] || function(){})(\(Self.toJSONLiteral(value)));
                    } catch(e) { console && console.error(e); }
                    """
                    self.webView.jobsEval(js)
                }
            }
            return
        }
        // 2) 没有注册时：默认 getToken（可选）
        if action == "getToken", let f = mobileConfig.tokenProvider {
            if #available(iOS 13.0, *) {
                let generation = bridgePageGeneration
                onMainAsync { [weak self] in
                    guard let self else { return }
                    let token = await f() ?? ""
                    guard self.bridgePageGeneration == generation, !callback.isEmpty else { return }
                    let js = "(window[\(Self.quote(callback))]||function(){})(\(Self.toJSONLiteral(token)))"
                    self.webView.jobsEval(js)
                }
            } else {
                guard !callback.isEmpty else { return }
                let js = "(window[\(Self.quote(callback))]||function(){})('')"
                self.webView.jobsEval(js)
            };return
        }
        mobileConfig.onUnknownAction?(action, dict)
    }
}

private final class JobsBridgeReplyGate: @unchecked Sendable {
    private let lock = NSLock()
    private var isFinished = false

    func take() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard !isFinished else { return false }
        isFinished = true
        return true
    }
}
