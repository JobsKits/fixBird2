//
//  UIAlertController.swift
//  JobsByUIKit
//
//  Created by Jobs on 2026年5月13日，星期三.
//

#if os(OSX)
import AppKit
#elseif os(iOS) || os(tvOS)
import UIKit
#endif

import JobsSwiftDSL
import SnapKit
import NSObject_Rx
import SDWebImage
import Kingfisher

#if canImport(JobsSwiftBlock)
import JobsSwiftBlock
#endif
#if canImport(JobsSwiftBaseDefines)
import JobsSwiftBaseDefines
#endif
#if canImport(RxSwift) && canImport(RxCocoa)
import RxSwift
import RxCocoa
#endif

// ================================== 构建 & 配置 ==================================
extension UIAlertController {
    // MARK: 工厂
    @discardableResult
    public static func makeAlert(_ title: String? = nil,
                          _ message: String? = nil) -> UIAlertController {
        UIAlertController(title: title, message: message, preferredStyle: .alert)
    }

    @discardableResult
    public static func makeActionSheet(_ title: String? = nil,
                                _ message: String? = nil) -> UIAlertController {
        UIAlertController(title: title, message: message, preferredStyle: .actionSheet)
    }
    // MARK: 基础属性
    @discardableResult
    public func byMessage(_ message: String?) -> Self {
        self.message = message
        return self
    }

    @available(iOS 16.0, *)
    @discardableResult
    public func bySeverity(_ severity: UIAlertControllerSeverity) -> Self {
        self.severity = severity
        return self
    }

    @discardableResult
    public func byTintColor(_ color: UIColor?) -> Self {
        if let color { self.view.tintColor = color };return self
    }
    // MARK: Actions
    @discardableResult
    public func byAddAction(title: String,
                     style: UIAlertAction.Style = .default,
                     isPreferred: Bool = false,
                     handler: ((UIAlertAction) -> Void)? = nil) -> Self {
        let action = UIAlertAction(title: title, style: style, handler: handler)
        self.addAction(action)
        if isPreferred { self.preferredAction = action };return self
    }

    @discardableResult
    public func byAddAction(title: String,
                     style: UIAlertAction.Style = .default,
                     isPreferred: Bool = false,
                     byActionBlock handler: @escaping (_ alert: UIAlertController, _ action: UIAlertAction) -> Void) -> Self {
        let action = UIAlertAction(title: title, style: style) { [weak self] act in
            guard let alert = self else { return }
            handler(alert, act)
        }
        self.addAction(action)
        if isPreferred { self.preferredAction = action };return self
    }

    @discardableResult
    public func byAddOK(_ title: String = "确定".tr,
                 isPreferred: Bool = true,
                 _ handler: ((UIAlertAction) -> Void)? = nil) -> Self {
        byAddAction(title: title, style: .default, isPreferred: isPreferred, handler: handler)
    }

    @discardableResult
    public func byAddOK(_ title: String = "确定".tr,
                 isPreferred: Bool = true,
                 _ handler: @escaping (_ alert: UIAlertController, _ action: UIAlertAction) -> Void) -> Self {
        byAddAction(title: title, style: .default, isPreferred: isPreferred, byActionBlock: handler)
    }

    @discardableResult
    public func byAddCancel(_ title: String = "取消",
                     _ handler: ((UIAlertAction) -> Void)? = nil) -> Self {
        let action = UIAlertAction(title: title, style: _effectiveCancelStyle, handler: handler)
        self.addAction(action)
        if _effectiveCancelStyle == .cancel { self.preferredAction = action };return self
    }

    @discardableResult
    public func byAddCancel(_ title: String = "取消",
                     _ handler: @escaping (_ alert: UIAlertController, _ action: UIAlertAction) -> Void) -> Self {
        let action = UIAlertAction(title: title, style: _effectiveCancelStyle) { [weak self] act in
            guard let alert = self else { return }
            handler(alert, act)
        }
        self.addAction(action)
        if _effectiveCancelStyle == .cancel { self.preferredAction = action };return self
    }

