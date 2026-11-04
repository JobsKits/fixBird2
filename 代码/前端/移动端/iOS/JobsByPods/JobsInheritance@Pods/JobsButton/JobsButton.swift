//
//  JobsButton.swift
//  JobsInheritance
//
//  Created by Jobs on 2026年5月13日，星期三.
//

#if os(OSX)
import AppKit
#elseif os(iOS) || os(tvOS)
import UIKit
#endif

import JobsByUIKit
import JobsSwiftDSL
import JobsSwiftBaseDefines
import SnapKit

public final class JobsButton: UIImageView {
    // MARK: - Mode
    public enum Mode {
        case imageTopTextBottom
        case textTopImageBottom
        case imageLeftTextRight
        case textLeftImageRight
    }
    // MARK: - Public Config
    public private(set) var mode: Mode = .imageLeftTextRight
    /// 前景图与主标题的距离
    public var imageTitleSpacing: CGFloat = 6 { didSet { refreshUI() } }
    /// 主标题与副标题的距离
    public var titleSubtitleSpacing: CGFloat = 2 { didSet { refreshUI() } }
    /// 内容内边距
    public var contentInsets: UIEdgeInsets = .zero { didSet { refreshUI() } }
    /// ✅ 前景图固定尺寸（仿系统按钮：icon 不随容器尺寸变化）
    public var foregroundImageSize: CGSize = CGSize(width: 24, height: 24) { didSet { refreshUI() } }
    /// 是否强制固定前景图尺寸
    public var isForegroundImageFixedSize: Bool = true { didSet { refreshUI() } }
    /// 是否显示前景图（推荐用这个控制“没有值就不显示”）
    /// - 说明：不要用 image == nil 来决定 hidden，否则异步加载阶段可能被错误剔除布局
    public var showsForegroundImage: Bool = true { didSet { refreshUI() } }
    // MARK: - Subviews (lazy)
    private lazy var contentContainer: UIView = {
        UIView.jobsMake { _ in }
            .byBackgroundColor(JobsCor.clear)
            .byUserInteractionEnabled(false)
    }()
    /// 对标 UIButton 的前景图
    public lazy var foregroundImageView: UIImageView = {
        let iv = UIImageView.jobsMake { _ in }
            .byBackgroundColor(JobsCor.clear)
            .byContentMode(.scaleAspectFit)
            .byClipsToBounds(true)
        // 仿系统：图标优先保留，不被文字挤没
        iv.setContentCompressionResistancePriority(.required, for: .horizontal)
        iv.setContentCompressionResistancePriority(.required, for: .vertical)
        iv.setContentHuggingPriority(.required, for: .horizontal)
        iv.setContentHuggingPriority(.required, for: .vertical)
        return iv
    }()
    /// 对标 UIButton.titleLabel
    public lazy var titleLabel: UILabel = {
        UILabel.jobsMake { _ in }
            .byNumberOfLines(1)
            .byBackgroundColor(JobsCor.clear)
            .byFont(JobsFont.systemFont(ofSize: 17))
            .byTextColor(JobsCor.label)
    }()
    /// 对标 UIButton.subtitle（拟合系统风格）
    public lazy var subtitleLabel: UILabel = {
        UILabel.jobsMake { _ in }
            .byNumberOfLines(1)
            .byBackgroundColor(JobsCor.clear)
            .byFont(JobsFont.systemFont(ofSize: 12))
            .byTextColor(JobsCor.secondaryLabel)
    }()
    // MARK: - Init
    public override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }
    /// 允许 JobsButton()，不需要 frame
    public convenience init() {
        self.init(frame: .zero)
    }

    private func commonInit() {
        isUserInteractionEnabled = true
        clipsToBounds = false
        contentMode = .scaleToFill
        setupViewsIfNeeded()
        refreshUI()
    }
    // MARK: - Fluent APIs
    @discardableResult
    public func byMode(_ mode: Mode) -> Self {
        self.mode = mode
        refreshUI()
        return self
    }
    // MARK: - DSL (Layout)
    /// 前景图与主标题的距离
    @discardableResult
    public func byImageTitleSpacing(_ value: CGFloat) -> Self {
        self.imageTitleSpacing = value
        return self
    }
    /// 主标题与副标题的距离
    @discardableResult
    public func byTitleSubtitleSpacing(_ value: CGFloat) -> Self {
        self.titleSubtitleSpacing = value
        return self
    }
    /// 内容内边距
    @discardableResult
    public func byContentInsets(_ value: UIEdgeInsets) -> Self {
        self.contentInsets = value
        return self
    }
    /// 是否强制固定前景图尺寸
    @discardableResult
    public func byForegroundImageFixedSize(_ value: Bool) -> Self {
        self.isForegroundImageFixedSize = value
        return self
    }
    /// ✅ 聚合式 DSL：一次性配置多个布局参数，并自动触发刷新
    /// - 说明：适合把一堆布局参数放到一个块里写，链式调用不被打断。
    @discardableResult
    public func byLayout(_ block: (_ dsl: JobsButtonLayoutDSL) -> Void) -> Self {
        let dsl = JobsButtonLayoutDSL(owner: self)
        block(dsl)
        return self.byRefreshUI()
    }
    /// 设置前景图（如果传 nil，会自动隐藏前景图）
    @discardableResult
    public func byForegroundImage(_ image: UIImage?) -> Self {
        foregroundImageView.byImage(image)
        showsForegroundImage = (image != nil)
        refreshUI()
        return self
    }
    /// 设置背景图（JobsButton 自己是 UIImageView）
    @discardableResult
    public func byBgImage(_ image: UIImage?) -> Self {
        self.image = image
        return self
    }

    @discardableResult
    public func byTitleLabel(_ block: (UILabel) -> Void) -> Self {
        block(titleLabel)
        refreshUI()
        return self
    }

    @discardableResult
    public func bySubTitleLabel(_ block: (UILabel) -> Void) -> Self {
        block(subtitleLabel)
        refreshUI()
        return self
    }
    /// 设置前景图固定尺寸
    @discardableResult
    public func byForegroundImageSize(_ size: CGSize) -> Self {
        foregroundImageSize = size
        return self
    }
    /// 显示/隐藏前景图
    @discardableResult
    public func byShowForegroundImage(_ show: Bool) -> Self {
        showsForegroundImage = show
        return self
    }

    @discardableResult
    public func byRefreshUI() -> Self {
        refreshUI()
        return self
    }
    /// ✅ 单条链配置 foregroundImageView，并自动刷新布局
    @discardableResult
    public func byForegroundImageView(_ block: (UIImageView) -> Void) -> Self {
        block(self.foregroundImageView)
        // 外部一旦开始配置前景图，默认认为要显示（避免异步阶段被剔除布局）
        showsForegroundImage = true
        return self.byRefreshUI()
    }

    // MARK: - DSL Type
    public struct JobsButtonLayoutDSL {
        fileprivate unowned let owner: JobsButton
        fileprivate init(owner: JobsButton) {
            self.owner = owner
        }
        /// 前景图与主标题的距离
        public func imageTitleSpacing(_ value: CGFloat) {
            owner.imageTitleSpacing = value
        }
        /// 主标题与副标题的距离
        public func titleSubtitleSpacing(_ value: CGFloat) {
            owner.titleSubtitleSpacing = value
        }
        /// 内容内边距
        public func contentInsets(_ value: UIEdgeInsets) {
            owner.contentInsets = value
        }
        /// 是否强制固定前景图尺寸
        public func foregroundImageFixedSize(_ value: Bool) {
            owner.isForegroundImageFixedSize = value
        }
    }
    // MARK: - Layout
    private var didSetupViews = false
    private func setupViewsIfNeeded() {
        guard !didSetupViews else { return }
        didSetupViews = true
        contentContainer.byAddTo(self)
        foregroundImageView.byAddTo(contentContainer)
        titleLabel.byAddTo(contentContainer)
        subtitleLabel.byAddTo(contentContainer)
        updateContainerConstraints()
    }

    private func updateContainerConstraints() {
        contentContainer.snp.remakeConstraints { [unowned self] make in
            make.center.equalToSuperview()
            make.left.greaterThanOrEqualToSuperview().offset(contentInsets.left)
            make.right.lessThanOrEqualToSuperview().inset(contentInsets.right)
            make.top.greaterThanOrEqualToSuperview().offset(contentInsets.top)
            make.bottom.lessThanOrEqualToSuperview().inset(contentInsets.bottom)
        }
    }

    private func refreshUI() {
        setupViewsIfNeeded()
        updateContainerConstraints()
        updateHiddenState()
        remakeLayoutConstraints()
        setNeedsLayout()
        layoutIfNeeded()
    }

    private func updateHiddenState() {
        let titleText = titleLabel.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        titleLabel.byHidden(titleText.isEmpty)
        let subText = subtitleLabel.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        subtitleLabel.byHidden(subText.isEmpty)
        // ✅ 只由显式开关控制是否参与布局（避免异步加载阶段被剔除布局）
        foregroundImageView.byHidden(!showsForegroundImage)
    }

    private func remakeLayoutConstraints() {
        foregroundImageView.snp.removeConstraints()
        titleLabel.snp.removeConstraints()
        subtitleLabel.snp.removeConstraints()
        let views = arrangedVisibleViews(for: mode)
        guard !views.isEmpty else { return }
        let vertical = isVerticalMode(mode)
        for (idx, v) in views.enumerated() {
            v.snp.remakeConstraints { [unowned self] make in
                // ✅ 仿系统：前景图固定尺寸
                if v === foregroundImageView, isForegroundImageFixedSize {
                    make.width.equalTo(foregroundImageSize.width)
                    make.height.equalTo(foregroundImageSize.height)
                }
                if vertical {
                    make.centerX.equalToSuperview()
                    if idx == 0 {
                        make.top.equalToSuperview()
                    } else {
                        let prev = views[idx - 1]
                        make.top.equalTo(prev.snp.bottom).offset(spacing(between: prev, and: v))
                    }
                    if idx == views.count - 1 {
                        make.bottom.equalToSuperview()
                    }
                } else {
                    make.centerY.equalToSuperview()
                    if idx == 0 {
                        make.left.equalToSuperview()
                    } else {
                        let prev = views[idx - 1]
                        make.left.equalTo(prev.snp.right).offset(spacing(between: prev, and: v))
                    }
                    if idx == views.count - 1 {
                        make.right.equalToSuperview()
                    }
                }
            }
        }
        // 仿系统：文字可被压缩，图标优先保留（配合前景图的 required）
        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        subtitleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    }

    private func arrangedVisibleViews(for mode: Mode) -> [UIView] {
        let image = foregroundImageView.isHidden ? nil : foregroundImageView
        let title = titleLabel.isHidden ? nil : titleLabel
        let sub = subtitleLabel.isHidden ? nil : subtitleLabel
        func compact(_ arr: [UIView?]) -> [UIView] { arr.compactMap { $0 } }
        switch mode {
        /// 处理 .imageTopTextBottom 分支
        case .imageTopTextBottom:  return compact([image, title, sub])
        /// 处理 .textTopImageBottom 分支
        case .textTopImageBottom:  return compact([title, sub, image])
        /// 处理 .imageLeftTextRight 分支
        case .imageLeftTextRight:  return compact([image, title, sub])
        /// 处理 .textLeftImageRight 分支
        case .textLeftImageRight:  return compact([title, sub, image])
        }
    }

    private func isVerticalMode(_ mode: Mode) -> Bool {
        switch mode {
        /// 合并处理 .imageTopTextBottom、.textTopImageBottom 分支
        case .imageTopTextBottom, .textTopImageBottom: return true
        /// 未匹配已知分支时执行兜底处理
        default: return false
        }
    }

    private func spacing(between a: UIView, and b: UIView) -> CGFloat {
        if (a === foregroundImageView && b === titleLabel) || (a === titleLabel && b === foregroundImageView) {
            return imageTitleSpacing
        }
        if (a === titleLabel && b === subtitleLabel) || (a === subtitleLabel && b === titleLabel) {
            return titleSubtitleSpacing
        };return 0
    }
}
// MARK: - JobsButtonLayoutDSL
/// JobsButton 布局参数 DSL
/// - 用途：把多个 layout 参数集中在一个闭包内配置，避免链式调用过长。
public final class JobsButtonLayoutDSL {
    private weak var owner: JobsButton?

    fileprivate init(owner: JobsButton) {
        self.owner = owner
    }
    /// 前景图与主标题的距离
    @discardableResult
    public func imageTitleSpacing(_ value: CGFloat) -> Self {
        owner?.imageTitleSpacing = value
        return self
    }
    /// 主标题与副标题的距离
    @discardableResult
    public func titleSubtitleSpacing(_ value: CGFloat) -> Self {
        owner?.titleSubtitleSpacing = value
        return self
    }
    /// 内容内边距
    @discardableResult
    public func contentInsets(_ value: UIEdgeInsets) -> Self {
        owner?.contentInsets = value
        return self
    }
    /// 是否强制固定前景图尺寸
    @discardableResult
    public func foregroundImageFixedSize(_ value: Bool) -> Self {
        owner?.isForegroundImageFixedSize = value
        return self
    }
}
