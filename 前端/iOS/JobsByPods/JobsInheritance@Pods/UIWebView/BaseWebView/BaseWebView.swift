//
//  BaseWebView.swift
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
import JobsNavBar
import JobsByUIKit
import JobsSwiftDSL
import JobsByWebKit
import JobsSwiftBlock
import JobsSwiftBaseDefines
import SnapKit

/**
 在 Info.plist 添加👇（更通用的 ATS 配置，避免为某域名单独开洞）
     <key>NSAppTransportSecurity</key>
     <dict>
       <!-- 仅放开 Web 内容，其他网络请求仍受 ATS 约束 -->
       <key>NSAllowsArbitraryLoadsInWebContent</key><true/>
     </dict>
 */
public final class BaseWebView: UIView {
    // MARK: - 基础配置项（完全通用，无业务常量）
    public var openBlankInPlace: Bool = true
    public var disableSelectionAndCallout: Bool = false
    public var injectDarkStylePatch: Bool = false
    public var isInspectableEnabled: Bool = true {
        didSet { webView.byInspectable(isInspectableEnabled) }
    }
    /// 远程原生 Bridge 必须显式授权 origin，例如 https://example.com:443。
    public var bridgeReplyTimeout: TimeInterval = 15
    public var bridgeAllowedOrigins: Set<String> = []
    public var allowsLocalFileBridge = true
    public private(set) var lastConfigurationError: Error?
    public var onConfigurationError: ((Error) -> Void)?
    var bridgePageGeneration: UInt64 = 0
    /// URL 重写器：返回新的 URL 表示重写；返回 nil 表示不重写（默认 nil）
    public var urlRewriter: ((URL) -> URL?)?
    /// Safari 兜底规则：返回 true 时交给 Safari 打开（默认 nil）
    public var safariFallbackRule: ((URL) -> Bool)?
    /// 循环重写保护
    public var rewriteBurstWindow: TimeInterval = 3
    public var rewriteBurstLimit: Int = 3
    public var allowedHosts: Set<String> = []                         // 空 = 不限制
    public var externalSchemes: Set<String> = [
        "tel",
        "mailto",
        "sms",
        "facetime",
        "itms-apps",
        "maps",
        "weixin",
        "alipays",
        "alipay",
        "mqqapi",
        "line"
    ]
    // MARK: - WKWebViewConfiguration 外部覆盖（外部优先；外部未设置则用内部默认）
    /// 外部覆盖：nil 表示未设置（将使用内部默认值）
    var overrideWebsiteDataStore: WKWebsiteDataStore? = nil
    /// 外部注入：在 WKWebView 初始化前回调，可配置除 dataStore 以外的其它项（或最终覆盖）
    var webViewConfigurationHook: (jobsByWKWebConfigBlock)? = nil
    // MARK: - Fixed no-cache policy
    static let noCacheHeader = "X-Jobs-NoCache"
    let alwaysFreshMainDocument = true
    // MARK: - Bridge
    public typealias NativeBlock = (_ payload: Any?, _ completion: @escaping (Any?) -> Void) -> Void
    public private(set) lazy var progressView: UIProgressView = { [unowned self] in
        UIProgressView(progressViewStyle: .default)
            .byAddTo(self) { make in
                make.top.leading.trailing.equalToSuperview()
            }
    }()

    let bridgeName = "bridge"
    let consoleName = "console"
    let mobileBridgeName = "iOSBridge"

    var handlers: [String: NativeBlock] = [:]

    // Mobile bridge
    var mobileActionHandlers: [String: MobileActionBlock] = [:]
    var mobileConfig: MobileBridgeConfig = .defaults()

    // MARK: - Presenter

    public weak var presenter: UIViewController?

    var presentingVC: UIViewController? {
        presenter ?? nearestViewController() ?? UIApplication.jobsTopMostVC()
    }

    // MARK: - UserAgent

    var uaSuffixProvider: ((URLRequest) -> String?)?
    var lastAppliedUASuffix: String?

    // MARK: - Rewrite state

    var rewriteCount = 0
    var lastRewriteAt = Date.distantPast

    // MARK: - KVO

    private var kvoEstimatedProgress: NSKeyValueObservation?
    private var kvoTitle: NSKeyValueObservation?

    // MARK: - UI

    lazy var configuration: WKWebViewConfiguration = makeConfiguration()
    public private(set) lazy var webView: WKWebView = makeWebView(configuration: configuration)

