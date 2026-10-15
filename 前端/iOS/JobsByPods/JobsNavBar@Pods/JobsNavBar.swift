//
//  JobsNavBar.swift
//  JobsNavBar
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
import JobsSwiftBaseDefines
import SnapKit

public class JobsNavBar: UIView {
    // MARK: - Style
    public struct Style {
        public var usesSafeAreaTopInset: Bool = true
        public var contentHeight: CGFloat = 44
        public var backgroundColor: UIColor = JobsCor.secondarySystemBackground
        public var hairlineColor: UIColor = JobsCor.separator.withAlphaComponent(0.6)
        public var hairlineHidden: Bool = false
        public var titleAlignmentCenter: Bool = true
        public init() {}
    }
    /// 占位标题（默认“加载中…”）
    private var placeholderTitleAttr: NSAttributedString = JobsNavBar._jobsMakeTitleAttr(JobsNavBar.loadingTitle)
    /// 外部可自定义返回键布局
    public var backButtonLayout: BackButtonLayout? {
        didSet {
            // 回调变更时，仅重排约束（不再重复 addSubview）
            if oldValue == nil, backButtonLayout == nil { return }
            rebuildBackButton()
        }
    }

    @MainActor
    public func showLoadingTitle(_ text: String = "加载中…") {
        placeholderTitleAttr = Self._jobsMakeTitleAttr(text)
        // 直接把占位画到 UI 上；保持 titleProvider 仍然是 nil，后续 bind 才会生效
        titleLabel.byAttributedString(placeholderTitleAttr)
    }

    public var style: Style {
        didSet {
            applyStyle()
            _leftContainerH?.update(offset: style.contentHeight) // 同步高度
            relayoutTitleConstraints()
            invalidateIntrinsicContentSize()
            rebuildBackButton()                                  // contentHeight 变更会影响按钮高度上限
        }
    }

    public var backButtonProvider: JobsRetButtonBlock? {
        didSet {
            rebuildBackButton() // provider 变化 -> 可能换按钮；交给 rebuild 处理
        }
    }

    public var titleProvider: JobsRetAttributedString? {
        didSet { refreshTitle() }
    }

    public var onBack: jobsByVoidBlock?
    // ===== 懒加载子视图（外部可直接链式修改，比如 navBar.hairline.byVisible(true））=====
    public private(set) lazy var backgroundView: UIView = {
        UIView.jobsMake { _ in }
            .byAddTo(self) { v, make in
                make.edges.equalToSuperview()
            }
    }()

    public private(set) lazy var hairline: UIView = {
        UIView.jobsMake { _ in }
            .byVisible(!style.hairlineHidden)
            .byBackgroundColor(style.hairlineColor)
            .byAddTo(self) { v, make in
                make.left.right.bottom.equalToSuperview()
                make.height.equalTo(0.5)
            }
    }()

    public private(set) lazy var titleLabel: UILabel = {
        UILabel.jobsMake { _ in }
            .byNumberOfLines(1)
            .byTextAlignment(.center)
            .byAddTo(self) { [unowned self] v, make in
                /// 具体约束在 relayoutTitleConstraints() 里统一处理
            }
    }()
    private var _leftContainerH: Constraint?
    public private(set) lazy var leftContainer: UIView = {
        UIView.jobsMake { _ in }.byAddTo(self) { [unowned self] v, make in
            make.left.equalToSuperview().offset(8)
            make.bottom.equalToSuperview() // 贴底
            _leftContainerH = make.height.equalTo(self.style.contentHeight).constraint // 固定“内容区”高
            make.width.greaterThanOrEqualTo(36)
        }
    }()

    public private(set) var leftButton: UIButton?
    // ===== 内部状态 =====
    private var kvoTitle: NSKeyValueObservation?
    /// 返回按钮约束是否已安装（用于首装 vs 变更时的 make/remake 切换）
    private var _backConstraintsInstalled = false
    // MARK: - Init
    public init(style: Style = .init()) {
        self.style = style
        super.init(frame: .zero)
        // 懒加载：这里只触发样式应用，不强制创建所有子视图
        applyStyle()
        relayoutTitleConstraints()
        if self.titleProvider == nil {
            showLoadingTitle()
        }
    }

    public required init?(coder: NSCoder) {
        self.style = .init()
        super.init(coder: coder)
        applyStyle()
        relayoutTitleConstraints()
        if self.titleProvider == nil {
            showLoadingTitle()
        }
    }

    deinit { kvoTitle?.invalidate() }
    // MARK: - Public helpers
    /// 主动刷新全部
    @MainActor
    public func jobsNavBarRefresh() {
        _ = backgroundView; _ = hairline; _ = titleLabel; _ = leftContainer
        rebuildBackButton()
        refreshTitle()
        setNeedsLayout()
    }
    /// 绑定 WebView 标题（也可以自定义 titleProvider 覆盖）
    // 小工具：统一标题样式
    private static func _jobsMakeTitleAttr(_ text: String) -> NSAttributedString {
        return NSAttributedString(
            string: text,
            attributes: [
                .font: JobsFont.systemFont(ofSize: 17, weight: .semibold),
                .foregroundColor: JobsCor.label
            ]
        )
    }
    public static var loadingTitle: String = "加载中..."
    @MainActor
    public func bind(
        webView: WKWebView,
        defaultTitle: String? = nil,
        preferHostWhenEmpty: Bool = true
    ) {
        let fallback = defaultTitle ?? Self.loadingTitle
        self.titleProvider = { [weak webView] in
            guard let wv = webView else {
                return Self._jobsMakeTitleAttr(fallback)
            }
            // 1) 页面标题
            if let t = wv.title?.trimmingCharacters(in: .whitespacesAndNewlines), !t.isEmpty {
                return Self._jobsMakeTitleAttr(t)
            }
            // 2) 域名回退
            if preferHostWhenEmpty, let host = wv.url?.host, !host.isEmpty {
                return Self._jobsMakeTitleAttr(host)
            }
            // 3) 默认占位
            return Self._jobsMakeTitleAttr(fallback)
        }
        kvoTitle?.invalidate()
        kvoTitle = webView.observe(\.title, options: [.new]) { [weak self] _, _ in
            onMainAsync(self) { vc in self?.refreshTitle() }
        }
        refreshTitle()
    }
    // MARK: - Private
    @MainActor
    private func applyStyle() {
        // 访问懒属性以确保存在，然后再设值
        backgroundView.byBackgroundColor(style.backgroundColor)
        hairline
            .byBackgroundColor(style.hairlineColor)
            .byVisible(!style.hairlineHidden)
    }

