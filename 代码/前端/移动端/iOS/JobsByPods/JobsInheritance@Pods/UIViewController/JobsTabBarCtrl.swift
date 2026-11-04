//
//  JobsTabBarCtrl.swift
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
import JobsToast
import JobsSwiftBaseDefines
import SnapKit

// MARK: - 自定义滚动 TabBar（继承 BaseVC）
open class JobsTabBarCtrl: BaseVC, UIScrollViewDelegate {
    // MARK: - 可配置项
    public var isSwipeEnabled: Bool = true {
        didSet { contentScrollView.isScrollEnabled = isSwipeEnabled }
    }
    /// 只允许横向翻页（默认 true）
    public var horizontalOnly: Bool = true {
        didSet {
            contentScrollView.byAlwaysBounceVertical(!horizontalOnly)
            contentScrollView.isDirectionalLockEnabled = horizontalOnly
        }
    }
    /// （可选）对子 VC 内滚动视图禁用纵向滚动（默认 false）
    public var suppressChildVerticalScrolls: Bool = false
    /// 默认高度 = 49 + safeBottom
    public var customBarHeight: CGFloat? {
        didSet { view.setNeedsLayout() }
    }
    /// 距底部上移量（>0 上移）
    public var barBottomOffset: CGFloat = 0 {
        didSet { view.setNeedsLayout() }
    }

    public var barBackgroundColor: UIColor = JobsCor.systemBackground {
        didSet { TabBar.byBackgroundColor(barBackgroundColor) }
    }

    public var barBackgroundImage: UIImage? {
        didSet { bgImageView.byImage(barBackgroundImage) }
    }
    /// TabBar 内边距（用于 1/2~5 规则与 >5 的参考宽度计算）
    public var contentInset: UIEdgeInsets = .init(top: 0, left: 12, bottom: 0, right: 12)
    /// 2~5 等分时的按钮间距
    public var equalSpacing: CGFloat = 8
    /// 2~5 的可见等分范围（上限决定 >5 时的“参考单元宽度”）
    public var equalVisibleRange: ClosedRange<Int> = 2...5
    /// 超过 5 个时是否仍然用“5 等分”的单元宽度与间距（是则超出横滑）
    public var lockUnitToMaxEqualCount: Bool = true
    /// 尺寸变化（旋转/分屏）时是否自动重排按钮
    public var autoRelayoutForBoundsChange: Bool = true
    /// 首次构建完按钮（addSubview 完）回调——只调一次
    public var onButtonsBuilt: (([UIButton]) -> Void)?
    /// 每次布局完按钮 frame 之后回调（含旋转/尺寸变化后）——可在此重复“中间按钮凸起”
    public var onButtonsLayouted: (([UIButton]) -> Void)?
    // MARK: - 数据源
    private(set) var buttons: [UIButton] = []
    private(set) var controllers: [UIViewController] = []
    // MARK: - 选中
    private(set) var selectedIndex: Int = 0
    // MARK: - UI
    private lazy var bgImageView: UIImageView = {
        UIImageView.jobsMake { _ in }.byContentMode(.scaleToFill)
    }()
    /// 满足 `JobsTabBarCtrl().TabBar.byAlpha(1)` 的链式风格
    public lazy var TabBar: UIScrollView = {
        UIScrollView.jobsMake { _ in }
            .byShowsHorizontalScrollIndicator(NO)
            .byAlwaysBounceHorizontal(YES)
            .byClipsToBounds(NO)
            .byBackgroundColor(barBackgroundColor)
    }()

