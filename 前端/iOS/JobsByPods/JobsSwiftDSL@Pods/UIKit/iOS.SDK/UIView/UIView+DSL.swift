//
//  UIView+DSL.swift
//  JobsByUIKit
//
//  Created by Jobs on 2026年5月13日，星期三.
//

#if os(OSX)
import AppKit
#elseif os(iOS) || os(tvOS)
import UIKit
#endif

import JobsSwiftBaseDefines

// MARK: - 直接赋值@单参数
extension UIView {
    @discardableResult
    public func byHidden(_ hidden: Bool) -> Self {
        self.isHidden = hidden
        return self
    }

    @discardableResult
    public func byAlpha(_ a: CGFloat) -> Self {
        self.alpha = a
        return self
    }

    @discardableResult
    public func byTintColor(_ color: UIColor?) -> Self {
        let slot = "UIView.tintColor"
        if let key = color?.jobsThemeColorKey {
            JobsThemeCenter.shared.bind(self, slot: slot) { object, center in
                guard let view = object as? UIView else { return }
                view.tintColor = center.resolvedColor(key)
            };return self
        }
        JobsThemeCenter.shared.unbind(self, slot: slot)
        self.tintColor = color
        return self
    }

    /// 统一圆角：按钮走 UIButton.Configuration 方案，其他视图保持原始 layer 逻辑
    @discardableResult
    public func byCornerRadius(_ radius: CGFloat?) -> Self {
        let r = max(0, radius ?? 0.0)
        if let btn = self as? UIButton {
            if #available(iOS 15.0, *), var cfg = btn.configuration {
                cfg.cornerStyle = .fixed
                var bg = cfg.background
                bg.cornerRadius = r
                cfg.background = bg
                btn.configuration = cfg
            }
            btn.layer.cornerRadius = r
            if #available(iOS 13.0, *) {
                btn.layer.cornerCurve = .continuous
            }
            btn.clipsToBounds = (r > 0)
            return self
        }
        self.layer.cornerRadius = r
        return self
    }
    /// 裁剪超出边界
    @discardableResult
    public func byClipsToBounds(_ enabled: Bool = true) -> Self {
        self.clipsToBounds = enabled
        return self
    }

    @discardableResult
    public func byMasksToBounds(_ masksToBounds: Bool?) -> Self {
        self.layer.masksToBounds = masksToBounds ?? false
        return self
    }
    /// 用 CoreAnimation 的圆角渲染，指定参与圆角的角（CACornerMask），再配合 layer.cornerRadius 生效。
    /// layerMaxXMaxYCorner – 右下角
    /// layerMaxXMinYCorner – 右上角
    /// layerMinXMaxYCorner – 左下角
    /// layerMinXMinYCorner – 左上角
    @available(iOS 11.0, *)
    @discardableResult
    public func byMaskedCorners(_ corners: CACornerMask?) -> Self {
        self.layer.maskedCorners = corners ?? []
        return self
    }

    @discardableResult
    public func byBorderColor(_ color: UIColor?) -> Self {
        self.layer.borderColor = color?.cgColor
        if color == nil { self.layer.borderWidth = 0 };return self
    }

    @discardableResult
    public func byZPosition(_ z: CGFloat) -> Self {
        self.layer.zPosition = z
        return self
    }

    @discardableResult
    public func byBorderWidth(_ width: CGFloat) -> Self {
        self.layer.borderWidth = width
        return self
    }

    @discardableResult
    public func byShadowRadius(_ radius: CGFloat) -> Self {
        self.layer.shadowRadius = radius
        return self
    }

    @discardableResult
    public func byShadowColor(_ color: UIColor?) -> Self {
        self.layer.shadowColor = color?.cgColor
        return self
    }

    @discardableResult
    public func byShadowOpacity(_ opacity: Float = 0.0) -> Self {
        self.layer.shadowOpacity = opacity
        return self
    }

    @discardableResult
    public func byShadowOffset(_ offset: CGSize = CGSize.zero) -> Self {
        self.layer.shadowOffset = offset
        return self
    }
    /// 2D/3D 变换
    @discardableResult
    public func byTransform(_ transf: CGAffineTransform) -> Self {
        self.transform = transf
        return self
    }

    @available(iOS 13.0, *)
    @discardableResult
    public func byTransform3D(_ t3d: CATransform3D) -> Self {
        self.transform3D = t3d
        return self
    }
    /// 缩放因子（渲染分辨率）
    @available(iOS 4.0, *)
    @discardableResult
    public func byContentScaleFactor(_ scale: CGFloat) -> Self {
        self.contentScaleFactor = scale
        return self
    }
    /// 锚点（注意：会影响 frame，需要配合 position/center 调整）
    @available(iOS 16.0, *)
    @discardableResult
    public func byAnchorPoint(_ anchor: CGPoint) -> Self {
        self.anchorPoint = anchor
        return self
    }
    /// 触摸行为
    @discardableResult
    public func byMultipleTouchEnabled(_ enabled: Bool) -> Self {
        self.isMultipleTouchEnabled = enabled
        return self
    }

    @discardableResult
    public func byExclusiveTouch(_ enabled: Bool) -> Self {
        self.isExclusiveTouch = enabled
        return self
    }
    /// 是否对子视图做 autoresize
    @discardableResult
    public func byAutoresizesSubviews(_ enabled: Bool) -> Self {
        self.autoresizesSubviews = enabled
        return self
    }
    /// 自伸缩掩码
    @discardableResult
    public func byAutoresizingMask(_ mask: UIView.AutoresizingMask) -> Self {
        self.autoresizingMask = mask
        return self
    }
    /// 传统 layoutMargins
    @available(iOS 8.0, *)
    @discardableResult
    public func byLayoutMargins(_ insets: UIEdgeInsets) -> Self {
        self.layoutMargins = insets
        return self
    }
    /// 方向化的 layoutMargins（更现代）
    @available(iOS 11.0, *)
    @discardableResult
    public func byDirectionalLayoutMargins(_ insets: NSDirectionalEdgeInsets) -> Self {
        self.directionalLayoutMargins = insets
        return self
    }
    /// 是否继承父视图的 layoutMargins
    @available(iOS 8.0, *)
    @discardableResult
    public func byPreservesSuperviewLayoutMargins(_ enabled: Bool) -> Self {
        self.preservesSuperviewLayoutMargins = enabled
        return self
    }
    /// 是否将 safeArea 纳入 layoutMargins 计算
    @available(iOS 11.0, *)
    @discardableResult
    public func byInsetsLayoutMarginsFromSafeArea(_ enabled: Bool) -> Self {
        self.insetsLayoutMarginsFromSafeArea = enabled
        return self
    }

    @discardableResult
    public func byContentMode(_ mode: UIView.ContentMode) -> Self {
        self.contentMode = mode
        return self
    }

    @discardableResult
    public func byTag(_ T: Int) -> Self {
        self.tag = T
        return self
    }

    @discardableResult
    public func byUserInteractionEnabled(_ enabled: Bool?) -> Self {
        self.isUserInteractionEnabled = enabled ?? false
        return self
    }
    /// 开启 AutoLayout（等价于 translatesAutoresizingMaskIntoConstraints = false）
    @discardableResult
    public func byAutoLayout() -> Self {
        self.translatesAutoresizingMaskIntoConstraints = false
        return self
    }
    /// 直接设置 translatesAutoresizingMaskIntoConstraints
    @discardableResult
    public func byTranslatesAutoresizingMaskIntoConstraints(_ value: Bool) -> Self {
        self.translatesAutoresizingMaskIntoConstraints = value
        return self
    }
}
// MARK: - 闭包重载@单参数
extension UIView {
    @discardableResult
    public func byHidden(_ builder: () -> Bool) -> Self {
        self.isHidden = builder()
        return self
    }