    @discardableResult
    public func byAddDestructive(_ title: String,
                          handler: ((UIAlertAction) -> Void)? = nil) -> Self {
        byAddAction(title: title, style: .destructive, handler: handler)
    }

    @discardableResult
    public func byAddDestructive(_ title: String,
                          withAlert handler: @escaping (_ alert: UIAlertController, _ action: UIAlertAction) -> Void) -> Self {
        byAddAction(title: title, style: .destructive, byActionBlock: handler)
    }

    @discardableResult
    public func byPreferredAction(_ action: UIAlertAction?) -> Self {
        self.preferredAction = action
        return self
    }

    @discardableResult
    public func byPreferredActionTitle(_ title: String) -> Self {
        if let hit = actions.first(where: { $0.title == title }) { self.preferredAction = hit };return self
    }
    // MARK: TextFields（基础）
    public func textField(at index: Int) -> UITextField? {
        guard let tfs = self.textFields, (0..<tfs.count).contains(index) else { return nil };return tfs[index]
    }

    @discardableResult
    public func byAddTextField(_ configure: ((UITextField) -> Void)? = nil) -> Self {
        self.addTextField { tf in
            configure?(tf)
        };return self
    }
}
// ================================== TextField：RAC 监听（可选） ==================================
#if canImport(RxSwift) && canImport(RxCocoa)
import RxSwift
import RxCocoa

final class JobsTextFieldDelegateProxy:
    DelegateProxy<UITextField, UITextFieldDelegate>,
    DelegateProxyType,
    UITextFieldDelegate {
    init(textField: UITextField) {
        super.init(parentObject: textField, delegateProxy: JobsTextFieldDelegateProxy.self)
    }

    public static func registerKnownImplementations() {
        self.register { JobsTextFieldDelegateProxy(textField: $0) }
    }

    public static func currentDelegate(for object: UITextField) -> UITextFieldDelegate? { object.delegate }
    public static func setCurrentDelegate(_ delegate: UITextFieldDelegate?, to object: UITextField) { object.delegate = delegate }
}

extension UIAlertController {
    @discardableResult
    public func byAddTextField(placeholder: String?,
                        text: String? = nil,
                        isSecure: Bool = false,
                        keyboard: UIKeyboardType = .default,
                        returnKey: UIReturnKeyType = .done,
                        textContentType: UITextContentType = .password,
                        leftView: UIView? = nil,
                        rightView: UIView? = nil,
                        autocorrection: UITextAutocorrectionType = .default,
                        capitalization: UITextAutocapitalizationType = .none,
                        contentType: UITextContentType? = nil,
                        // 样式（可选）
                        borderWidth: CGFloat? = nil,
                        borderColor: UIColor? = nil,
                        cornerRadius: CGFloat? = nil,
                        onChange: @escaping (_ alert: UIAlertController,
                                             _ tf: UITextField,
                                             _ input: String,
                                             _ oldText: String,
                                             _ isDeleting: Bool) -> Void) -> Self {
        self.addTextField { [weak self] tf in
            tf.byPlaceholder(placeholder)
                .byText(text)
                .byReturnKeyType(returnKey)
                .byTextContentType(textContentType)
                .byLeftView(leftView)
                .byRightView(rightView)
                .bySecureTextEntry(isSecure)
                .byKeyboardType(keyboard)
                .byAutocorrectionType(autocorrection)
                .byAutocapitalizationType(capitalization)
                .byTextContentType(contentType)
            var didStyle = false
            if let w = borderWidth { tf.layer.borderWidth = w; didStyle = true }
            if let c = borderColor { tf.layer.borderColor = c.cgColor; didStyle = true }
            if let r = cornerRadius { tf.layer.cornerRadius = r; didStyle = true }
            if didStyle {
                tf.byMasksToBounds(true)
                if #available(iOS 13.0, *) { tf.layer.cornerCurve = .continuous }
            }
            guard let alert = self else { return }
            var previousText = tf.text ?? ""
            tf.rx.controlEvent(.editingChanged)
                .subscribe(onNext: { [weak alert, weak tf] in
                    guard let alert = alert, let tf = tf else { return }
                    let currentText = tf.text ?? ""
                    let isDeleting = currentText.count < previousText.count
                    var input = ""
                    if !isDeleting {
                        if currentText.hasPrefix(previousText) {
                            input = String(currentText.dropFirst(previousText.count))
                        } else {
                            input = currentText
                        }
                    }
                    onChange(alert, tf, input, previousText, isDeleting)
                    previousText = currentText
                })
                .disposed(by: tf.disposeBag)
        };return self
    }
}
#endif
// ================================== 统一锚点 & 一行展示 ==================================
extension UIAlertController {
    public enum Anchor {
        case auto
        case center   // 屏幕中心（无箭头）
        case barButton(UIBarButtonItem)
        case view(UIView, CGRect? = nil, UIPopoverArrowDirection = [])
    }

