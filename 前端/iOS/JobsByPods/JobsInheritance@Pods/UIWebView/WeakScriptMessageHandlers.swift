//
//  WeakScriptMessageHandlers.swift
//  JobsInheritance
//
//  Created by Jobs on 2026年5月13日，星期三.
//

import WebKit
/// iOS < 14 的弱代理封装

final class WeakScriptMessageHandler: NSObject, WKScriptMessageHandler {
    weak var target: WKScriptMessageHandler?

    init(target: WKScriptMessageHandler) {
        self.target = target
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        target?.userContentController(userContentController, didReceive: message)
    }
}
/// iOS 14+：同时支持无回调与 withReply 的弱转发器，打断 UCC→handler 闭环
@available(iOS 14.0, *)
final class WeakScriptMessageHandlerWithReply: NSObject,
                                                WKScriptMessageHandler,
                                                WKScriptMessageHandlerWithReply {
    weak var target: (WKScriptMessageHandler & WKScriptMessageHandlerWithReply)?
    init(target: (WKScriptMessageHandler & WKScriptMessageHandlerWithReply)) {
        self.target = target
    }

    func userContentController(_ userContentController: WKUserContentController,
                               didReceive message: WKScriptMessage) {
        target?.userContentController(userContentController, didReceive: message)
    }

    func userContentController(_ userContentController: WKUserContentController,
                               didReceive message: WKScriptMessage,
                               replyHandler: @escaping (Any?, String?) -> Void) {
        target?.userContentController(userContentController, didReceive: message, replyHandler: replyHandler)
    }
}
/// 用 keyPath 显式取系统的 name，规避工程里可能的同名扩展
private typealias WKSM = WebKit.WKScriptMessage
extension WKSM {
    var jobsChannel: String { self[keyPath: \WKSM.name] }
}