    @discardableResult
    public func byAlpha(_ builder: () -> CGFloat) -> Self {
        self.alpha = builder()
        return self
    }

    @discardableResult
    public func byTintColor(_ builder: () -> UIColor?) -> Self {
        byTintColor(builder())
    }

    @discardableResult
    public func byCornerRadius(_ builder: () -> CGFloat?) -> Self {
        let radius = builder()
        return self.byCornerRadius(radius)
    }

    @discardableResult
    public func byClipsToBounds(_ builder: () -> Bool) -> Self {
        self.clipsToBounds = builder()
        return self
    }

    @discardableResult
    public func byMasksToBounds(_ builder: () -> Bool?) -> Self {
        self.layer.masksToBounds = builder() ?? false
        return self
    }

    @available(iOS 11.0, *)
    @discardableResult
    public func byMaskedCorners(_ builder: () -> CACornerMask?) -> Self {
        self.layer.maskedCorners = builder() ?? []
        return self
    }

    @discardableResult
    public func byBorderColor(_ builder: () -> UIColor?) -> Self {
        let color = builder()
        self.layer.borderColor = color?.cgColor
        if color == nil { self.layer.borderWidth = 0 };return self
    }

    @discardableResult
    public func byZPosition(_ builder: () -> CGFloat) -> Self {
        self.layer.zPosition = builder()
        return self
    }