    @MainActor
    private func makeConfiguration() -> WKWebViewConfiguration {
        let config = WKWebViewConfiguration()
            .byWebsiteDataStore(overrideWebsiteDataStore ?? .nonPersistent())
            .byAllowsInlineMediaPlayback(YES)
        webViewConfigurationHook?(config)
        if let overrideWebsiteDataStore {
            config.byWebsiteDataStore(overrideWebsiteDataStore)
        }
        config.userContentController.byAddUserScript(Self.makeBridgeUserScript())
        return config
    }

    @MainActor
    private func makeWebView(configuration: WKWebViewConfiguration) -> WKWebView {
        WKWebView(frame: .zero, configuration: configuration)
            .byNavigationDelegate(self)
            .byUIDelegate(self)
            .byInspectable(isInspectableEnabled)
            .byScrollView { scrollView in
                scrollView.byAlwaysBounceVertical(true).byRefreshControl(refresher)
            }
            .byAddTo(self) { [unowned self] make in
                make.top.equalTo(self.progressView.snp.bottom)
                make.leading.trailing.bottom.equalToSuperview()
            }
    }

    /// 初始化后的链式配置仅允许在首个文档加载之前重建 WebView。
    @MainActor
    func updateCreationConfiguration(_ update: () -> Void) {
        guard webView.url == nil, !webView.isLoading else {
            let error = NSError(domain: "BaseWebView", code: -11,
                                userInfo: [NSLocalizedDescriptionKey: "Configure WKWebView before loading its first document"])
            lastConfigurationError = error
            onConfigurationError?(error)
            return
        }
        update()
        kvoEstimatedProgress?.invalidate()
        kvoTitle?.invalidate()
        webView.stopLoading()
        let ucc = webView.configuration.userContentController
        for name in [bridgeName, consoleName, mobileBridgeName] {
            ucc.removeScriptMessageHandler(forName: name)
        }
        webView.byNavigationDelegate(nil).byUIDelegate(nil)
        webView.removeFromSuperview()
        configuration = makeConfiguration()
        webView = makeWebView(configuration: configuration)
        bridgePageGeneration &+= 1
        lastConfigurationError = nil
        registerMessageHandlers()
        setupKVO()
        applyRuntimeToggles()
        injectMinimalMobileShimIfNeeded()
    }

