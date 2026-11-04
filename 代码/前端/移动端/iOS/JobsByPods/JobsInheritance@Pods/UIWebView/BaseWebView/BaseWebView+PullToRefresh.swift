//
//  BaseWebView+PullToRefresh.swift
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

extension BaseWebView {
    @MainActor
    @objc func handlePullToRefresh() {
        // 用当前 URL 重新发起“无缓存”加载，避免 reload 走到内存缓存
        if let url = webView.url {
            webView.load(makeNoCache(URLRequest(url: url)))
        } else {
            webView.reload()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            onMainAsync { [weak self] in
                guard let self else { return }
                self.refresher.endRefreshing()
            }
        }
    }
}
