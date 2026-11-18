//
//  DesktopRedirectPolicy.swift
//  RepairDesktop
//
//  Created by Jobs on 2026年11月18日，星期三.
//

import Foundation

final class DesktopRedirectPolicy: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    func urlSession(
        _ session: URLSession, task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        completionHandler(nil)
    }
}

extension URLSession {
    static func desktopMake() -> URLSession {
        URLSession(configuration: .ephemeral, delegate: DesktopRedirectPolicy(), delegateQueue: nil)
    }
}