    @discardableResult
    public func byBorderWidth(_ builder: () -> CGFloat) -> Self {
        self.layer.borderWidth = builder()
        return self
    }

    @discardableResult
    public func byShadowRadius(_ builder: () -> CGFloat) -> Self {
        self.layer.shadowRadius = builder()
        return self
    }

    @discardableResult
    public func byShadowColor(_ builder: () -> UIColor?) -> Self {
        self.layer.shadowColor = builder()?.cgColor
        return self
    }

    @discardableResult
    public func byShadowOpacity(_ builder: () -> Float) -> Self {
        self.layer.shadowOpacity = builder()
        return self
    }

    @discardableResult
    public func byShadowOffset(_ builder: () -> CGSize) -> Self {
        self.layer.shadowOffset = builder()
        return self
    }

    @discardableResult
    public func byTransform(_ builder: () -> CGAffineTransform) -> Self {
        self.transform = builder()
        return self
    }

    @available(iOS 13.0, *)
    @discardableResult
    public func byTransform3D(_ builder: () -> CATransform3D) -> Self {
        self.transform3D = builder()
        return self
    }

    @available(iOS 4.0, *)
    @discardableResult
    public func byContentScaleFactor(_ builder: () -> CGFloat) -> Self {
        self.contentScaleFactor = builder()
        return self
    }

    @available(iOS 16.0, *)
    @discardableResult
    public func byAnchorPoint(_ builder: () -> CGPoint) -> Self {
        self.anchorPoint = builder()
        return self
    }

    @discardableResult
    public func byMultipleTouchEnabled(_ builder: () -> Bool) -> Self {
        self.isMultipleTouchEnabled = builder()
        return self
    }

    @discardableResult
    public func byExclusiveTouch(_ builder: () -> Bool) -> Self {
        self.isExclusiveTouch = builder()
        return self
    }

    @discardableResult
    public func byAutoresizesSubviews(_ builder: () -> Bool) -> Self {
        self.autoresizesSubviews = builder()
        return self
    }

    @discardableResult
    public func byAutoresizingMask(_ builder: () -> UIView.AutoresizingMask) -> Self {
        self.autoresizingMask = builder()
        return self
    }

    @available(iOS 8.0, *)
    @discardableResult
    public func byLayoutMargins(_ builder: () -> UIEdgeInsets) -> Self {
        self.layoutMargins = builder()
        return self
    }

    @available(iOS 11.0, *)
    @discardableResult
    public func byDirectionalLayoutMargins(_ builder: () -> NSDirectionalEdgeInsets) -> Self {
        self.directionalLayoutMargins = builder()
        return self
    }

    @available(iOS 8.0, *)
    @discardableResult
    public func byPreservesSuperviewLayoutMargins(_ builder: () -> Bool) -> Self {
        self.preservesSuperviewLayoutMargins = builder()
        return self
    }

    @available(iOS 11.0, *)
    @discardableResult
    public func byInsetsLayoutMarginsFromSafeArea(_ builder: () -> Bool) -> Self {
        self.insetsLayoutMarginsFromSafeArea = builder()
        return self
    }

    @discardableResult
    public func byContentMode(_ builder: () -> UIView.ContentMode) -> Self {
        self.contentMode = builder()
        return self
    }