    private lazy var contentScrollView: UIScrollView = {
        UIScrollView.jobsMake { _ in }
            .byPagingEnabled(YES)
            .byBounces(NO)
            .byShowsHorizontalScrollIndicator(NO)
            .byShowsVerticalScrollIndicator(NO)
            .byDelegate(self)
            .byBackgroundColor(JobsCor.clear)
            .byScrollEnabled(isSwipeEnabled)
            .byAlwaysBounceVertical(!horizontalOnly)
            .byDirectionalLockEnabled(YES)
            .byAlwaysBounceHorizontal(YES)
    }()
    // 旧策略标记
    private var builtOnce = false
    // MARK: - Lifecycle
    open override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    open override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        layoutUI()
    }
    // MARK: - Public API
    public func setDataSource(buttons: [UIButton], controllers: [UIViewController]) {
        // 清理旧的
        self.buttons.forEach { $0.removeFromSuperview() }
        self.controllers.forEach { vc in
            if vc.parent == self {
                vc.willMove(toParent: nil)
                vc.view.removeFromSuperview()
                vc.removeFromParent()
            }
        }
        self.buttons = []
        self.controllers = []
        builtOnce = false
        // 写入新数据
        self.buttons = buttons
        self.controllers = controllers
        // 配按钮
        for (i, b) in buttons.enumerated() {
            b.byTag(i)
            b.onTap { [weak self] _ in
                self?.handleTap(at: i)
            }
            b.byAddTo(TabBar)
        }
        // 配子控制器：仅取前 N（N = min(btns, ctrls)）
        let pageCount = min(buttons.count, controllers.count)
        for i in 0..<pageCount {
            let vc = embedIfNeeded(controllers[i])
            addChild(vc)
            vc.view.byAddTo(contentScrollView)
            vc.didMove(toParent: self)
            // 可选：对子 VC 内纵向滚动控件做限制
            if suppressChildVerticalScrolls {
                suppressVertical(in: vc.view)
            }
        }
        selectedIndex = 0
        applySelectionState(animated: false)
        // 首次构建完成回调
        onButtonsBuilt?(self.buttons)
        view.setNeedsLayout()
    }
    /// 主动选中
    public func select(index: Int, animated: Bool = true) {
        guard index >= 0, index < buttons.count else { return }
        guard index < min(buttons.count, controllers.count) else {
            "请配置子控制器".toast
            return
        }
        selectedIndex = index
        applySelectionState(animated: animated)
    }
    /// 主动请求重排（适用于手动触发）
    public func requestRelayout() {
        view.setNeedsLayout()
        view.layoutIfNeeded()
    }
    // MARK: - UI
    private func setupUI() {
        view.byBackgroundColor(JobsCor.systemBackground)
        contentScrollView.byAddTo(view)
        bgImageView.byAddTo(TabBar)
        TabBar.byAddTo(view)
    }

    private func layoutUI() {
        let safeBottom = view.safeAreaInsets.bottom
        let barH = (customBarHeight ?? (49 + safeBottom))
        TabBar.byFrame(CGRect(
            x: 0,
            y: view.bounds.height - barH - barBottomOffset,
            width: view.bounds.width,
            height: barH
        ))
        bgImageView.byFrame(TabBar.bounds)
        contentScrollView.byFrame(CGRect(
            x: 0,
            y: 0,
            width: view.bounds.width,
            height: view.bounds.height - barH - barBottomOffset
        ))
        // 按钮布局
        if autoRelayoutForBoundsChange || !builtOnce {
            layoutButtonsByRule()
            builtOnce = true
            onButtonsLayouted?(buttons) // 给外部重做“凸起”等改动
        }
        // 页面布局
        layoutPages()
        syncContentOffset(animated: false)
    }
    /// 1 -> 居中；2~5 -> 等分；>5 -> 仍按“max 等分(默认 5)”的单元宽度排，超出横滑
    private func layoutButtonsByRule() {
        guard !buttons.isEmpty else {
            TabBar.contentSize = .zero
            return
        }
        let total = buttons.count
        let bounds = TabBar.bounds
        let availableW = max(0, bounds.width - contentInset.left - contentInset.right)
        let h = max(0, bounds.height - contentInset.top - contentInset.bottom)
        var frames: [CGRect] = .init(repeating: .zero, count: total)
        if total == 1 {
            // 居中：宽度取 intrinsic + padding 与 availableW 的夹取
            let b = buttons[0]
            let ideal = b.intrinsicContentSize.width
            // 取“等分 n=2”的基准宽度，避免过窄/过宽
            let n2 = max(equalVisibleRange.lowerBound, 2)
            let refW = (availableW - CGFloat(n2 - 1) * equalSpacing) / CGFloat(n2)
            let w = max(minItemWidth, min(ideal + 2 * 16, refW))
            let x = contentInset.left + (availableW - w) * 0.5
            frames[0] = CGRect(x: x, y: contentInset.top, width: w, height: h)
        } else if equalVisibleRange.contains(total) {
            // 2~5 等分
            let n = total
            let w = (availableW - CGFloat(n - 1) * equalSpacing) / CGFloat(n)
            var curX = contentInset.left
            for i in 0..<total {
                frames[i] = CGRect(x: curX, y: contentInset.top, width: w, height: h)
                curX += w + equalSpacing
            }
        } else {
            // >5：用“max 等分数”（默认 5）来确定单元宽度与间距
            let nRef = max(equalVisibleRange.upperBound, 2)
            let unitW = (availableW - CGFloat(nRef - 1) * equalSpacing) / CGFloat(nRef)
            var curX = contentInset.left
            for i in 0..<total {
                frames[i] = CGRect(x: curX, y: contentInset.top, width: unitW, height: h)
                curX += unitW + equalSpacing
            }
        }
        // 应用 frame
        for (i, f) in frames.enumerated() {
            buttons[i].byFrame(f)
        }
        // contentSize
        let widthSum: CGFloat
        if buttons.count <= equalVisibleRange.upperBound {
            widthSum = bounds.width // 不需要滚动
        } else {
            widthSum = (buttons.last!.frame.maxX) + contentInset.right
        }
        TabBar.contentSize = CGSize(width: widthSum, height: bounds.height)
    }

    private var minItemWidth: CGFloat { 60 }

    private func layoutPages() {
        let pageCount = min(buttons.count, controllers.count)
        guard pageCount > 0 else {
            contentScrollView.byContentSize(.zero)
            return
        }
        let pageW = contentScrollView.bounds.width
        let pageH = contentScrollView.bounds.height
        for i in 0..<pageCount {
            let vc = children[i]
            vc.view.byFrame(CGRect(x: CGFloat(i) * pageW, y: 0, width: pageW, height: pageH))
        }
        contentScrollView.byContentSize(CGSize(width: pageW * CGFloat(pageCount), height: pageH))
    }
    // MARK: - 交互
    public func handleTap(at index: Int) {
        if index >= min(buttons.count, controllers.count) {
            "请配置子控制器".toast
            return
        }
        select(index: index, animated: true)
    }

    public func applySelectionState(animated: Bool) {
        for (i, b) in buttons.enumerated() { b.bySelected(i == selectedIndex) }
        syncContentOffset(animated: animated)
        scrollTabBarToVisible(index: selectedIndex, animated: animated)
    }

    public func syncContentOffset(animated: Bool) {
        let pageW = contentScrollView.bounds.width
        let x = CGFloat(selectedIndex) * pageW
        contentScrollView.setContentOffset(CGPoint(x: x, y: 0), animated: animated)
    }

    public func scrollTabBarToVisible(index: Int, animated: Bool) {
        guard index < buttons.count else { return }
        let frame = buttons[index].frame.insetBy(dx: -16, dy: 0)
        TabBar.scrollRectToVisible(frame, animated: animated)
    }

    public func embedIfNeeded(_ vc: UIViewController) -> UIViewController {
        if vc is UINavigationController { return vc };return UINavigationController(rootViewController: vc)
    }

    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard horizontalOnly, scrollView === contentScrollView else { return }
        if scrollView.contentOffset.y != 0 {
            scrollView.contentOffset.y = 0
        }
    }
    // MARK: - 子 VC 内纵向滚动禁用（可选启用）
    private func suppressVertical(in root: UIView) {
        if let tv = root as? UITableView {
            tv
                .byScrollEnabled(false)
                .byShowsVerticalScrollIndicator(false)
                .byAlwaysBounceVertical(false)
        } else if let cv = root as? UICollectionView {
            if let flow = cv.collectionViewLayout as? UICollectionViewFlowLayout,
               flow.scrollDirection == .horizontal {
                // 保留横向
                cv
                    .byShowsVerticalScrollIndicator(false)
                    .byAlwaysBounceVertical(false)
            } else {
                cv
                    .byScrollEnabled(false)
                    .byShowsVerticalScrollIndicator(false)
                    .byAlwaysBounceVertical(false)
            }
        } else if let sv = root as? UIScrollView {
            sv
                .byShowsVerticalScrollIndicator(false)
                .byAlwaysBounceVertical(false)
            // 如需“一刀切完全不滚”，可加：sv.isScrollEnabled = false
        }
        root.subviews.forEach { suppressVertical(in: $0) }
    }
    // MARK: - UIScrollViewDelegate（页切换同步）
    public func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        guard scrollView === contentScrollView else { return }
        let page = Int(round(scrollView.contentOffset.x / max(scrollView.bounds.width, 1)))
        if page != selectedIndex {
            selectedIndex = page
            applySelectionState(animated: true)
        }
    }

    public func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        guard scrollView === contentScrollView else { return }
        let page = Int(round(scrollView.contentOffset.x / max(scrollView.bounds.width, 1)))
        if page != selectedIndex {
            selectedIndex = page
            applySelectionState(animated: false)
        }
    }
}
// MARK: - 链式扩展
extension JobsTabBarCtrl {
    // 基础布尔/数值/对象配置
    @discardableResult public func bySwipeEnabled(_ flag: Bool) -> Self {
        self.isSwipeEnabled = flag
        return self
    }
    @discardableResult public func byBarBackgroundColor(_ color: UIColor) -> Self {
        self.barBackgroundColor = color
        return self
    }
    @discardableResult public func byCustomBarHeight(_ height: CGFloat?) -> Self {
        self.customBarHeight = height
        return self
    }
    @discardableResult public func byBarBottomOffset(_ offset: CGFloat) -> Self {
        self.barBottomOffset = offset
        return self
    }
    @discardableResult public func byBarBackgroundImage(_ image: UIImage?) -> Self {
        self.barBackgroundImage = image
        return self
    }
    // 布局策略
    @discardableResult public func byContentInset(_ inset: UIEdgeInsets) -> Self {
        self.contentInset = inset
        return self
    }
    @discardableResult public func byEqualSpacing(_ spacing: CGFloat) -> Self {
        self.equalSpacing = spacing
        return self
    }
    @discardableResult public func byEqualVisibleRange(_ range: ClosedRange<Int>) -> Self {
        self.equalVisibleRange = range
        return self
    }
    @discardableResult public func byLockUnitToMaxEqualCount(_ flag: Bool) -> Self {
        self.lockUnitToMaxEqualCount = flag
        return self
    }
    @discardableResult public func byAutoRelayoutForBoundsChange(_ flag: Bool) -> Self {
        self.autoRelayoutForBoundsChange = flag
        return self
    }
    // 横向/子滚动限制
    @discardableResult public func byHorizontalOnly(_ flag: Bool) -> Self {
        self.horizontalOnly = flag
        return self
    }
    @discardableResult public func bySuppressChildVerticalScrolls(_ flag: Bool) -> Self {
        self.suppressChildVerticalScrolls = flag
        return self
    }
    // 回调（支持链式设置）
    @discardableResult public func onButtonsBuilt(_ block: @escaping ([UIButton]) -> Void) -> Self {
        self.onButtonsBuilt = block
        return self
    }
    @discardableResult public func onButtonsLayouted(_ block: @escaping ([UIButton]) -> Void) -> Self {
        self.onButtonsLayouted = block
        return self
    }

    @discardableResult
    public func byDataSource(buttons: [UIButton], controllers: [UIViewController]) -> Self {
        self.setDataSource(buttons: buttons, controllers: controllers)
        return self
    }
    /// 安全弱持有 owner 的包装，避免在外部写 [weak self]
    @discardableResult
    public func onButtonsLayoutedWeakOwner(
        _ block: @escaping (_ owner: JobsTabBarCtrl, _ btns: [UIButton]) -> Void
    ) -> Self {
        self.onButtonsLayouted = { [weak self] btns in
            guard let self else { return }
            block(self, btns)
        };return self
    }
}
