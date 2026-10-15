//
//  JobsToast.swift
//  JobsToast
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
import JobsSwiftBlock
import JobsSwiftBaseDefines
import SnapKit

// ================================== Toast ==================================
@MainActor
public final class JobsToast: UIView {
    // ✅ 用 UInt8 做关联 key，避免字符串
    private static var currentToastKey: UInt8 = 0
    // 供懒加载按钮的点按回调占位（由 show(...) 注入）
    private var tapHandler: ((UIButton) -> Void)?
    // ✅ 懒加载按钮，使用已有链式 API
    private lazy var contentButton: UIButton = {
        UIButton.sys()
            .byNormalBgColor(JobsCor.clear)
            .byTitle(" ", for: .normal) // 占位；真正文案在 show/链式里设
            .byTitleColor(JobsCor.white, for: .normal)
            .byTitleFont(JobsFont.systemFont(ofSize: 15, weight: .medium))
            .byContentEdgeInsets(UIEdgeInsets(top: 10, left: 16, bottom: 10, right: 16))
            .onTap { [weak self] sender in
                guard let self else { return }
                self.tapHandler?(sender)
            }
            .byAddTo(self) { make in
                make.edges.equalToSuperview()
            }
    }()

    private var completion: jobsByVoidBlock?
    private weak var hostWindow: UIWindow?
    private var dismissalWork: DispatchWorkItem?
    private var isDismissing = false
    // MARK: - 配置：支持时长、边距、偏移、圆角、背景色等链式
    public struct Config {
        public var duration: TimeInterval = 1.0
        public var bottomOffset: CGFloat = 120
        public var horizontalPadding: CGFloat = 16
        public var verticalPadding: CGFloat = 10
        public var cornerRadius: CGFloat = 10
        public var backgroundColor: UIColor = JobsCor.black.withAlphaComponent(0.85)
        public init() {}
        // MARK: - 链式配置
        @discardableResult public func byDuration(_ value: TimeInterval) -> Self {
            var cfg = self; cfg.duration = value; return cfg
        }
        @discardableResult public func byBottomOffset(_ value: CGFloat) -> Self {
            var cfg = self; cfg.bottomOffset = value; return cfg
        }
        @discardableResult public func byHorizontalPadding(_ value: CGFloat) -> Self {
            var cfg = self; cfg.horizontalPadding = value; return cfg
        }
        @discardableResult public func byVerticalPadding(_ value: CGFloat) -> Self {
            var cfg = self; cfg.verticalPadding = value; return cfg
        }
        @discardableResult public func byCornerRadius(_ value: CGFloat) -> Self {
            var cfg = self; cfg.cornerRadius = value; return cfg
        }
        @discardableResult public func byBackgroundColor(_ color: UIColor) -> Self {
            var cfg = self; cfg.backgroundColor = color; return cfg
        }
    }
}
// MARK: - JobsToast 自身的链式扩展
public extension JobsToast {
    /// 链式：设置完成回调
    @discardableResult
    func byCompletion(_ block: jobsByVoidBlock?) -> Self {
        self.completion = block
        return self
    }
    /// 链式：设置点击回调
    @discardableResult
    func byTap(_ handler: ((UIButton) -> Void)?) -> Self {
        self.tapHandler = handler
        return self
    }
    /// 链式：设置显示文本
    @discardableResult
    func byText(_ text: String) -> Self {
        _ = contentButton
        contentButton.byTitle(text, for: .normal)
        return self
    }
    /// 链式：应用样式配置（背景色、圆角、padding）
    @discardableResult
    func byApply(_ config: Config) -> Self {
        // 容器外观
        self.byBackgroundColor(config.backgroundColor)
        byCornerRadius(config.cornerRadius)
        byMasksToBounds(true)
        // 内容内边距
        _ = contentButton
        contentButton.byContentEdgeInsets(UIEdgeInsets(
            top: config.verticalPadding,
            left: config.horizontalPadding,
            bottom: config.verticalPadding,
            right: config.horizontalPadding
        ));return self
    }
}
// MARK: - 静态 API
public extension JobsToast {
    // ================================== API ==================================
    @discardableResult
    static func show(
        text: String,
        in window: UIWindow? = nil,            // ⚠️ 不用默认取 .wd，避免 actor 警告
        config: Config = .init(),
        tap: ((UIButton) -> Void)? = nil,
        completion: jobsByVoidBlock? = nil,
        showDuration: TimeInterval = 0.18,     // ⬅️ 入场动画时长（默认 0.18）
        showDelay: TimeInterval = 0,
        showOptions: UIView.AnimationOptions = [.curveEaseOut]
    ) -> JobsToast {
        // 在主线程里安全获取 window
        let targetWindow = window ?? UIWindow.wd
        // 每窗只保留一个
        removeExistingToast(from: targetWindow)
        // 构建并上屏
        let toast = JobsToast()
            .byCompletion(completion)
            .byTap(tap)
            .byApply(config)
            .byText(text)
            .byAlpha(0)
            .byTransform(CGAffineTransform(scaleX: 0.96, y: 0.96))
            .byAddTo(targetWindow) { make in
                // 当前是居中展示
                make.center.equalToSuperview()
                make.width.lessThanOrEqualTo(targetWindow.bounds.width - 40)
            }
        // 入场动画（使用参数化时长/延迟/曲线）
        UIView.jobsAnimateWithOptions(
            showDuration,
            delay: showDelay,
            options: showOptions,
            animations: {
                toast
                    .byAlpha(1)
                    .byTransform(.identity)
            }
        )
        // 记录引用：每窗只保留一个
        objc_setAssociatedObject(targetWindow, &currentToastKey, toast, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        toast.hostWindow = targetWindow
        let work = DispatchWorkItem { [weak toast, weak targetWindow] in
            guard let toast, let targetWindow else { return }
            toast.dismiss(from: targetWindow)
        }
        toast.dismissalWork = work
        let duration = config.duration.isFinite ? max(0.15, config.duration) : 1
        DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: work)
        return toast
    }
    // 主动消失 —— 无参便捷版（MainActor 内部安全取 wd）
    func dismiss() {
        guard let targetWindow = hostWindow ?? (superview as? UIWindow) else { return }
        dismiss(from: targetWindow)
    }
    // 主动消失 —— 需要明确传入 window（不提供默认值）
    func dismiss(from window: UIWindow) {
        guard superview != nil, !isDismissing else { return }
        isDismissing = true
        dismissalWork?.cancel()
        dismissalWork = nil
        UIView.jobsAnimateWithOptions(
            0.18,
            delay: 0,
            options: [.curveEaseIn],
            animations: {
                self.byAlpha(0)
                self.transform = CGAffineTransform(scaleX: 0.97, y: 0.97).translatedBy(x: 0, y: 6)
            },
            completion: { [weak self, weak window] _ in
                guard let self else { return }
                self.removeFromSuperview()
                if let window,
                   objc_getAssociatedObject(window, &Self.currentToastKey) as? JobsToast === self {
                    Self.clearAssociatedToast(from: window)
                }
                let completion = self.completion
                self.completion = nil
                completion?()
            }
        )
    }
}
// MARK: - 辅助
private extension JobsToast {
    static func removeExistingToast(from window: UIWindow) {
        if let existing = objc_getAssociatedObject(window, &currentToastKey) as? JobsToast {
            existing.dismissalWork?.cancel()
            existing.dismissalWork = nil
            existing.layer.removeAllAnimations()
            existing.removeFromSuperview()
            existing.completion = nil
            clearAssociatedToast(from: window)
        }
    }
    static func clearAssociatedToast(from window: UIWindow) {
        objc_setAssociatedObject(window, &currentToastKey, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }
}
// MARK: - Tips
public func toastBy(_ string: String) {
    /// 允许任意线程调用这个方法
    onMainAsync {
        JobsToast.show(
            text: string,
            config: JobsToast.Config()
                .byBackgroundColor(JobsCor.systemGreen.withAlphaComponent(0.9))
                .byCornerRadius(12)
        )
    }
}

extension String {
     public var toast: Void {
        toastBy(self)
        print ("toast: \(self)")
    }
}
