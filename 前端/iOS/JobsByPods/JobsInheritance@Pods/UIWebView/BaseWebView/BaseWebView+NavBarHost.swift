//
//  BaseWebView+NavBarHost.swift
//  JobsInheritance
//
//  Created by Jobs on 2026年5月13日，星期三.
//

#if os(OSX)
import AppKit
#elseif os(iOS) || os(tvOS)
import UIKit
#endif

import JobsNavBar
import SnapKit

// ===== BaseWebView 作为 NavBar 宿主：根据显隐重排内部约束 =====
extension BaseWebView: JobsNavBarHost {
    @MainActor
    public func jobsNavBarDidToggle(enabled: Bool, navBar: JobsNavBar) {
        progressView.snp.remakeConstraints { make in
            if enabled {
                make.top.equalTo(navBar.snp.bottom)
            } else {
                make.top.equalToSuperview()
            }
            make.left.right.equalToSuperview()
        }
        webView.snp.remakeConstraints { make in
            make.top.equalTo(progressView.snp.bottom)
            make.left.right.bottom.equalToSuperview()
        }
        layoutIfNeeded()
    }
}
