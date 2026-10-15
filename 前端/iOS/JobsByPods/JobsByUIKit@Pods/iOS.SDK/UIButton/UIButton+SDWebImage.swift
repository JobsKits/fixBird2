//
//  UIButton+SDWebImage.swift
//  JobsByUIKit
//
//  Created by Jobs on 2026年5月13日，星期三.
//

#if os(OSX)
import AppKit
#elseif os(iOS) || os(tvOS)
import UIKit
#endif

import ObjectiveC

// MARK: - SDWebImage

#if canImport(SDWebImage)
import SDWebImage
public struct SDButtonLoadConfig {
    public var url: URL?
    public var placeholder: UIImage?
    /// ✅ 背景图占位（仅用于背景图：URL 为空/失败兜底；加载时仍优先 Shimmer）
    public var bgPlaceholder: UIImage? = nil
    public var options: SDWebImageOptions = []
    public var context: [SDWebImageContextOption: Any]? = nil
    public var progress: SDImageLoaderProgressBlock? = nil
    public var completed: SDExternalCompletionBlock? = nil
    /// ✅ 目标尺寸（point）。用于强制下采样：避免远端大图撑开 UIButton 的 intrinsicContentSize。
    /// - Note: 不设置时会按按钮当前 UI 猜一个兜底值。
    public var targetSize: CGSize? = nil
    /// ✅ 背景图目标尺寸（point）。不设置时默认取按钮 bounds（取不到则兜底 320x64）。
    public var bgTargetSize: CGSize? = nil
    public init() {}
}

private enum _SDButtonAOKey {
    static var config: UInt8 = 0
}

extension UIButton {
    private var _sd_config: SDButtonLoadConfig {
        get { (objc_getAssociatedObject(self, &_SDButtonAOKey.config) as? SDButtonLoadConfig) ?? SDButtonLoadConfig() }
        set {
            objc_setAssociatedObject(
                self,
                &_SDButtonAOKey.config,
                newValue,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
        }
    }
}

extension UIButton {
    @discardableResult
    private func _sd_setImageURL(_ url: URL?) -> Self {
        var c = _sd_config; c.url = url; _sd_config = c
        return self
    }

    @discardableResult
    private func _sd_setPlaceholder(_ img: UIImage?) -> Self {
        var c = _sd_config; c.placeholder = img; _sd_config = c
        return self
    }

    @discardableResult
    private func _sd_setBgPlaceholder(_ img: UIImage?) -> Self {
        var c = _sd_config; c.bgPlaceholder = img; _sd_config = c
        return self
    }

    @discardableResult
    private func _sd_setOptions(_ opts: SDWebImageOptions) -> Self {
        var c = _sd_config; c.options = opts; _sd_config = c
        return self
    }

    @discardableResult
    private func _sd_setContext(_ ctx: [SDWebImageContextOption: Any]?) -> Self {
        var c = _sd_config; c.context = ctx; _sd_config = c
        return self
    }
    @discardableResult
    private func _sd_setProgress(_ block: SDImageLoaderProgressBlock?) -> Self {
        var c = _sd_config; c.progress = block; _sd_config = c
        return self
    }

    @discardableResult
    private func _sd_setCompleted(_ block: SDExternalCompletionBlock?) -> Self {
        var c = _sd_config; c.completed = block; _sd_config = c
        return self
    }

    @discardableResult
    private func _sd_setTargetSize(_ size: CGSize?) -> Self {
        var c = _sd_config; c.targetSize = size; _sd_config = c
        return self
    }

    @discardableResult
    private func _sd_setBgTargetSize(_ size: CGSize?) -> Self {
        var c = _sd_config; c.bgTargetSize = size; _sd_config = c
        return self
    }
}

extension UIButton {
    @discardableResult
    public func sd_imageURL(_ url: URL?) -> Self {
        _sd_setImageURL(url)
    }

    @discardableResult
    public func sd_imageURL(_ urlString: String?) -> Self {
        guard let s = urlString, let u = URL(string: s)
        else {
            return _sd_setImageURL(nil)
        };return _sd_setImageURL(u)
    }