    @MainActor
    private func refreshTitle() {
        if let attr = titleProvider?(),
           !attr.string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            titleLabel.byAttributedString(attr)
        } else {
            titleLabel.byAttributedString(placeholderTitleAttr)
        }
    }
    /// ④ 标题改为参照 leftContainer 的“内容区”对齐（避免对整个 NavBar 对齐）
    @MainActor
    private func relayoutTitleConstraints() {
        titleLabel.snp.remakeConstraints { make in
            if style.titleAlignmentCenter {
                make.center.equalToSuperview()
                make.left.greaterThanOrEqualTo(leftContainer.snp.right).offset(8)
                make.right.lessThanOrEqualToSuperview().inset(12)
            } else {
                make.left.equalTo(leftContainer.snp.right).offset(8)
                make.right.lessThanOrEqualToSuperview().inset(12)
            }
        }
    }
    /// 只走一次 addSubview；其后仅改约束（首装 make / 变更 remake）
    @MainActor
    private func rebuildBackButton() {
        _ = leftContainer
        // 1) 拿到 provider 结果；nil = 隐藏并清理
        guard let providedBtn = backButtonProvider?() else {
            leftContainer.byVisible(false)
            leftButton?.removeFromSuperview()
            leftButton = nil
            return
        }
        leftContainer.byVisible(true)
        // 2) 如按钮实例变了 -> 替换并清安装标记（只在此处 addSubview，一次性）
        if leftButton !== providedBtn {
            leftButton?.removeFromSuperview()
            leftButton = providedBtn
            providedBtn.byAddTo(leftContainer)
            // 基础属性（不涉及布局）
            providedBtn.byContentVerticalAlignment(.center)
            providedBtn.setContentHuggingPriority(.required, for: .vertical)
            providedBtn.setContentCompressionResistancePriority(.required, for: .vertical)
            // 事件（避免重复加 target：先移除旧引用已 removeFromSuperview，这里安全）
            providedBtn.onTap { [weak self] _ in self?.backTapped() }
        }
        guard let btn = leftButton else { return }
        // 3) 安装/更新约束：首次 make，之后 remake（不再使用 byAddTo，避免重复 add）
        let install: (_ make: ConstraintMaker) -> Void = { [unowned self] make in
            if let L = self.backButtonLayout {
                L(self, btn, make)
            } else {
                make.left.equalToSuperview().inset(0)
                make.top.equalToSuperview().inset(6)
                make.height.greaterThanOrEqualTo(36)
                make.height.lessThanOrEqualTo(self.style.contentHeight)
                make.right.lessThanOrEqualToSuperview().inset(8)
            }
        }
        if _backConstraintsInstalled {
            btn.snp.remakeConstraints(install)
        } else {
            btn.snp.makeConstraints(install)
            _backConstraintsInstalled = true
        }
    }

    @MainActor
    private func backTapped() {
        if let onBack {
            onBack()
        } else {
            debugOnly {  // 仅 Debug 执行
                JobsSwiftMessageToast.show("Hello", duration: 0.8)
            }
        }
    }
    // MARK: - Layout / Safe Area
    public override var intrinsicContentSize: CGSize {
        let top = style.usesSafeAreaTopInset ? safeAreaInsets.top : 0
        return .init(width: UIView.noIntrinsicMetric, height: top + style.contentHeight)
    }

    public override func safeAreaInsetsDidChange() {
        super.safeAreaInsetsDidChange()
        if style.usesSafeAreaTopInset { invalidateIntrinsicContentSize() }
    }
}
@MainActor
public extension JobsNavBar.Style {
    /// 是否占用宿主的 safeArea 顶部内边距
    @discardableResult
    func byUsesSafeAreaTopInset(_ on: Bool = true) -> Self {
        var c = self; c.usesSafeAreaTopInset = on; return c
    }
    /// 内容区高度（不含安全区）
    @discardableResult
    func byContentHeight(_ height: CGFloat) -> Self {
        var c = self; c.contentHeight = height; return c
    }
    /// 背景色
    @discardableResult
    func byBackgroundColor(_ color: UIColor) -> Self {
        var c = self; c.backgroundColor = color; return c
    }
    /// 发丝线颜色
    @discardableResult
    func byHairlineColor(_ color: UIColor) -> Self {
        var c = self; c.hairlineColor = color; return c
    }
    /// 是否隐藏发丝线
    @discardableResult
    func byHairlineHidden(_ hidden: Bool = true) -> Self {
        var c = self; c.hairlineHidden = hidden; return c
    }
    /// 标题是否居中
    @discardableResult
    func byTitleAlignmentCenter(_ centered: Bool = true) -> Self {
        var c = self; c.titleAlignmentCenter = centered; return c
    }
}