    @discardableResult
    public func byTag(_ builder: () -> Int) -> Self {
        self.tag = builder()
        return self
    }

    @discardableResult
    public func byUserInteractionEnabled(_ builder: () -> Bool?) -> Self {
        self.isUserInteractionEnabled = builder() ?? false
        return self
    }

    @discardableResult
    public func byTranslatesAutoresizingMaskIntoConstraints(_ builder: () -> Bool) -> Self {
        self.translatesAutoresizingMaskIntoConstraints = builder()
        return self
    }
}

extension UIView {
    // MARK: 设置UI
    /// 统一在一个回调里配置 layer
    @discardableResult
    public func byLayer(_ config: (CALayer) -> Void) -> Self {
        config(layer)
        return self
    }

    @discardableResult
    public func byAddArranged(_ stack: UIStackView) -> Self {
        stack.addArrangedSubview(self)
        return self
    }

    @discardableResult
    public func byInsertSublayer(_ layer: CALayer, at index: UInt32) -> Self {
        layer.insertSublayer(layer, at: index)
        return self
    }

    @discardableResult
    public func byInsertSublayer(_ layer: CALayer, below sibling: CALayer?) -> Self {
        layer.insertSublayer(layer, below: sibling)
        return self
    }

    @discardableResult
    public func byInsertSublayer(_ layer: CALayer, above sibling: CALayer?) -> Self {
        layer.insertSublayer(layer, above: sibling)
        return self
    }