    lazy var refresher: UIRefreshControl = {
        UIRefreshControl.jobsMake { _ in }
            .onJobsChange { [weak self] (_: UIRefreshControl) in
                guard let self else { return }
                self.handlePullToRefresh()
            }
    }()
    /// 强引用 DocumentPicker 代理，避免立刻释放
    var docPickerDelegate: DocumentPickerDelegateProxy?
    // MARK: - Init
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    @MainActor
    public override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }
    /// ✅ 推荐构造：在 WKWebView 创建前注入 configuration（确保 websiteDataStore 等初始化参数生效）
    @MainActor
    public convenience init(_ configuration: @escaping jobsByWKWebConfigBlock) {
        self.init(frame: .zero, configuration: configuration)
    }
    /// 带 frame 的注入构造
    @MainActor
    public init(frame: CGRect = .zero, configuration: jobsByWKWebConfigBlock? = nil) {
        super.init(frame: frame)
        webViewConfigurationHook = configuration
        commonInit()
    }

    @MainActor
    private func commonInit() {
        // 先唤起 UI 懒加载（UI/约束都在 lazy block 内）
        progressView.byVisible(true)
        webView.byVisible(true)
        registerMessageHandlers()
        self.byBackgroundColor(JobsCor.clear)
        // 仅做“使用阶段”的配置；UI 生成与约束在 lazy block（progressView/webView）里完成
        progressView.byVisible(true)
        webView.byVisible(true)
        lastAppliedUASuffix = nil
        setupKVO()
        applyRuntimeToggles()
        // 默认启用通用 MobileBridge（零配置可用）
        _ = useMobileBridge()
    }

    deinit {
        cleanupNow()
    }

    private func cleanupNow() {
        kvoEstimatedProgress?.invalidate()
        kvoEstimatedProgress = nil
        kvoTitle?.invalidate()
        kvoTitle = nil
        webView.stopLoading()
        webView
            .byNavigationDelegate(nil)
            .byUIDelegate(nil)
        let ucc = webView.configuration.userContentController
        ucc.removeAllUserScripts()
        ucc.removeScriptMessageHandler(forName: bridgeName)
        ucc.removeScriptMessageHandler(forName: consoleName)
        ucc.removeScriptMessageHandler(forName: mobileBridgeName)
        handlers.removeAll()
        mobileActionHandlers.removeAll()
        docPickerDelegate = nil
    }
}
// MARK: - Internal assemble
private extension BaseWebView {
    @MainActor
    func registerMessageHandlers() {
        let ucc = webView.configuration.userContentController
        if #available(iOS 14.0, *) {
            let weakH = WeakScriptMessageHandlerWithReply(target: self)
            ucc.addScriptMessageHandler(weakH, contentWorld: .page, name: bridgeName)
            ucc.addScriptMessageHandler(weakH, contentWorld: .page, name: consoleName)
            ucc.addScriptMessageHandler(weakH, contentWorld: .page, name: mobileBridgeName)
        } else {
            ucc.add(WeakScriptMessageHandler(target: self), name: bridgeName)
            ucc.add(WeakScriptMessageHandler(target: self), name: consoleName)
            ucc.add(WeakScriptMessageHandler(target: self), name: mobileBridgeName)
        }
    }

    @MainActor
    func setupKVO() {
        kvoEstimatedProgress = webView.observe(\.estimatedProgress, options: [.new]) { [weak self] _, change in
            guard let self else { return }
            guard let p = change.newValue else { return }
            onMainAsync { [weak self] in
                guard let self else { return }
                self.progressView.byHidden(p >= 1.0)
                self.progressView.setProgress(Float(p), animated: true)
                if p >= 1.0 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
                        guard let self else { return }
                        self.progressView.byProgress(0)
                    }
                }
            }
        }
        kvoTitle = webView.observe(\.title, options: [.new]) { _, _ in }
    }

    @MainActor
    func applyRuntimeToggles() {
        injectDarkCSSIfNeeded()
        setSelectionDisabled(disableSelectionAndCallout)
    }
}
// MARK: - Public API
public extension BaseWebView {
    @discardableResult
    @MainActor
    func loadBy(_ url: URL) -> Self {
        if url.isFileURL {
            let readAccess = url.deletingLastPathComponent()
            webView.loadFileURL(url, allowingReadAccessTo: readAccess)
        } else {
            let req = URLRequest(url: url)
            webView.load(makeNoCache(req))
        };return self
    }

    @discardableResult
    @MainActor
    func loadBy(_ urlString: String) -> Self {
        if let url = URL(string: urlString) {
            let req = URLRequest(url: url)
            webView.load(makeNoCache(req))
        };return self
    }

    @discardableResult
    @MainActor
    func loadBy(_ url: URL,
                cachePolicy: URLRequest.CachePolicy = .useProtocolCachePolicy,
                timeout: TimeInterval = 60) -> Self {
        // ⚠️ 对外签名保留，但内部一律走无缓存策略（忽略传入的 cachePolicy）
        var req = URLRequest(url: url, cachePolicy: cachePolicy, timeoutInterval: timeout)
        req = makeNoCache(req)
        webView.load(req)
        return self
    }

    @discardableResult
    @MainActor
    func loadBy(_ request: URLRequest) -> Self {
        webView.load(makeNoCache(request))
        return self
    }

    @discardableResult
    @MainActor
    func loadHTMLBy(_ html: String, baseURL: URL? = nil) -> Self {
        webView.loadHTMLString(html, baseURL: baseURL)
        return self
    }
    /// 加载 App Bundle 内的本地 HTML 文件（链式）
    @discardableResult
    @MainActor
    func loadBundleHTMLBy(named name: String,
                          in subdirectory: String? = nil,
                          bundle: Bundle = .main) -> Self {
        if let url = bundle.url(forResource: name, withExtension: "html", subdirectory: subdirectory) {
            return loadBy(url)
        }
        if let urls = bundle.urls(forResourcesWithExtension: "html", subdirectory: nil),
           let url = urls.first(where: { $0.lastPathComponent == "\(name).html" }) {
            return loadBy(url)
        }
        assertionFailure("HTML '\(name).html' not found in bundle")
        return self
    }

    func on(_ name: String, handler: @escaping NativeBlock) { handlers[name] = handler }
    func off(_ name: String) { handlers.removeValue(forKey: name) }

