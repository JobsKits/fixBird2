//
//  BaseWebVC.swift
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
import JobsByUIKit
import JobsSwiftDSL
import JobsByWebKit
import JobsSwiftFoundation
import JobsSwiftBaseDefines
import JobsSwiftStandardLibrary
import SnapKit
import GKNavigationBarSwift

/**
     BaseWebVC()
         .byData("https://www.baidu.com")
         .onResult { id in
            print("回来了 id=\(String(describing: id))")
         }
         .byPush(self)           // 自带防重入，连点不重复
         .byCompletion{
             print("❤️结束❤️")
         }
 */
open class BaseWebVC: BaseVC {
    // MARK: - 懒加载 Web（全通用，无业务常量）
    open lazy var webView: BaseWebView = { [unowned self] in
        BaseWebView{ cfg in
            cfg
                /// .nonPersistent() ：无痕模式
                /// .default() ：带sec default 保存 ➤ cookies / localStorage / IndexedDB / cache
                .byWebsiteDataStore(.default())
                /// 按需配置
                .byAllowsInlineMediaPlayback(true)
                .byPreferences { preferences in
                    preferences.javaScriptCanOpenWindowsAutomatically = true
                }
        }
        .byBackgroundColor(JobsCor.clear)
        .byAllowedHosts([])                  // 不限域
        .byOpenBlankInPlace(true)
        .byDisableSelectionAndCallout(false)
        .byUserAgentSuffixProvider { _ in
            // 按请求动态追加 UA 后缀；nil = 使用系统默认 UA
            // 需要区分页面时在此 return "YourApp/1.0"
            return nil
        }
//        .byNormalizeMToWWW(false)               // ❗️关闭 m→www
//        .byForceHTTPSUpgrade(false)             // ❗️关闭 http→https
//        .bySafariFallbackOnHTTP(false)          // ❗️关闭 Safari 兜底
//        .byInjectRedirectSanitizerJS(false)     // 可关，避免干涉 H5 自己跳转
        /// URL 重写策略（默认不重写；这里保持关闭）
        .byURLRewriter { _ in
            // 例如要做 http→https 升级：检测 url.scheme == "http" 再返回新 URL
            // 现在返回 nil 表示不改写
            return nil
        }
        /// Safari 兜底（默认不开）；返回 true 即交给 Safari 打开
        .bySafariFallbackRule { _ in
            return false
        }
        /// 一键开导航栏（默认标题=webView.title，默认有返回键）
        .byNavBarEnabled(NO)
        .byNavBarStyle { s in
            s.byHairlineHidden(false)
             .byBackgroundColor(JobsCor.systemBackground)
             .byTitleAlignmentCenter(true)
        }
        /// 自定义返回键（想隐藏就：.byNavBarBackButtonProvider { nil }）
        .byNavBarBackButtonProvider {
            UIButton.sys()
                .byBackgroundColor(JobsCor.clear)
                .byImage("chevron.left".sysImg, for: .normal)
                .byTitle("返回".tr, for: .normal)
                .byTitleFont(JobsFont.systemFont(ofSize: 16, weight: .medium))
                .byTitleColor(JobsCor.label, for: .normal)
                .byContentEdgeInsets(.init(top: 6, left: 10, bottom: 6, right: 10))
                .byTapSound("Sound.wav")
        }
        /// 返回行为：优先后退，否则关闭当前控制器
        .byNavBarOnBack { [weak self] in
            guard let self else { return }
            goBack("")
        }
        .byAddTo(view) { [unowned self] make in
            make.left.right.bottom.equalToSuperview()
            if view.jobs_hasVisibleTopBar() {
                make.top.equalTo(self.gk_navigationBar.snp.bottom).offset(10)
            } else {
                make.top.equalTo(view.safeAreaLayoutGuide.snp.top)
            }
        }
        // MARK: - 以下是依据前端暴露的自定义方法进行的JS交互
        /// 跳转到首页
        .registerMobileAction("navigateToHome") { [weak self] body, reply in
            self!.goBack("")
            reply(nil)
        }
        .registerMobileAction("getToken") { [weak self] body, reply in
            reply(nil)
        }
        .registerMobileAction("navigateToLogin") { [weak self] body, reply in
            /// 跳转到登录页
            reply(nil)
        }
        .registerMobileAction("navigateToDeposit") { [weak self] body, reply in
            /// 跳转到充值页
            reply(nil)
        }
        .registerMobileAction("closeWebView") { [weak self] body, reply in
            /// 关闭WebView
            reply(nil)
        }
        .registerMobileAction("navigateToSecurityCenter") { [weak self] body, reply in
            /// 跳转福利中心
            reply(nil)
        }
        .registerMobileAction("showToast") { [weak self] body, reply in
            /// 显示Toast
            (body.stringValue(for: "message") ?? "").toast
            reply(nil)
        }
    }()
    // MARK: - 生命周期
    // ✅ 缓存任意类型的入参
    private var input: Any?
    open override func loadView() {
        super.loadView()
        if let any = input { print("收到任意数据:", any) }
    }

    open override func viewDidLoad() {
        super.viewDidLoad()
        if let s = input as? String, !s.isEmpty {
            webView.loadBy(s)
        }
    }

    @discardableResult
    open func byData(_ any: Any?) -> Self {
        input = any
        return self
    }
}
