//
//  JobsImageCacheCleaner.swift
//  JobsImageTools
//
//  Created by Jobs on 2026年5月13日，星期三.
//

import Foundation
import ObjectiveC
import JobsSwiftBlock
import JobsSwiftBaseDefines
import JobsSwiftDSL

#if canImport(Kingfisher)
import Kingfisher
#endif
#if canImport(SDWebImage)
import SDWebImage
#endif

public enum JobsImageLoaderKind: Int {
    case unknown = 0
    case sdwebimage = 1
    case kingfisher = 2
    case urlSession = 3
}

public enum JobsImageCacheCleaner {
    /// 清空 Kingfisher：内存 + 磁盘
    public static func clearKingfisherCache(_ completion: (jobsByVoidBlock)? = nil) {
        #if canImport(Kingfisher)
        let cache = KingfisherManager.shared.cache
        cache.clearMemoryCache()
        cache.clearDiskCache {
            cache.cleanExpiredDiskCache()
            completion?()
        }
        #else
        completion?()
        #endif
    }
    /// 清空 SDWebImage：内存 + 磁盘
    public static func clearSDWebImageCache(_ completion: (jobsByVoidBlock)? = nil) {
        #if canImport(SDWebImage)
        let cache = SDImageCache.shared
        cache.clearMemory()
        cache.clearDisk {
            completion?()
        }
        #else
        completion?()
        #endif
    }
    /// ✅ 强制让“当前页面视图树内”的图片重新下载（UIImageView / UIButton）
    /// - Important: 只覆盖“已在视图树里”的控件；并且要求控件自身记录了 URL（jobs_remoteURL / jobs_bgURL）。
    /// - Note: 项目里同时有 Kingfisher + SDWebImage 时，不能再用编译期 #if/elseif 二选一。
    ///         这里按控件的 jobs_imageLoaderKind（由包装加载方法写入）来选择实际执行的框架。
    @MainActor public static func forceRedownloadImages(
        in rootView: UIView,
        placeholder: UIImage? = nil,
        completion: (jobsByVoidBlock)? = nil
    ) {
        if Thread.isMainThread {
            _forceRedownloadImagesMain(in: rootView, placeholder: placeholder, completion: completion)
        } else {
            DispatchQueue.main.async {
                _forceRedownloadImagesMain(in: rootView, placeholder: placeholder, completion: completion)
            }
        }
    }