    @discardableResult
    public func byAddSublayer(_ layer: CALayer) -> Self {
        self.layer.addSublayer(layer)
        return self
    }
    /// 是否可见：true 显示；false 隐藏（折叠布局）
    @MainActor
    @discardableResult
    public func byVisible(_ visible: Bool) -> Self {
        self.byHidden(!visible)
        self.byAlpha(visible ? 1 : 0)
        return self
    }
    /// 【优点】
    /// 兼容更早系统（老 iOS 也能用）。
    /// 可以做“非等半径圆角”、不规则路径、甚至切角/异形（这点 maskedCorners 做不到）。
    /// 【 致命点 / 常见坑】
    /// 依赖 self.bounds：你现在的实现如果在 AutoLayout 前调用，bounds 可能是 .zero，mask 就错了。通常要在 layoutSubviews / layoutSublayers(of:) 里更新，或者在尺寸确定后再调一次。
    /// 会影响阴影：layer.mask 会把阴影也一起裁掉（阴影经常“消失”），除非你额外用外层容器做 shadow。
    /// 动态变化时需要反复更新 maskPath，否则旋转、尺寸变化圆角会错。
    @discardableResult
    public func byCornerRaduis(corner: UIRectCorner, raduis: CGFloat) -> Self {
        if self.bounds == .zero { return self }
        let maskPath = UIBezierPath(roundedRect: self.bounds,
                                    byRoundingCorners: corner,
                                    cornerRadii: CGSize(width: raduis, height: raduis))
        self.layer.mask = CAShapeLayer().byFrame(self.bounds).byPath(maskPath.cgPath)
        self.clipsToBounds = true
        return self
    }
    // MARK: - UIView · Subview Hierarchy
    /// 添加子视图（链式）✅ 返回调用者（父视图）
    @discardableResult
    public func byAddSubviewRetSuper(_ view: UIView) -> Self {
        addSubview(view)
        return self //
    }
    /// 添加子视图（链式）✅ 返回子视图
    @discardableResult
    public func byAddSubviewRetSub<T: UIView>(_ view: T) -> T {
        addSubview(view)
        return view
    }
    /// 把当前视图添加到父视图；基础装配不依赖 SnapKit。
    @discardableResult
    public func byAddTo(_ superView: UIView?) -> Self {
        superView?.addSubview(self)
        return self
    }
    /// 在指定层级插入 ✅ 返回调用者（父视图）
    @discardableResult
    public func byInsertSubview(_ view: UIView, at index: Int) -> Self {
        insertSubview(view, at: index)
        return self
    }
    /// 在指定层级插入 ✅ 返回子视图
    @discardableResult
    public func byInsertSubviewRetSub<T: UIView>(_ view: T, at index: Int) -> T {
        insertSubview(view, at: index)
        return view
    }
    /// 在某视图之下插入 ✅ 返回调用者（父视图）
    @discardableResult
    public func byInsertSubview(_ view: UIView, below sibling: UIView) -> Self {
        insertSubview(view, belowSubview: sibling)
        return self
    }
    /// 在某视图之下插入 ✅ 返回子视图
    @discardableResult
    public func byInsertSubviewRetSub<T: UIView>(_ view: T, below sibling: UIView) -> T {
        insertSubview(view, belowSubview: sibling)
        return view
    }
    /// 在某视图之上插入 ✅ 返回调用者（父视图）
    @discardableResult
    public func byInsertSubview(_ view: UIView, above sibling: UIView) -> Self {
        insertSubview(view, aboveSubview: sibling)
        return self
    }
    /// 在某视图之上插入 ✅ 返回子视图
    @discardableResult
    public func byInsertSubviewRetSub<T: UIView>(_ view: T, above sibling: UIView) -> T {
        insertSubview(view, aboveSubview: sibling)
        return view
    }
    /// 交换两个下标的子视图 ✅ 返回调用者（父视图）
    @discardableResult
    public func byExchangeSubview(at i: Int, with j: Int) -> Self {
        exchangeSubview(at: i, withSubviewAt: j)
        return self
    }
    /// 置顶 ✅ 返回调用者（父视图）
    @discardableResult
    public func byBringToFront(_ view: UIView) -> Self {
        bringSubviewToFront(view)
        return self
    }
    /// 置顶 ✅ 返回子视图
    @discardableResult
    public func byBringToFrontRetSub<T: UIView>(_ view: T) -> T {
        bringSubviewToFront(view)
        return view
    }
    /// 置底 ✅ 返回调用者（父视图）
    @discardableResult
    public func bySendToBack(_ view: UIView) -> Self {
        sendSubviewToBack(view)
        return self
    }
    /// 置底 ✅ 返回子视图
    @discardableResult
    public func bySendToBackRetSub<T: UIView>(_ view: T) -> T {
        sendSubviewToBack(view)
        return view
    }
    /// 移除自身 ✅ 返回调用者（父视图）
    @discardableResult
    public func byRemoveFromSuperview() -> Self {
        removeFromSuperview()
        return self
    }
    /// 移除所有子视图（便捷）
    @discardableResult
    public func byRemoveAllSubviews() -> Self {
        subviews.forEach { $0.removeFromSuperview() };return self
    }
    // MARK: - UIView · Layout Triggers
    /// 标记需要布局
    @discardableResult
    public func bySetNeedsLayout() -> Self {
        setNeedsLayout()
        return self
    }
    /// 立即布局
    @discardableResult
    public func byLayoutIfNeeded() -> Self {
        layoutIfNeeded()
        return self
    }
    /// 自适应到指定尺寸（仅设置，不触发布局）
    @discardableResult
    public func bySizeThatFits(_ size: CGSize) -> Self {
        _ = sizeThatFits(size)
        return self
    }
    /// 自身尺寸适配
    @discardableResult
    public func bySizeToFit() -> Self {
        sizeToFit()
        return self
    }
    /// 手势封装：添加手势以后返回这个手势本身@常用于链式调用
    @discardableResult
    public func jobs_addGestureRetView<T: UIGestureRecognizer>(_ gesture: T?) -> Self {
        guard let gesture = gesture else { return self }
        addGestureRecognizer(gesture)
        return self
    }
    /// 手势封装：添加手势以后返回这个手势本身@常用于链式调用
    @discardableResult
    public func jobs_addGesture<T: UIGestureRecognizer>(_ gesture: T?) -> T? {
        guard let gesture = gesture else { return nil }
        addGestureRecognizer(gesture)
        return gesture
    }
    /// 刷新UI@标记即可（让系统合帧处理）：适合大多数情况
    @MainActor
    @discardableResult
    public func refresh()-> Self{
        setNeedsLayout()  // 下帧再布局
        layoutIfNeeded()  // 立刻完成布局（当前 runloop）
        return self
    }
    /// 刷新UI@标记即可（让系统合帧处理）：适合大多数情况
    @MainActor
    @discardableResult
    public func refreshNow() -> Self {
        setNeedsLayout()     // 下帧再布局
        /// 最后同步布局会改变尺寸/路径，应在布局完成后再决定要画什么
        /// 所以把 setNeedsDisplay() 放到 layoutIfNeeded() 之后 更合理
        layoutIfNeeded()     // 立刻完成布局（当前 runloop）
        /// 只当确实重写了 draw(_:) /或者 使用自定义 layerClass 自绘时才需要 setNeedsDisplay()
        setNeedsDisplay()    // 标记（下帧）需要重绘（基于新布局），不是布局
        // 如必须同步把图也画出来（少用，重）：
        // layer.displayIfNeeded()
        return self
    }