    @discardableResult
    public func byAnchor(_ anchor: Anchor, host: UIViewController) -> Self {
        guard let pop = self.popoverPresentationController else { return self }
        switch anchor {
        /// 处理 .barButton 分支
        case .barButton(let item):
            pop.barButtonItem = item
        /// 处理 .view 分支
        case .view(let v, let rect, let arrows):
            pop.sourceView = v
            pop.sourceRect = rect ?? v.bounds
            pop.permittedArrowDirections = arrows
        /// 处理 .auto 分支
        case .auto:
            pop.sourceView = host.view
            pop.sourceRect = CGRect(x: host.view.bounds.midX,
                                    y: host.view.bounds.maxY - 1,
                                    width: 1, height: 1)
            pop.permittedArrowDirections = []
        /// 处理 .center 分支
        case .center:
            pop.sourceView = host.view
            pop.sourceRect = CGRect(x: host.view.bounds.midX,
                                    y: host.view.bounds.midY,
                                    width: 1, height: 1)
            pop.permittedArrowDirections = []
        };return self
    }
    /// present：与系统转场协调执行（本地背景“强制同步安装”，网络图“转场后淡入”）
    @discardableResult
    public func byPresent(_ vc: UIViewController,
                          anchor: Anchor = .auto,
                          animated: Bool = true,
                          completion: (jobsByVoidBlock)? = nil) -> Self {
        let isSheet: Bool = {
            switch vc.modalPresentationStyle {
            /// 合并处理 .pageSheet、.formSheet、.automatic 分支
            case .pageSheet, .formSheet, .automatic: return true
            /// 未匹配已知分支时执行兜底处理
            default: return false
            }
        }()
        let host = (isSheet ? vc.presentingViewController : nil) ?? vc
        if self.popoverPresentationController != nil {
            self.byAnchor(anchor, host: host)
        }
        // 先把本地背景同步装好，避免首帧空白
        self.loadViewIfNeeded()
        self.view.setNeedsLayout()
        self.view.layoutIfNeeded()
        _installLocalBGIfPending()
        host.present(self, animated: animated) { [weak self] in
            guard let self else { completion?(); return }
            if let tc = self.transitionCoordinator {
                tc.animate(alongsideTransition: { _ in
                    UIView.performWithoutAnimation {
                        self._installLocalBGIfPending()
                        self._drainPreBGTasks()
                    }
                }, completion: { _ in
                    self._drainPostBGTasks()
                    DispatchQueue.main.async { [weak self] in
                        self?._installLocalBGIfPending()
                        self?._drainPostBGTasks()
                    }
                })
            } else {
                UIView.performWithoutAnimation {
                    self._installLocalBGIfPending()
                    self._drainPreBGTasks()
                }
                self._drainPostBGTasks()
                DispatchQueue.main.async { [weak self] in
                    self?._installLocalBGIfPending()
                    self?._drainPostBGTasks()
                }
            }
            completion?()
        };return self
    }
}
// MARK: - AO（UInt8 哨兵）
private struct _JobsAO {
    // 背景安装任务队列（转场前/后各一队）——仅用于“非本地背景”的延迟任务
    static var bgTasksPreKey:  UInt8 = 0
    static var bgTasksPostKey: UInt8 = 0