    @MainActor
    func emitEvent(_ name: String, payload: Any?) {
        let js = "window.Native && window.Native.emit(\(Self.quote(name)), \(Self.toJSONLiteral(payload)));"
        webView.jobsEval(js)
    }

    @MainActor
    func callJS(function: String,
                args: [Any] = [],
                completion: JobsByAnyErrMASendableBlock? = nil) {
        let jsArgs = args.map(Self.toJSONLiteral).joined(separator: ",")
        webView.jobsEval("\(function)(\(jsArgs));", completion: completion)
    }
}
// MARK: - JS eval（Raw + Decodable）
public extension BaseWebView {
    @available(iOS 13.0, *)
    @MainActor
    func evalAsyncRaw(_ js: String, timeout: TimeInterval = 8) async throws -> Any? {
        guard timeout.isFinite, timeout > 0, timeout <= 86_400 else {
            throw NSError(domain: "BaseWebView", code: -2,
                          userInfo: [NSLocalizedDescriptionKey: "JS timeout must be finite and in (0, 86400]"])
        }
        let state = JobsWebEvaluationState()
        let timeoutWork = DispatchWorkItem {
            state.finish(.failure(NSError(domain: "BaseWebView", code: -1,
                                         userInfo: [NSLocalizedDescriptionKey: "JS eval timeout"])))
        }
        defer { timeoutWork.cancel() }
        return try await withTaskCancellationHandler(operation: {
            try Task.checkCancellation()
            return try await withCheckedThrowingContinuation { continuation in
                state.install(continuation)
                DispatchQueue.main.asyncAfter(deadline: .now() + timeout, execute: timeoutWork)
                webView.jobsEval(js) { value, error in
                    if let error {
                        state.finish(.failure(error))
                    } else {
                        state.finish(.success(value))
                    }
                }
            }
        }, onCancel: {
            state.finish(.failure(CancellationError()))
        })
    }

    @available(iOS 13.0, *)
    func evalAsync<T: Decodable>(_ js: String,
                                 as type: T.Type = T.self,
                                 timeout: TimeInterval = 8,
                                 decoder: JSONDecoder = JSONDecoder.make { _ in }) async throws -> T {
        let raw = try await evalAsyncRaw(js, timeout: timeout)
        return try Self.decodeJSResult(raw, as: T.self, decoder: decoder)
    }
}
// MARK: - Cookies / Selection
public extension BaseWebView {
    @MainActor
    func setCookies(_ cookies: [HTTPCookie], completion: (jobsByVoidBlock)? = nil) {
        let store = webView.configuration.websiteDataStore.httpCookieStore
        let group = DispatchGroup()
        cookies.forEach { c in
            group.enter()
            store.setCookie(c) { group.leave() }
        }
        group.notify(queue: .main) {
            completion?()
        }
    }

    @MainActor
    func setSelectionDisabled(_ disabled: Bool) {
        disableSelectionAndCallout = disabled
        let js = """
        (function(){
          var el = document.documentElement;
          el.style.webkitUserSelect=\(disabled ? "'none'" : "''");
          el.style.webkitTouchCallout=\(disabled ? "'none'" : "''");
        })();
        """
        webView.jobsEval(js)
    }
}
// MARK: - MobileBridge API
public extension BaseWebView {
    @discardableResult
    @MainActor
    func useMobileBridge(_ cfg: MobileBridgeConfig = .defaults()) -> Self {
        mobileConfig = cfg
        injectMinimalMobileShimIfNeeded()
        return self
    }

    @discardableResult
    func registerMobileAction(_ name: String, _ handler: @escaping MobileActionBlock) -> Self {
        mobileActionHandlers[name] = handler
        return self
    }

    @discardableResult
    func unregisterMobileAction(_ name: String) -> Self {
        mobileActionHandlers.removeValue(forKey: name)
        return self
    }
}

private final class JobsWebEvaluationState: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Any?, Error>?
    private var result: Result<Any?, Error>?

    func install(_ continuation: CheckedContinuation<Any?, Error>) {
        lock.lock()
        if let result {
            lock.unlock()
            continuation.resume(with: result)
        } else {
            self.continuation = continuation
            lock.unlock()
        }
    }

    func finish(_ result: Result<Any?, Error>) {
        lock.lock()
        guard self.result == nil else {
            lock.unlock()
            return
        }
        self.result = result
        let continuation = self.continuation
        self.continuation = nil
        lock.unlock()
        continuation?.resume(with: result)
    }
}