    @discardableResult
    public func sd_placeholderImage(_ img: UIImage?) -> Self {
        _sd_setPlaceholder(img)
    }
    /// ✅ 背景图占位（仅作用于 UIButton 的 backgroundImage）
    @discardableResult
    public func sd_placeholderBgImage(_ img: UIImage?) -> Self {
        _sd_setBgPlaceholder(img)
    }

    @discardableResult
    public func sd_options(_ opts: SDWebImageOptions) -> Self {
        _sd_setOptions(opts)
    }

    @discardableResult
    public func sd_context(_ ctx: [SDWebImageContextOption: Any]?) -> Self {
        _sd_setContext(ctx)
    }

    @discardableResult
    public func sd_progress(_ block: SDImageLoaderProgressBlock?) -> Self {
        _sd_setProgress(block)
    }

    @discardableResult
    public func sd_completed(_ block: SDExternalCompletionBlock?) -> Self {
        _sd_setCompleted(block)
    }
    /// ✅ 目标尺寸（point）：用于下采样（前景图）
    @discardableResult
    public func sd_targetSize(_ size: CGSize?) -> Self {
        _sd_setTargetSize(size)
    }
    /// ✅ 目标尺寸（point）：用于下采样（背景图）
    @discardableResult
    public func sd_bgTargetSize(_ size: CGSize?) -> Self {
        _sd_setBgTargetSize(size)
    }

    @discardableResult
    public func sd_normalLoad() -> Self {
        _sd_loadImage(for: .normal)
        return self
    }

    @discardableResult
    public func sd_highlightedLoad() -> Self {
        _sd_loadImage(for: .highlighted)
        return self
    }

    @discardableResult
    public func sd_disabledLoad() -> Self {
        _sd_loadImage(for: .disabled)
        return self
    }

    @discardableResult
    public func sd_selectedLoad() -> Self {
        _sd_loadImage(for: .selected)
        return self
    }

    @available(iOS 9.0, *)
    @discardableResult
    public func sd_focusedLoad() -> Self {
        _sd_loadImage(for: .focused)
        return self
    }

    @discardableResult
    public func sd_applicationLoad() -> Self {
        _sd_loadImage(for: .application)
        return self
    }

    @discardableResult
    public func sd_reservedLoad() -> Self {
        _sd_loadImage(for: .reserved)
        return self
    }

    @discardableResult
    public func sd_bgNormalLoad() -> Self {
        _sd_loadBackgroundImage(for: .normal)
        return self
    }

    @discardableResult
    public func sd_bgHighlightedLoad() -> Self {
        _sd_loadBackgroundImage(for: .highlighted)
        return self
    }

    @discardableResult
    public func sd_bgDisabledLoad() -> Self {
        _sd_loadBackgroundImage(for: .disabled)
        return self
    }

    @discardableResult
    public func sd_bgSelectedLoad() -> Self {
        _sd_loadBackgroundImage(for: .selected)
        return self
    }

    @available(iOS 9.0, *)
    @discardableResult
    public func sd_bgFocusedLoad() -> Self {
        _sd_loadBackgroundImage(for: .focused)
        return self
    }

    @discardableResult
    public func sd_bgApplicationLoad() -> Self {
        _sd_loadBackgroundImage(for: .application)
        return self
    }