    // 本地背景（同步优先安装）
    static var localBGImageKey: UInt8 = 0
    static var localBGHideBackdropKey: UInt8 = 0
}

 extension UIAlertController {
    typealias _BGTask = (UIAlertController) -> Void

    private var _bgTasksPre:  [_BGTask] {
        get { (objc_getAssociatedObject(self, &_JobsAO.bgTasksPreKey)  as? [_BGTask]) ?? [] }
        set { objc_setAssociatedObject(self, &_JobsAO.bgTasksPreKey,  newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
    private var _bgTasksPost: [_BGTask] {
        get { (objc_getAssociatedObject(self, &_JobsAO.bgTasksPostKey) as? [_BGTask]) ?? [] }
        set { objc_setAssociatedObject(self, &_JobsAO.bgTasksPostKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    private func _enqueueBGTask(preTransition: Bool, _ task: @escaping _BGTask) {
        if preTransition { _bgTasksPre.append(task) } else { _bgTasksPost.append(task) }
    }
    private func _drainPreBGTasks()  { let t = _bgTasksPre;  _bgTasksPre.removeAll();  t.forEach { $0(self) } }
    private func _drainPostBGTasks() { let t = _bgTasksPost; _bgTasksPost.removeAll(); t.forEach { $0(self) } }

    // -------- 本地背景 AO --------
    private var _localBGImage: UIImage? {
        get { objc_getAssociatedObject(self, &_JobsAO.localBGImageKey) as? UIImage }
        set { objc_setAssociatedObject(self, &_JobsAO.localBGImageKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
    private var _localBGHideBackdrop: Bool {
        get { (objc_getAssociatedObject(self, &_JobsAO.localBGHideBackdropKey) as? Bool) ?? true }
        set { objc_setAssociatedObject(self, &_JobsAO.localBGHideBackdropKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
}
// MARK: - 背景图（本地 / SD / KF）— 本地“强制同步”，网络“转场后淡入”
extension UIAlertController {
    /// 本地图片：**强制同步安装**（present 前尝试一次；转场开始时再确保一次）
    @discardableResult
    public func byBgImage(
        _ image: UIImage?,
        hideSystemBackdrop: Bool = true
    ) -> Self {
        _localBGImage = image ?? jobsSolidBlue()
        _localBGHideBackdrop = hideSystemBackdrop
        _installLocalBGIfPending()
        return self
    }

#if canImport(SDWebImage)
    /// SD：URL 为空则只装本地图；有 URL 时转场后淡入网络图
    @discardableResult
    public func bySDBgImageView(
        _ url: String,
        image: UIImage? = nil,
        hideSystemBackdrop: Bool = true,
        crossfade: TimeInterval = 0.2
    ) -> Self {
        _ = byBgImage(image ?? jobsSolidBlue(), hideSystemBackdrop: hideSystemBackdrop)
        let trimmed = url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return self }
        _enqueueBGTask(preTransition: false) { alert in
            onMainAsync(self) { vc in
                alert._withAlertCard { card in
                    let iv = alert._ensureBGImageView(in: card)
                    let placeholder = iv.image ?? (image ?? jobsSolidBlue())
                    if #available(iOS 13.0, *) {
                        Task { @MainActor in
                            let img = await trimmed.sdLoadImage(fallbackImage: placeholder)
                            if crossfade > 0 { alert._crossfade(iv, to: img, duration: crossfade) }
                            else { iv.image = img }
                            iv.byCornerRadius(card.layer.cornerRadius)
                        }
                    } else {
                        trimmed.sdLoadImage(fallbackImage: placeholder) { img in
                            onMainAsync(self) { _ in
                                if crossfade > 0 { alert._crossfade(iv, to: img, duration: crossfade) }
                                else { iv.image = img }
                                iv.byCornerRadius(card.layer.cornerRadius)
                            }
                        }
                    }
                }
            }
        };return self
    }
#endif

#if canImport(Kingfisher)
    /// KF：URL 为空则只装本地图；有 URL 时转场后淡入网络图
    @discardableResult
    public func byKFBgImageView(
        _ url: String,
        image: UIImage? = nil,
        hideSystemBackdrop: Bool = true,
        crossfade: TimeInterval = 0.2
    ) -> Self {
        _ = byBgImage(image ?? jobsSolidBlue(), hideSystemBackdrop: hideSystemBackdrop)
        let trimmed = url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return self }
        _enqueueBGTask(preTransition: false) { alert in
            onMainAsync(self) { vc in
                alert._withAlertCard { card in
                    let iv = alert._ensureBGImageView(in: card)
                    let placeholder = iv.image ?? (image ?? jobsSolidBlue())
                    if #available(iOS 13.0, *) {
                        Task { @MainActor in
                            let img = await trimmed.kfLoadImage(fallbackImage: placeholder)
                            if crossfade > 0 { alert._crossfade(iv, to: img, duration: crossfade) }
                            else { iv.image = img }
                            iv.byCornerRadius(card.layer.cornerRadius)
                        }
                    } else {
                        trimmed.kfLoadImage { result in
                            onMainAsync(self) { _ in
                                let img: UIImage
                                switch result {
                                /// 处理 .success 分支
                                case .success(let value):
                                    img = value
                                /// 处理 .failure 分支
                                case .failure:
                                    img = placeholder
                                }
                                if crossfade > 0 { alert._crossfade(iv, to: img, duration: crossfade) }
                                else { iv.image = img }
                                iv.byCornerRadius(card.layer.cornerRadius)
                            }
                        }
                    }
                }
            }
        };return self
    }
#endif
    /// 给 Alert 卡片加描边（外层容器，不是输入框）
    @discardableResult
    public func byCardBorder(width: CGFloat,
                      color: UIColor,
                      cornerRadius: CGFloat? = nil) -> Self {
        _enqueueBGTask(preTransition: true) { alert in
            onMainAsync(self) { vc in
                alert._withAlertCard { card in
                    card
                        .byBorderWidth(width)
                        .byBorderColor(color)
                    if let r = cornerRadius { card.layer.cornerRadius = r }
                    card.byMasksToBounds(true)
                    if #available(iOS 13.0, *) { card.layer.cornerCurve = .continuous }
                }
            }
        };return self
    }
    /// 给指定 index 的输入框「外层灰色容器」描边（不是 UITextField 自身）
    @discardableResult
    public func byTextFieldOuterBorder(at index: Int = 0,
                                width: CGFloat,
                                color: UIColor,
                                cornerRadius: CGFloat? = nil,
                                insets: UIEdgeInsets = .zero) -> Self {
        _enqueueBGTask(preTransition: true) { alert in
            onMainAsync(self) { vc in
                alert._withAlertCard { _ in
                    guard let tf = alert.textField(at: index) else { return }
                    guard let box = alert._findTextFieldBox(for: tf) else { return }
                    let tag = 0x7F_54_19
                    let borderView: UIView
                    if let exist = box.viewWithTag(tag) {
                        borderView = exist
                    } else {
                        let v = UIView()
                        v
                            .byUserInteractionEnabled(false)
                            .byBackgroundColor(JobsCor.clear)
                            .byTag(tag)
                        box.insertSubview(v, belowSubview: tf)
                        v.snp.makeConstraints { make in make.edges.equalToSuperview().inset(insets) }
                        borderView = v
                    }
                    borderView
                        .byBorderWidth(width)
                        .byBorderColor(color)
                        .byCornerRadius(cornerRadius ?? box.layer.cornerRadius)
                        .byMasksToBounds(true)
                    if #available(iOS 13.0, *) { borderView.layer.cornerCurve = .continuous }
                }
            }
        };return self
    }
}
// MARK: - 私有：找卡片 / 安装背景 / 视觉
extension UIAlertController {
    /// 更稳的“找 Action 视图”（优先 Label 命中 Action 标题，退化到 UIControl / 私有类名前缀）
    @MainActor
    fileprivate func _findAnyActionView() -> UIView? {
        let all = view._allSubviews()
        // A) 直接匹配 Action 标题的 UILabel
        let actionTitles = Set(actions.compactMap { $0.title })
        if let label = all.compactMap({ $0 as? UILabel }).first(where: { l in
            guard let t = l.text else { return false };return actionTitles.contains(t)
        }) {
            return label
        }
        // B) 任意 UIControl（排除 UITextField），通常就是 Action Cell
        if let ctl = all.first(where: { ($0 is UIControl) && !($0 is UITextField) && $0.bounds.height >= 34 }) {
            return ctl
        }
        // C) 类名线索：UIInterfaceAction*
        if let v = all.first(where: { cls in
            let name = NSStringFromClass(type(of: cls))
            return name.contains("UIInterfaceAction")
                || name.contains("InterfaceAction")
                || name.contains("UIAlertControllerInterfaceAction")
        }) {
            return v
        };return nil
    }
    /// 找到整张 Alert 的“卡片视图”
    /// 1) 明确命中私有类 `_UIAlertControllerView`
    /// 2) 再用“标题/消息 Label”与“任一 Action 视图”的 LCA
    /// 3) 面积最大的可见圆角容器
    /// 4) 兜底：根 view
    @MainActor
    fileprivate func _findAlertCardView() -> UIView? {
        let all = view._allSubviews()
        // 0) 明确命中私有类（很多系统版本都在）
        if let explicit = all.first(where: { NSStringFromClass(type(of: $0)).contains("_UIAlertControllerView") }) {
            return explicit
        }
        // 1) 锚点：标题/消息 label（没有就用任意 label 兜底）
        let titleLabels = all.compactMap { $0 as? UILabel }
        let titleAnchor = titleLabels.first(where: { $0.text == title || $0.text == message }) ?? titleLabels.first
        // 2) 锚点：任一 Action 视图
        let actionAnchor = _findAnyActionView()
        // 3) LCA：同时找到两端锚点 → 用最低公共祖先；若不是圆角容器，向上找圆角
        if let a = titleAnchor, let b = actionAnchor, let lca = _lowestCommonAncestor(a, b) {
            if lca.layer.cornerRadius > 0 { return lca }
            if let roundedUp = lca._firstAncestor(where: { $0.layer.cornerRadius > 0 }) { return roundedUp };return lca
        }
        // 4) 退路：面积最大的“可见圆角容器”
        let rounded = all.filter {
            $0 !== view && !$0.isHidden && $0.alpha > 0.01 &&
            $0.layer.cornerRadius > 1 && $0.bounds.width > 20 && $0.bounds.height > 20
        }
        if let big = rounded.max(by: { ($0.bounds.width * $0.bounds.height) < ($1.bounds.width * $1.bounds.height) }) {
            return big
        }
        // 5) 兜底
        return view
    }
    /// 安装/复用底层背景图（SnapKit 约束，不参与撑大）
    @MainActor
    fileprivate func _ensureBGImageView(in container: UIView) -> UIImageView {
        if let exist = container.subviews.first(where: {
            ($0 as? UIImageView)?.accessibilityIdentifier == "jobs.alert.bg"
        }) as? UIImageView {
            return exist
        }
        let iv = UIImageView()
            .byUserInteractionEnabled(false)
            .byClipsToBounds(true)
            .byContentMode(.scaleAspectFill)
            .byAccessibilityIdentifier("jobs.alert.bg")
        // 降低“存在感”
        iv.setContentHuggingPriority(.init(1), for: .horizontal)
        iv.setContentHuggingPriority(.init(1), for: .vertical)
        iv.setContentCompressionResistancePriority(.init(1), for: .horizontal)
        iv.setContentCompressionResistancePriority(.init(1), for: .vertical)
        container.insertSubview(iv, at: 0)
        iv.snp.makeConstraints { make in
            make.edges.equalToSuperview()   // 只贴边，不加 <= 约束，避免卡片被“收缩”
        };return iv
    }
}
// MARK: - 私有：同步安装“本地背景”
extension UIAlertController {
    @discardableResult
    @MainActor
    private func _installLocalBGIfPending() -> Bool {
        guard let img = _localBGImage else { return false }
        var did = false
        _withAlertCard { [weak self] card in
            guard let self else { return }
            if self._localBGHideBackdrop { self._hideBackdropAll(in: card) }
            let iv = self._ensureBGImageView(in: card)
            // 整卡片裁剪，背景图按圆角贴合整张卡片
            card.byMasksToBounds(true)
            iv
                .byCornerRadius(card.layer.cornerRadius)
                .byMasksToBounds(true)
            UIView.performWithoutAnimation {
                iv.byImage(img)
                iv.layoutIfNeeded()
            }
            did = true
        };return did
    }
}
// ================================== Shim & 工具 ==================================
extension UIAlertController {
    /// 在“整张 Alert 卡片”就绪后执行（找不到卡片则下一轮 RunLoop 再试一次，最后用根 view 兜底）
    @available(iOS 13.0, tvOS 13.0, *)
    @MainActor
    fileprivate func _withAlertCard(_ body: @escaping (_ card: UIView) async -> Void) {
        guard let card = _findAlertCardView() else {
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                let card: UIView = self._findAlertCardView() ?? self.view
                Task { @MainActor in
                    await body(card)
                }
            };return
        }
        Task { @MainActor in
            await body(card)
        }
    }
    @MainActor
    fileprivate func _withAlertCard(_ body: @escaping (_ card: UIView) -> Void) {
        guard let card = _findAlertCardView() else {
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                let card: UIView = self._findAlertCardView() ?? self.view
                body(card)
            };return
        };body(card)
    }
    /// 隐掉毛玻璃，并清掉容器底色（供本地/网络背景生效时使用）
    @MainActor
    fileprivate func _hideBackdropAll(in card: UIView) {
        func hideEffect(in v: UIView) {
            if v is UIVisualEffectView { v.isHidden = true }
            v.subviews.forEach(hideEffect)
        }
        hideEffect(in: card)
        card.byBackgroundColor(JobsCor.clear)
        view.backgroundColor = JobsCor.clear
    }

    @MainActor
    fileprivate func _crossfade(_ iv: UIImageView,
                                to image: UIImage,
                                duration: TimeInterval) {
        guard duration > 0 else { iv.image = image; return }
        UIView.transition(with: iv, duration: duration, options: .transitionCrossDissolve) {
            iv.byImage(image)
        }
    }
    /// 找到 UITextField 外层的“灰底容器”（用于描边等）
    @MainActor
    fileprivate func _findTextFieldBox(for tf: UITextField) -> UIView? {
        func looksLikeBox(_ v: UIView) -> Bool {
            if v === tf { return false }
            if v.layer.cornerRadius > 0 { return true }
            if (v.backgroundColor?.cgColor.alpha ?? 0) > 0.01 { return true }
            if v is UIVisualEffectView { return true };return false
        }
        if let s1 = tf.superview, looksLikeBox(s1) { return s1 }
        if let s2 = tf.superview?.superview, looksLikeBox(s2) { return s2 }
        var p = tf.superview
        while let v = p { if looksLikeBox(v) { return v }; p = v.superview }
        if let container = tf.superview?.superview {
            for v in container.subviews where v !== tf { if looksLikeBox(v) { return v } }
        };return nil
    }
    /// 求两个视图的“最低公共祖先”(LCA)
    fileprivate func _lowestCommonAncestor(_ a: UIView, _ b: UIView) -> UIView? {
        func chain(_ v: UIView) -> [UIView] {
            var arr: [UIView] = []; var p: UIView? = v
            while let cur = p { arr.append(cur); p = cur.superview };return arr
        }
        let aChain = chain(a).map { ObjectIdentifier($0) }
        let aSet   = Set(aChain)
        var p: UIView? = b
        while let cur = p {
            if aSet.contains(ObjectIdentifier(cur)) { return cur }
            p = cur.superview
        };return nil
    }
}

extension UIAlertController {
    private var _isPopoverActionSheet: Bool {
        return preferredStyle == .actionSheet
        && (traitCollection.userInterfaceIdiom == .pad
            || popoverPresentationController != nil)
    }
    private var _effectiveCancelStyle: UIAlertAction.Style {
        // 在 iPad 的 actionSheet(popover) 中，.cancel 会被系统隐藏：降级为 .default
        return _isPopoverActionSheet ? .default : .cancel
    }
}