    @MainActor
    private static func _forceRedownloadImagesMain(
        in rootView: UIView,
        placeholder: UIImage? = nil,
        completion: (jobsByVoidBlock)? = nil
    ) {
        let group = DispatchGroup()
        // MARK: - helpers
        func _pointToPixel(_ point: CGSize) -> CGSize {
            #if canImport(UIKit)
            let scale = UIScreen.main.scale
            return CGSize(width: max(1, point.width * scale), height: max(1, point.height * scale))
            #else
            return point
            #endif
        }
        func _guessImageViewTargetSize(_ iv: UIImageView) -> CGSize {
            let s = iv.jobs_remoteImageTargetSize ?? iv.bounds.size
            if s.width > 1, s.height > 1 { return s };return CGSize(width: 160, height: 160)
        }
        func _guessButtonForegroundTargetSize(_ btn: UIButton) -> CGSize {
            if let s = btn.jobs_remoteImageTargetSize, s.width > 1, s.height > 1 { return s }
            if let iv = btn.imageView {
                let s = iv.bounds.size
                if s.width > 1, s.height > 1 { return s }
            }
            let h = btn.bounds.size.height
            if h > 1 {
                let side = max(24, h - 16)
                return CGSize(width: side, height: side)
            };return CGSize(width: 48, height: 48)
        }
        func _guessButtonBackgroundTargetSize(_ btn: UIButton) -> CGSize {
            if let s = btn.jobs_bgImageTargetSize, s.width > 1, s.height > 1 { return s }
            let s = btn.bounds.size
            if s.width > 1, s.height > 1 { return s };return CGSize(width: 320, height: 64)
        }
        // MARK: - concrete loaders (compiled conditionally)
        #if canImport(Kingfisher)
        func _reloadWithKingfisher(imageView iv: UIImageView, url: URL) {
            let target = _guessImageViewTargetSize(iv)
            group.enter()
            let opts: KingfisherOptionsInfo = [
                .forceRefresh,
                .processor(DownsamplingImageProcessor(size: target)),
                .scaleFactor(UIScreen.main.scale)
            ]
            iv.kf.setImage(with: url, placeholder: placeholder, options: opts) { _ in
                group.leave()
            }
        }
        func _reloadWithKingfisher(button btn: UIButton, url: URL, state: UIControl.State) {
            let target = _guessButtonForegroundTargetSize(btn)
            let generation = btn.jobs_remoteBindingGeneration
            group.enter()
            let opts: KingfisherOptionsInfo = [
                .forceRefresh,
                .processor(DownsamplingImageProcessor(size: target)),
                .scaleFactor(UIScreen.main.scale)
            ]
            btn.kf.setImage(with: url,
                            for: state,
                            placeholder: placeholder,
                            options: opts,
                            completionHandler:  { result in
                onMainAsync {
                    guard btn.jobs_remoteURL == url, btn.jobs_remoteBindingGeneration == generation else {
                        group.leave()
                        return
                    }
                    switch result {
                    /// 处理 .success 分支
                    case .success(let r): btn.jobsResetBtnImage(r.image, for: state)
                    /// 处理 .failure 分支
                    case .failure:        btn.jobsResetBtnImage(placeholder, for: state)
                    }
                    group.leave()
                }
            })
        }
        func _reloadWithKingfisherBackground(button btn: UIButton, url: URL, state: UIControl.State) {
            let target = _guessButtonBackgroundTargetSize(btn)
            let generation = btn.jobs_bgBindingGeneration
            group.enter()
            let opts: KingfisherOptionsInfo = [
                .forceRefresh,
                .processor(DownsamplingImageProcessor(size: target)),
                .scaleFactor(UIScreen.main.scale)
            ]
            btn.kf.setBackgroundImage(with: url,
                                      for: state,
                                      placeholder: placeholder,
                                      options: opts,
                                      completionHandler:  { result in
                onMainAsync {
                    guard btn.jobs_bgURL == url, btn.jobs_bgBindingGeneration == generation else {
                        group.leave()
                        return
                    }
                    switch result {
                    /// 处理 .success 分支
                    case .success(let r): btn.jobsResetBtnBgImage(r.image, for: state)
                    /// 处理 .failure 分支
                    case .failure:        btn.jobsResetBtnBgImage(placeholder, for: state)
                    }
                    group.leave()
                }
            })
        }
        #endif
        #if canImport(SDWebImage)
        func _reloadWithSDWebImage(imageView iv: UIImageView, url: URL) {
            let target = _guessImageViewTargetSize(iv)
            group.enter()
            var ctx: [SDWebImageContextOption: Any] = [:]
            ctx[.imageScaleFactor] = UIScreen.main.scale
            ctx[.imageThumbnailPixelSize] = _pointToPixel(target)
            let opts: SDWebImageOptions = [.refreshCached, .retryFailed, .highPriority, .scaleDownLargeImages]
            iv.sd_setImage(with: url,
                          placeholderImage: placeholder,
                          options: opts,
                          context: ctx,
                          progress: nil) { _, _, _, _ in
                group.leave()
            }
        }
        func _reloadWithSDWebImage(button btn: UIButton, url: URL, state: UIControl.State) {
            let target = _guessButtonForegroundTargetSize(btn)
            let generation = btn.jobs_remoteBindingGeneration
            group.enter()
            var ctx: [SDWebImageContextOption: Any] = [:]
            ctx[.imageScaleFactor] = UIScreen.main.scale
            ctx[.imageThumbnailPixelSize] = _pointToPixel(target)
            let opts: SDWebImageOptions = [.refreshCached, .retryFailed, .highPriority, .scaleDownLargeImages, .avoidAutoSetImage]
            btn.sd_setImage(with: url,
                            for: state,
                            placeholderImage: placeholder,
                            options: opts,
                            context: ctx,
                            progress: nil) { img, err, _, _ in
                onMainAsync {
                    guard btn.jobs_remoteURL == url, btn.jobs_remoteBindingGeneration == generation else {
                        group.leave()
                        return
                    }
                    btn.jobsResetBtnImage((err == nil ? img : nil) ?? placeholder, for: state)
                    group.leave()
                }
            }
        }
        func _reloadWithSDWebImageBackground(button btn: UIButton, url: URL, state: UIControl.State) {
            let target = _guessButtonBackgroundTargetSize(btn)
            let generation = btn.jobs_bgBindingGeneration
            group.enter()
            var ctx: [SDWebImageContextOption: Any] = [:]
            ctx[.imageScaleFactor] = UIScreen.main.scale
            ctx[.imageThumbnailPixelSize] = _pointToPixel(target)
            let opts: SDWebImageOptions = [.refreshCached, .retryFailed, .highPriority, .scaleDownLargeImages, .avoidAutoSetImage]
            btn.sd_setBackgroundImage(with: url,
                                      for: state,
                                      placeholderImage: placeholder,
                                      options: opts,
                                      context: ctx,
                                      progress: nil) { img, err, _, _ in
                onMainAsync {
                    guard btn.jobs_bgURL == url, btn.jobs_bgBindingGeneration == generation else {
                        group.leave()
                        return
                    }
                    btn.jobsResetBtnBgImage((err == nil ? img : nil) ?? placeholder, for: state)
                    group.leave()
                }
            }
        }
        #endif
        func _reloadWithJobsImageLoader(imageView iv: UIImageView, url: URL) {
            let target = _guessImageViewTargetSize(iv)
            let generation = iv.jobs_remoteBindingGeneration
            group.enter()
            JobsImageLoader.shared.load(
                .remote(url),
                options: .init(preferredLoader: .urlSession,
                               targetSize: target,
                               forceRefresh: true)
            ) { result in
                guard iv.jobs_remoteURL == url, iv.jobs_remoteBindingGeneration == generation else {
                    group.leave()
                    return
                }
                switch result {
                /// 处理 .success 分支
                case .success(let value):
                    iv.byImage(value.image)
                    iv.jobs_remoteURL = value.url
                    iv.jobs_imageLoaderKind = value.loaderKind
                /// 处理 .failure 分支
                case .failure:
                    iv.byImage(placeholder)
                }
                group.leave()
            }
        }
        // MARK: - walker
        func walk(_ view: UIView) {
            // MARK: - UIImageView（前景图）
            if let iv = view as? UIImageView, let url = iv.jobs_remoteURL {
                let kind = iv.jobs_imageLoaderKind
                // 先按标记框架走；标记缺失时：优先 SD（因为项目里 SD + KF 同时存在时，之前的 #elseif 会误伤 SD）
                switch kind {
                /// 处理 .urlSession 分支
                case .urlSession:
                    _reloadWithJobsImageLoader(imageView: iv, url: url)
                /// 处理 .sdwebimage 分支
                case .sdwebimage:
                    #if canImport(SDWebImage)
                    _reloadWithSDWebImage(imageView: iv, url: url)
                    #elseif canImport(Kingfisher)
                    _reloadWithKingfisher(imageView: iv, url: url)
                    #endif
                /// 处理 .kingfisher 分支
                case .kingfisher:
                    #if canImport(Kingfisher)
                    _reloadWithKingfisher(imageView: iv, url: url)
                    #elseif canImport(SDWebImage)
                    _reloadWithSDWebImage(imageView: iv, url: url)
                    #endif
                /// 处理 .unknown 分支
                case .unknown:
                    #if canImport(SDWebImage)
                    _reloadWithSDWebImage(imageView: iv, url: url)
                    #elseif canImport(Kingfisher)
                    _reloadWithKingfisher(imageView: iv, url: url)
                    #endif
                }
            }
            // MARK: - UIButton（前景图 / 背景图）
            if let btn = view as? UIButton {
                // 前景图
                if let url = btn.jobs_remoteURL {
                    let state = btn.jobs_remoteState
                    let kind = btn.jobs_imageLoaderKind
                switch kind {
                    /// 处理 .urlSession 分支
                    case .urlSession:
                        #if canImport(SDWebImage)
                        _reloadWithSDWebImage(button: btn, url: url, state: state)
                        #elseif canImport(Kingfisher)
                        _reloadWithKingfisher(button: btn, url: url, state: state)
                        #endif
                    /// 处理 .sdwebimage 分支
                    case .sdwebimage:
                        #if canImport(SDWebImage)
                        _reloadWithSDWebImage(button: btn, url: url, state: state)
                        #elseif canImport(Kingfisher)
                        _reloadWithKingfisher(button: btn, url: url, state: state)
                        #endif
                    /// 处理 .kingfisher 分支
                    case .kingfisher:
                        #if canImport(Kingfisher)
                        _reloadWithKingfisher(button: btn, url: url, state: state)
                        #elseif canImport(SDWebImage)
                        _reloadWithSDWebImage(button: btn, url: url, state: state)
                        #endif
                    /// 处理 .unknown 分支
                    case .unknown:
                        #if canImport(SDWebImage)
                        _reloadWithSDWebImage(button: btn, url: url, state: state)
                        #elseif canImport(Kingfisher)
                        _reloadWithKingfisher(button: btn, url: url, state: state)
                        #endif
                    }
                }
                // 背景图
                if let url = btn.jobs_bgURL {
                    let state = btn.jobs_bgState
                    let kind = btn.jobs_imageLoaderKind
                switch kind {
                    /// 处理 .urlSession 分支
                    case .urlSession:
                        #if canImport(SDWebImage)
                        _reloadWithSDWebImageBackground(button: btn, url: url, state: state)
                        #elseif canImport(Kingfisher)
                        _reloadWithKingfisherBackground(button: btn, url: url, state: state)
                        #endif
                    /// 处理 .sdwebimage 分支
                    case .sdwebimage:
                        #if canImport(SDWebImage)
                        _reloadWithSDWebImageBackground(button: btn, url: url, state: state)
                        #elseif canImport(Kingfisher)
                        _reloadWithKingfisherBackground(button: btn, url: url, state: state)
                        #endif
                    /// 处理 .kingfisher 分支
                    case .kingfisher:
                        #if canImport(Kingfisher)
                        _reloadWithKingfisherBackground(button: btn, url: url, state: state)
                        #elseif canImport(SDWebImage)
                        _reloadWithSDWebImageBackground(button: btn, url: url, state: state)
                        #endif
                    /// 处理 .unknown 分支
                    case .unknown:
                        #if canImport(SDWebImage)
                        _reloadWithSDWebImageBackground(button: btn, url: url, state: state)
                        #elseif canImport(Kingfisher)
                        _reloadWithKingfisherBackground(button: btn, url: url, state: state)
                        #endif
                    }
                }
            }
            view.subviews.forEach(walk)
        }
        walk(rootView)
        group.notify(queue: .main) {
            completion?()
        }
    }
    /// （可选）一条龙：先清两套缓存，再强制让当前页面图片重下
    @MainActor public static func clearAllCachesAndForceRedownload(
        in rootView: UIView,
        placeholder: UIImage? = nil,
        completion: (jobsByVoidBlock)? = nil
    ) {
        clearSDWebImageCache {
            clearKingfisherCache {
                forceRedownloadImages(in: rootView, placeholder: placeholder, completion: completion)
            }
        }
    }
}
// MARK: - URL bridge（统一字段：jobs_remoteURL / jobs_bgURL）
#if canImport(UIKit)
private var jobs_remoteURLKey: UInt8 = 0
private var jobs_remoteGenerationKey: UInt8 = 0
private var jobs_remoteStateKey: UInt8 = 0
private var jobs_imageLoaderKindKey: UInt8 = 0
private var jobs_remoteImageTargetSizeKey: UInt8 = 0
private var jobs_bgImageTargetSizeKey: UInt8 = 0
private var jobs_imageViewTargetSizeKey: UInt8 = 0
extension UIView {
    var jobs_remoteBindingGeneration: UUID? {
        objc_getAssociatedObject(self, &jobs_remoteGenerationKey) as? UUID
    }
}

