//
//  UIImageView+自研骨架屏呼吸占位效果Shimmer.swift
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
import JobsImageTools
import JobsSwiftDSL
import JobsSwiftBaseDefines

public enum JobsImageFallbackMode {
    case shimmerOnly
    case fallback(UIImage)

    @inline(__always)
    var image: UIImage? {
        switch self {
        /// 处理 .shimmerOnly 分支
        case .shimmerOnly: return nil
        /// 处理 .fallback 分支
        case .fallback(let image): return image
        }
    }
}

private enum JobsImageViewLoadingKeys {
    static var urlKey: UInt8 = 0
    static var tokenKey: UInt8 = 0
}

extension UIImageView {
    private var jobs_loadingURL: URL? {
        get { objc_getAssociatedObject(self, &JobsImageViewLoadingKeys.urlKey) as? URL }
        set { objc_setAssociatedObject(self, &JobsImageViewLoadingKeys.urlKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    private var jobs_loadingToken: JobsImageLoadToken? {
        get { objc_getAssociatedObject(self, &JobsImageViewLoadingKeys.tokenKey) as? JobsImageLoadToken }
        set { objc_setAssociatedObject(self, &JobsImageViewLoadingKeys.tokenKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    @inline(__always)
    private func jobs_runOnMain(_ work: @escaping (UIImageView) -> Void) {
        onMainAsync {
            work(self)
        }
    }

    @inline(__always)
    private func jobs_targetSizeForImageLoading(_ override: CGSize?) -> CGSize? {
        if let override, override.width > 1, override.height > 1 { return override }
        if let size = jobs_remoteImageTargetSize, size.width > 1, size.height > 1 { return size }
        if bounds.width > 1, bounds.height > 1 { return bounds.size };return nil
    }
}

public extension UIImageView {
    @inline(__always)
    func jobs_beginShimmerLoading(config: JobsShimmerConfig = .default) {
        byShimmering(true, config: config)
        onMainAsync { [weak self] in
            guard let self else { return }
            self.jobs_updateShimmerLayout()
        }
    }

    @inline(__always)
    func jobs_endShimmerLoading() {
        byShimmering(false)
    }

    func jobs_cancelImageLoad() {
        jobs_loadingToken?.cancel()
        jobs_loadingToken = nil
        jobs_loadingURL = nil
        jobs_remoteURL = nil
        jobs_imageLoaderKind = .unknown
    }

    @discardableResult
    func jobs_setImage(
        _ src: String?,
        fallback: UIImage? = nil,
        shimmerConfig: JobsShimmerConfig? = .default,
        preferredLoader: JobsImageLoaderPreference = .automatic,
        targetSize: CGSize? = nil,
        forceRefresh: Bool = false,
        fade: TimeInterval = 0.25
    ) -> Self {
        let mode: JobsImageFallbackMode = fallback.map { .fallback($0) } ?? .shimmerOnly
        jobs_loadingToken?.cancel()
        guard let source = JobsImageSource(src) else {
            jobs_cancelImageLoad()
            jobs_handleImageLoadFailure(mode: mode, shimmerConfig: shimmerConfig)
            return self
        }
        switch source {
        /// 处理 .local 分支
        case .local:
            jobs_remoteURL = nil
            jobs_loadingURL = nil
            jobs_imageLoaderKind = .unknown
        /// 处理 .remote 分支
        case .remote(let url):
            jobs_remoteURL = url
            jobs_loadingURL = url
            jobs_imageLoaderKind = .unknown
        }
        if let shimmerConfig {
            image = nil
            jobs_beginShimmerLoading(config: shimmerConfig)
        }
        let options = JobsImageLoadOptions(
            preferredLoader: preferredLoader,
            targetSize: jobs_targetSizeForImageLoading(targetSize),
            forceRefresh: forceRefresh
        )
        jobs_loadingToken = JobsImageLoader.shared.load(source, options: options) { [weak self] result in
            guard let self else { return }
            if case .remote(let url) = source, self.jobs_loadingURL != url { return }
            self.jobs_runOnMain { iv in
                switch result {
                /// 处理 .success 分支
                case .success(let value):
                    iv.jobs_remoteURL = value.url
                    iv.jobs_imageLoaderKind = value.loaderKind
                    iv.jobs_loadingURL = value.url
                    iv.jobs_transition(to: value.image, fade: fade)
                    iv.jobs_endShimmerLoading()
                /// 处理 .failure 分支
                case .failure:
                    iv.jobs_handleImageLoadFailure(mode: mode, shimmerConfig: shimmerConfig)
                }
            }
        };return self
    }

    @inline(__always)
    func jobs_handleImageLoadFailure(
        mode: JobsImageFallbackMode,
        shimmerConfig: JobsShimmerConfig?
    ) {
        if let fallback = mode.image {
            image = fallback
            jobs_endShimmerLoading()
        } else if let shimmerConfig {
            image = nil
            jobs_beginShimmerLoading(config: shimmerConfig)
        } else {
            image = nil
            jobs_endShimmerLoading()
        }
    }

    @inline(__always)
    func jobs_transition(to image: UIImage, fade: TimeInterval) {
        guard fade > 0 else {
            self.image = image
            return
        }
        #if os(iOS) || os(tvOS)
        UIView.transition(
            with: self,
            duration: fade,
            options: .transitionCrossDissolve,
            animations: { self.image = image },
            completion: nil
        )
        #else
        self.image = image
        #endif
    }
}