    @discardableResult
    public func byActivate() -> Self {
        // 下一帧：让父视图先布局，再让自己重建，避免首帧 bounds==0 的问题
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            superview?.setNeedsLayout()
            superview?.layoutIfNeeded()
            setNeedsLayout()
        };return self
    }
}
// MARK: 修改背景色
private var kBgColorMapKey: UInt8 = 0
private extension UIView {
    func jobsApplyBackgroundColor(
        _ color: UIColor?,
        for state: UIControl.State
    ) {
        // ===== UIButton =====
        if let button = self as? UIButton {
            // -------- iOS 15+ --------
            if #available(iOS 15.0, *) {
                // 1. 存颜色
                var map = objc_getAssociatedObject(button, &kBgColorMapKey) as? [Int: UIColor] ?? [:]
                map[Int(state.rawValue)] = color
                objc_setAssociatedObject(
                    button,
                    &kBgColorMapKey,
                    map,
                    .OBJC_ASSOCIATION_RETAIN_NONATOMIC
                )
                // 2. 初始化 configuration
                if button.configuration == nil {
                    button.configuration = UIButton.Configuration.plain()
                        .byBackgroundPatch { bg in
                            bg.backgroundColor = JobsCor.clear
                            bg.backgroundColorTransformer = nil
                        }
                }
                button.updateConfiguration()
                // 3. 状态渲染
                button.configurationUpdateHandler = { btn in
                    guard var c = btn.configuration else { return }
                    let colors = objc_getAssociatedObject(btn, &kBgColorMapKey) as? [Int: UIColor]
                    let normalKey = Int(UIControl.State.normal.rawValue)
                    let highlightedKey = Int(UIControl.State.highlighted.rawValue)
                    let selectedKey = Int(UIControl.State.selected.rawValue)
                    let disabledKey = Int(UIControl.State.disabled.rawValue)
                    let wantedKey: Int
                    if !btn.isEnabled {
                        wantedKey = disabledKey
                    } else if btn.isHighlighted {
                        wantedKey = highlightedKey
                    } else if btn.isSelected {
                        wantedKey = selectedKey
                    } else {
                        wantedKey = normalKey
                    }
                    // ✅关键：没有设置对应状态色，就回退到 normal（避免变成 nil 触发系统蓝色高亮）
                    let resolvedColor =
                        colors?[wantedKey]
                        ?? colors?[normalKey]
                        ?? JobsCor.clear
                    c.background.backgroundColor = resolvedColor
                    btn.configuration = c
                }
                // 4. 立刻生效
                button.updateConfiguration()
                return
            }
            // -------- iOS14- --------
            button.byBackgroundImage(color?.byImage(), for: state)
            return
        }
        // ===== UIView（无状态）=====
        backgroundColor = color
    }
}

extension UIView {
    @discardableResult
    public func byBackgroundColor(
        _ color: UIColor?,
        for state: UIControl.State = .normal
    ) -> Self {
        let slot = "UIView.backgroundColor.\(state.rawValue)"
        if let key = color?.jobsThemeColorKey {
            JobsThemeCenter.shared.bind(
                self,
                slot: slot
            ) { object, center in
                (object as? UIView)?.jobsApplyBackgroundColor(
                    center.resolvedColor(key),
                    for: state
                )
            };return self
        }
        JobsThemeCenter.shared.unbind(self, slot: slot)
        jobsApplyBackgroundColor(color, for: state)
        return self
    }
}