public extension UIView {
    /// 统一“前景图 URL 记忆位”
    /// - Note: UIImageView / UIButton 只要是远端图，都建议写入它，便于 JobsImageCacheCleaner 遍历强制重下。
    var jobs_remoteURL: URL? {
        get { objc_getAssociatedObject(self, &jobs_remoteURLKey) as? URL }
        set {
            objc_setAssociatedObject(self, &jobs_remoteURLKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            objc_setAssociatedObject(self, &jobs_remoteGenerationKey, UUID(), .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }

    /// 记录当前控件“实际使用哪个图片框架加载”（用于 forceRedownloadImages 精准选择框架）
    var jobs_imageLoaderKind: JobsImageLoaderKind {
        get {
            let raw = (objc_getAssociatedObject(self, &jobs_imageLoaderKindKey) as? Int) ?? JobsImageLoaderKind.unknown.rawValue
            return JobsImageLoaderKind(rawValue: raw) ?? .unknown
        }
        set {
            objc_setAssociatedObject(self, &jobs_imageLoaderKindKey, newValue.rawValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
}

public extension UIButton {
    /// 统一“前景图对应的 state”，默认 .normal
    var jobs_remoteState: UIControl.State {
        get {
            let raw = (objc_getAssociatedObject(self, &jobs_remoteStateKey) as? UInt) ?? UIControl.State.normal.rawValue
            return UIControl.State(rawValue: raw)
        }
        set {
            objc_setAssociatedObject(self, &jobs_remoteStateKey, newValue.rawValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
    /// ✅ 前景图的目标 UI 尺寸（point）——用于下采样，避免“大图撑开按钮”
    var jobs_remoteImageTargetSize: CGSize? {
        get { (objc_getAssociatedObject(self, &jobs_remoteImageTargetSizeKey) as? NSValue)?.cgSizeValue }
        set {
            if let newValue {
                objc_setAssociatedObject(self, &jobs_remoteImageTargetSizeKey, NSValue(cgSize: newValue), .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            } else {
                objc_setAssociatedObject(self, &jobs_remoteImageTargetSizeKey, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            }
        }
    }
    /// ✅ 背景图的目标 UI 尺寸（point）——用于下采样
    var jobs_bgImageTargetSize: CGSize? {
        get { (objc_getAssociatedObject(self, &jobs_bgImageTargetSizeKey) as? NSValue)?.cgSizeValue }
        set {
            if let newValue {
                objc_setAssociatedObject(self, &jobs_bgImageTargetSizeKey, NSValue(cgSize: newValue), .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            } else {
                objc_setAssociatedObject(self, &jobs_bgImageTargetSizeKey, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            }
        }
    }
}

public extension UIImageView {
    /// ✅ UIImageView 的目标 UI 尺寸（point）——用于下采样
    var jobs_remoteImageTargetSize: CGSize? {
        get { (objc_getAssociatedObject(self, &jobs_imageViewTargetSizeKey) as? NSValue)?.cgSizeValue }
        set {
            if let newValue {
                objc_setAssociatedObject(self, &jobs_imageViewTargetSizeKey, NSValue(cgSize: newValue), .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            } else {
                objc_setAssociatedObject(self, &jobs_imageViewTargetSizeKey, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            }
        }
    }
}

#if canImport(Kingfisher)
public extension UIImageView {
    /// ✅ 用 Kingfisher 设置图片时，建议优先用这个（它会把 url 存起来，方便后续 forceRedownloadImages 扫描到）
    @MainActor
    func jobs_kfSetImage(
        with url: URL?,
        placeholder: UIImage? = nil,
        options: KingfisherOptionsInfo? = nil,
        completion: (@Sendable (Result<RetrieveImageResult, KingfisherError>) -> Void)? = nil
    ) {
        jobs_remoteURL = url
        jobs_imageLoaderKind = .kingfisher
        kf.setImage(
            with: url,
            placeholder: placeholder,
            options: options,
            completionHandler: { result in
                completion?(result)
            }
        )
    }
}
#endif
#endif