    @discardableResult
    public func sd_bgReservedLoad() -> Self {
        _sd_loadBackgroundImage(for: .reserved)
        return self
    }
}

// MARK: - internal helpers
extension UIButton {
    private func _jobs_sdBuildContext(base: [SDWebImageContextOption: Any]?, targetPointSize: CGSize?) -> [SDWebImageContextOption: Any] {
        var ctx = base ?? [:]
        if ctx[.imageScaleFactor] == nil {
            ctx[.imageScaleFactor] = UIScreen.main.scale
        }
        // ✅ 核心：强制缩略图像素尺寸（避免 image.size 过大导致 UIButton intrinsicContentSize 被撑开）
        if ctx[.imageThumbnailPixelSize] == nil {
            let point = targetPointSize
            if let point, point.width > 1, point.height > 1 {
                let scale = UIScreen.main.scale
                ctx[.imageThumbnailPixelSize] = CGSize(width: max(1, point.width * scale), height: max(1, point.height * scale))
            }
        };return ctx
    }
}

extension UIButton {
    // MARK: - 前景图（SDWebImage）
    public func _sd_loadImage(for state: UIControl.State) {
        let cfg = _sd_config
        let token = _jobs_nextToken(loader: .sd, channel: .foreground, for: state)
        // ✅ 标记实际使用的框架（给 JobsImageCacheCleaner 用）
        self.jobs_imageLoaderKind = .sdwebimage
        // ✅ 记录：前景 state / url（供 JobsImageCacheCleaner 遍历重下）
        self.jobs_remoteState = state
        // ✅ 目标尺寸：优先显式设置的 targetSize，否则按 UI 猜一个兜底值（用于 shimmer + thumbnail 下采样）
        let targetPointSize = cfg.targetSize ?? _jobs_guessForegroundTargetSize()
        self.jobs_remoteImageTargetSize = targetPointSize
        let loadingPlaceholder = _jobs_loadingPlaceholderImage(targetPointSize: targetPointSize, fallback: cfg.placeholder)
        guard let url = cfg.url else {
            self.jobs_remoteURL = nil
            // URL 解析失败也视为失败：直接落兜底（不需要 shimmer）
            _jobs_runOnMain { btn in
                guard btn._jobs_isCurrentToken(token,
                                               loader: .sd,
                                               channel: .foreground,
                                               for: state) else { return }
                btn._jobs_stopForegroundShimmer()
                btn._jobs_forceSetForegroundImage(cfg.placeholder, for: state)
            };return
        }
        self.jobs_remoteURL = url
        // 先灌入兜底图（或透明占位）让 imageView 可用，再在当前 imageView.layer 上做 shimmer。
        _jobs_runOnMain { btn in
            guard btn._jobs_isCurrentToken(token,
                                           loader: .sd,
                                           channel: .foreground,
                                           for: state) else { return }
            btn._jobs_forceSetForegroundImage(loadingPlaceholder, for: state)
            btn.setNeedsLayout()
            btn._jobs_startForegroundShimmer(targetSize: targetPointSize)
        }
        // 取消同 state 的在途请求
        self.sd_cancelImageLoad(for: state)
        // ✅ SD 只在回调里写图：避免 SD 自动写回导致“先被大图撑开，再被你重置”的竞态
        var opts = cfg.options
        opts.insert(.continueInBackground)
        opts.insert(.highPriority)
        opts.insert(.scaleDownLargeImages)
        opts.insert(.avoidAutoSetImage)
        let ctx = _jobs_sdBuildContext(base: cfg.context, targetPointSize: targetPointSize)
        self.sd_setImage(
            with: url,
            for: state,
            placeholderImage: nil,
            options: opts,
            context: ctx,
            progress: cfg.progress
        ) { [weak self] img, err, cacheType, imageURL in
            guard let self else { return }
            self._jobs_runOnMain { btn in
                guard btn._jobs_isCurrentToken(token,
                                               loader: .sd,
                                               channel: .foreground,
                                               for: state) else { return }
                let nsErr = err as NSError?
                let isCancelled = (nsErr?.domain == SDWebImageErrorDomain && nsErr?.code == SDWebImageError.cancelled.rawValue)
                if isCancelled {
                    // ✅ 取消也算“请求结束”：停 shimmer；不覆盖新请求（token 已保证）
                    btn._jobs_stopForegroundShimmer()
                    btn._jobs_forceSetForegroundImage(cfg.placeholder, for: state)
                    cfg.completed?(img, err, cacheType, imageURL)
                    return
                }
                if let img {
                    // ✅ Success：请求结束，停 shimmer，显示最终图
                    btn._jobs_stopForegroundShimmer()
                    // UIButton.Configuration 会替换内部 imageView，不能放进 transition 动画块。
                    btn._jobs_forceSetForegroundImage(img, for: state)
                } else {
                    // ✅ Failure：请求结束，必须停 shimmer；有兜底图就落兜底；没有就保持 nil
                    btn._jobs_stopForegroundShimmer()
                    btn._jobs_forceSetForegroundImage(cfg.placeholder, for: state)
                }
                cfg.completed?(img, err, cacheType, imageURL)
            }
        }
    }
    // MARK: - 背景图（SDWebImage）
    public func _sd_loadBackgroundImage(for state: UIControl.State) {
        let cfg = _sd_config
        // ✅ 标记实际使用的框架（给 JobsImageCacheCleaner 用）
        self.jobs_imageLoaderKind = .sdwebimage
        // 记录元数据（克隆/复用要用）
        self.jobs_bgURL = cfg.url
        self.jobs_bgState = state
        // ✅ Loading：永远先 Shimmer（placeholder 只作为「失败兜底」）
        _jobs_runOnMain { btn in
            // ✅ 背景加载：先落背景占位（如果有），再上 shimmer
            btn._jobs_forceSetBackgroundImage((cfg.bgPlaceholder ?? cfg.placeholder), for: state)
            btn._jobs_startBackgroundShimmer()
        }
        guard let url = cfg.url else {
            // URL 解析失败也视为失败：有兜底图则显示兜底并停 shimmer；否则继续 shimmer
            if let fb = (cfg.bgPlaceholder ?? cfg.placeholder) {
                _jobs_runOnMain { btn in
                    btn._jobs_stopBackgroundShimmer()
                    btn._jobs_forceSetBackgroundImage(fb, for: state)
                }
            };return
        }
        // ✅ 目标尺寸：背景优先显式设置，否则按按钮 bounds 兜底
        let targetPointSize = cfg.bgTargetSize ?? _jobs_guessBackgroundTargetSize()
        self.jobs_bgImageTargetSize = targetPointSize
        // 取消在途任务（同一 state）
        self.sd_cancelBackgroundImageLoad(for: state)
        // 只在回调里写图，避免 SD 自动写回导致的闪白/覆盖
        var opts = cfg.options
        opts.insert(.continueInBackground)
        opts.insert(.highPriority)
        opts.insert(.scaleDownLargeImages)
        opts.insert(.avoidAutoSetImage)
        let ctx = _jobs_sdBuildContext(base: cfg.context, targetPointSize: targetPointSize)
        self.sd_setBackgroundImage(
            with: url,
            for: state,
            placeholderImage: nil,
            options: opts,
            context: ctx,
            progress: cfg.progress
        ) { [weak self] img, err, cacheType, _ in
            guard let self else { return }
            self._jobs_runOnMain { btn in
                let nsErr = err as NSError?
                let isCancelled = (nsErr?.domain == SDWebImageErrorDomain && nsErr?.code == SDWebImageError.cancelled.rawValue)
                if isCancelled { return }
                if let img {
                    // ✅ Success：停 shimmer，显示最终图
                    btn._jobs_stopBackgroundShimmer()
                    // 背景图会同步到 UIButton.Configuration，避免在 transition 动画块内替换内部层级。
                    btn._jobs_forceSetBackgroundImage(img, for: state)
                } else {
                    // ✅ Failure：有兜底图才落兜底；否则继续 shimmer
                    if let fb = (cfg.bgPlaceholder ?? cfg.placeholder) {
                        btn._jobs_stopBackgroundShimmer()
                        btn._jobs_forceSetBackgroundImage(fb, for: state)
                    }
                }
                cfg.completed?(img, err, cacheType, url)
            }
        }
    }
    /// 克隆 SD 的“背景图”到目标按钮：优先现成位图/配置 → 缓存 → 可选走网
    public func sd_cloneBackground(to target: UIButton,
                                   for state: UIControl.State = .normal,
                                   allowNetworkIfMissing: Bool = false) {
        target.jobs_isClone = true
        target.jobs_bgState = state
        target.jobs_imageLoaderKind = .sdwebimage
        // 先 snapshot 一份配置，避免跨 actor 反复读 AO
        let snapCfg = self._sd_config
        // 有效 URL：优先用 _sd_loadBackgroundImage 记录的 jobs_bgURL，退回配置里的 url
        let effectiveURL = self.jobs_bgURL ?? snapCfg.url
        // ===== 情况 1：没有 URL，说明是纯本地背景图，直接复用现成位图后结束 =====
        if effectiveURL == nil {
            if #available(iOS 15.0, *), let cfgImg = self.configuration?.background.image {
                target._jobs_runOnMain { btn in
                    btn._jobs_forceSetBackgroundImage(cfgImg, for: state)
                };return
            }
            if let img = self.backgroundImage(for: state) {
                target._jobs_runOnMain { btn in
                    btn._jobs_forceSetBackgroundImage(img, for: state)
                };return
            }
            // 只有占位图的极端情况
            if let ph = (snapCfg.bgPlaceholder ?? snapCfg.placeholder) {
                target._jobs_runOnMain { btn in
                    btn._jobs_forceSetBackgroundImage(ph, for: state)
                }
            };return
        }
        // ===== 情况 2：有 URL，说明是远程图；此时现成位图很可能只是占位，不能直接 return =====
        if let ph = (snapCfg.bgPlaceholder ?? snapCfg.placeholder) {
            target._jobs_runOnMain { btn in
                btn._jobs_forceSetBackgroundImage(ph, for: state)
            }
        }
        let url = effectiveURL!
        target.jobs_bgURL = url
        // ✅ 同步复制目标尺寸配置
        target._sd_setBgTargetSize(snapCfg.bgTargetSize)
        if let s = snapCfg.bgTargetSize { target.jobs_bgImageTargetSize = s }
        // 先查缓存（同步），命中就直接用缓存图
        let key = SDWebImageManager.shared.cacheKey(for: url) ?? url.absoluteString
        if let cached = SDImageCache.shared.imageFromCache(forKey: key) {
            target._jobs_runOnMain { btn in
                btn._jobs_forceSetBackgroundImage(cached, for: state)
            };return
        }
        // 不允许走网，直接停在占位图
        guard allowNetworkIfMissing else { return }
        // 允许走网：复制源按钮的加载配置；克隆场景加 avoidAutoSetImage，避免闪烁
        var opts = snapCfg.options
        opts.insert(.continueInBackground)
        opts.insert(.highPriority)
        opts.insert(.scaleDownLargeImages)
        opts.insert(.avoidAutoSetImage)
        target._sd_setImageURL(url)
        target._sd_setPlaceholder(snapCfg.placeholder)
        target._sd_setBgPlaceholder(snapCfg.bgPlaceholder)
        target._sd_setOptions(opts)
        target._sd_setContext(snapCfg.context)
        target._sd_setProgress(snapCfg.progress)
        target._sd_setCompleted(snapCfg.completed)
        // 用已有的淡入版本，真正发起 SD 的背景图加载
        target._sd_loadBackgroundImage(for: state)
    }
    /// 克隆“前景图”
    public func sd_cloneImage(to target: UIButton,
                              for state: UIControl.State = .normal) {
        guard let url = _sd_config.url else { return }
        target.jobs_imageLoaderKind = .sdwebimage
        target._sd_setImageURL(url)
        target._sd_setPlaceholder(self._sd_config.placeholder)
        target._sd_setOptions(self._sd_config.options)
        target._sd_setContext(self._sd_config.context)
        target._sd_setProgress(self._sd_config.progress)
        target._sd_setCompleted(self._sd_config.completed)
        // ✅ 同步复制目标尺寸配置
        target._sd_setTargetSize(self._sd_config.targetSize)
        if let s = self._sd_config.targetSize { target.jobs_remoteImageTargetSize = s }
        target._sd_loadImage(for: state)
    }
}
#endif
