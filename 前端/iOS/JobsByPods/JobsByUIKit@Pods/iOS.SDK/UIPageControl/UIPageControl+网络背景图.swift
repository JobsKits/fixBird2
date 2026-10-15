//
//  UIPageControl+网络背景图.swift
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
import JobsSwiftDSL
import JobsSwiftBaseDefines
import SnapKit

#if canImport(SDWebImage)
import SDWebImage
#endif
#if canImport(Kingfisher)
import Kingfisher
#endif

private var kJobsPCNormalImageKey: UInt8 = 0
private var kJobsPCCurrentImageKey: UInt8 = 0
private var kJobsPCDotDiameterKey: UInt8 = 0
private var kJobsPCDotSpacingKey: UInt8 = 0
private var kJobsPCOverlayKey: UInt8 = 0
private var kJobsPCStackKey: UInt8 = 0
private var kJobsPCDotViewsKey: UInt8 = 0
private var kJobsPCUseOverlayKey: UInt8 = 0
extension UIPageControl {
    // MARK: - Public
    /// 设置“其他页/当前页”指示器图片（本地 UIImage）
    /// - Note: 为了保证网络图/彩色图不被系统 tint 掉，这里默认启用自绘 overlay dots（稳定跨版本）
    public func jobs_setIndicatorImages(
        normal: UIImage?,
        current: UIImage?,
        dotDiameter: CGFloat = 10,
        dotSpacing: CGFloat = 6) {
        // ✅ 强制 alwaysOriginal：保留网络图纹理/颜色
        let n = normal?.withRenderingMode(.alwaysOriginal)
        let c = current?.withRenderingMode(.alwaysOriginal)
        objc_setAssociatedObject(
            self,
            &kJobsPCNormalImageKey,
            n,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
        objc_setAssociatedObject(
            self,
            &kJobsPCCurrentImageKey,
            c,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
        objc_setAssociatedObject(
            self,
            &kJobsPCDotDiameterKey,
            dotDiameter,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
        objc_setAssociatedObject(
            self,
            &kJobsPCDotSpacingKey,
            dotSpacing,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
        // ✅ 只要设置了图片，就用 overlay 渲染（不赌系统内部层级）
        let useOverlay = (n != nil || c != nil)
        objc_setAssociatedObject(
            self,
            &kJobsPCUseOverlayKey,
            useOverlay,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
        if useOverlay {
            // ✅ 隐藏系统默认点，避免叠影
            self.pageIndicatorTintColor = JobsCor.clear
            self.currentPageIndicatorTintColor = JobsCor.clear
        }
        jobs_applyIndicatorImagesIfNeeded()
    }
    /// 每次 currentPage/numberOfPages 变化后调用它刷新图片
    public func jobs_applyIndicatorImagesIfNeeded() {
        let normal = objc_getAssociatedObject(self, &kJobsPCNormalImageKey) as? UIImage
        let current = objc_getAssociatedObject(self, &kJobsPCCurrentImageKey) as? UIImage
        guard normal != nil || current != nil else { return }
        let useOverlay = (objc_getAssociatedObject(self, &kJobsPCUseOverlayKey) as? Bool) ?? false
        guard useOverlay else {
            // 如果你未来想允许“走系统点”，可以在这里加回 setIndicatorImage 的逻辑
            return
        }
        jobs_ensureOverlay()
        jobs_renderOverlayDots(normal: normal, current: current)
    }
    /// DSL：外界只关心：normalURL/currentURL + fallback 图片
    /// 下载成功后会自动调用 jobs_setIndicatorImages(normal:current:)
    public func jobs_setIndicatorImageURLs(
        normalURL: URL?,
        currentURL: URL?,
        fallbackNormal: UIImage?,
        fallbackCurrent: UIImage?,
        dotDiameter: CGFloat = 10,
        dotSpacing: CGFloat = 6) {
        // 先用兜底图顶上，保证立即有 UI
        self.jobs_setIndicatorImages(
            normal: fallbackNormal,
            current: fallbackCurrent,
            dotDiameter: dotDiameter,
            dotSpacing: dotSpacing
        )
        let group = DispatchGroup()
        var normalImage: UIImage? = fallbackNormal
        var currentImage: UIImage? = fallbackCurrent
        group.enter()
        jobs_loadImage(url: normalURL, fallback: fallbackNormal) { img in
            normalImage = img ?? fallbackNormal
            group.leave()
        }
        group.enter()
        jobs_loadImage(url: currentURL, fallback: fallbackCurrent) { img in
            currentImage = img ?? fallbackCurrent
            group.leave()
        }
        group.notify(queue: .main) { [weak self] in
            guard let self else { return }
            // ✅ picsum 是 JPG：裁圆 + 透明背景 + alwaysOriginal
            let n = self.jobs_circleDotImage(normalImage, diameter: dotDiameter) ?? fallbackNormal
            let c = self.jobs_circleDotImage(currentImage, diameter: dotDiameter) ?? fallbackCurrent
            self.jobs_setIndicatorImages(
                normal: n,
                current: c,
                dotDiameter: dotDiameter,
                dotSpacing: dotSpacing
            )
        }
    }
    // MARK: - Overlay Renderer (Stable)
    private func jobs_ensureOverlay() {
        if objc_getAssociatedObject(self, &kJobsPCOverlayKey) as? UIView != nil { return }
        let overlay = UIView()
            .byUserInteractionEnabled(false)
            .byBackgroundColor(JobsCor.clear)
            // overlay 跟随 UIPageControl 自己居中
            .byAddTo(self) { [unowned self] make in
                make.center.equalToSuperview()
                make.height.equalToSuperview()
                make.width.lessThanOrEqualToSuperview()
            }
        objc_setAssociatedObject(
            self,
            &kJobsPCOverlayKey,
            overlay,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
        objc_setAssociatedObject(
            self,
            &kJobsPCStackKey,
            UIStackView()
                .byAxis(.horizontal)
                .byAlignment(.center)
                .byDistribution(.equalSpacing)
                .byBackgroundColor(JobsCor.clear)
                .byAddTo(overlay) { [unowned self] make in
                    make.center.equalToSuperview()
                    make.height.lessThanOrEqualToSuperview()
                },
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
        objc_setAssociatedObject(
            self,
            &kJobsPCDotViewsKey,
            [UIImageView](),
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
    }

    private func jobs_renderOverlayDots(normal: UIImage?, current: UIImage?) {
        guard let stack = objc_getAssociatedObject(self, &kJobsPCStackKey) as? UIStackView else { return }
        let dotDiameter = (objc_getAssociatedObject(self, &kJobsPCDotDiameterKey) as? CGFloat) ?? 10
        let dotSpacing = (objc_getAssociatedObject(self, &kJobsPCDotSpacingKey) as? CGFloat) ?? 6
        stack.bySpacing(dotSpacing)
        let pages = max(0, self.numberOfPages)
        let currentIndex = max(0, min(self.currentPage, max(0, pages - 1)))
        // 拿到旧数组
        var dots = (objc_getAssociatedObject(self, &kJobsPCDotViewsKey) as? [UIImageView]) ?? []
        // 需要增/减 dotViews
        if dots.count > pages {
            // 移除多余的
            for i in stride(from: dots.count - 1, through: pages, by: -1) {
                let v = dots[i]
                v.removeFromSuperview()
                dots.remove(at: i)
            }
        } else if dots.count < pages {
            // 增加不足的
            for _ in dots.count..<pages {
                dots.append(
                    UIImageView()
                        .byUserInteractionEnabled(false)
                        .byContentMode(.scaleAspectFit)
                        .byAddTo(stack) { [unowned self] make in
                            make.width.height.equalTo(dotDiameter)
                        })
            }
        }
        // 更新图片
        for (idx, iv) in dots.enumerated() {
            if idx == currentIndex {
                iv.image = (current ?? normal)?.withRenderingMode(.alwaysOriginal)
            } else {
                iv.image = normal?.withRenderingMode(.alwaysOriginal)
            }
        }
        objc_setAssociatedObject(
            self,
            &kJobsPCDotViewsKey,
            dots,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
        stack.byRemakeConstraints { make in
            make.center.equalToSuperview()
            make.height.lessThanOrEqualToSuperview()
            make.width.greaterThanOrEqualTo(CGFloat(pages) * dotDiameter + CGFloat(max(0, pages - 1)) * dotSpacing).priority(.required) // 让 stack 的宽度更确定，避免被压缩到 1 个点的视觉
            make.width.lessThanOrEqualToSuperview().priority(.required)
        }
    }
    // MARK: - Image Helpers
    /// 把任意图片裁成“圆形 + 透明背景”，并强制 alwaysOriginal
    private func jobs_circleDotImage(_ image: UIImage?, diameter: CGFloat) -> UIImage? {
        guard let image else { return nil }
        let size = CGSize(width: diameter, height: diameter)
        let out = UIGraphicsImageRenderer(size: size).image { _ in
            let rect = CGRect(origin: .zero, size: size)
            UIBezierPath.make(ovalIn: rect).addClip()
            image.draw(in: rect)
        };return out.withRenderingMode(.alwaysOriginal)
    }
    // MARK: - Image Loader
    private func jobs_loadImage(
        url: URL?,
        fallback: UIImage?,
        completion: @escaping (UIImage?) -> Void) {
        guard let url else {
            onMainAsync {
                completion(fallback)
            };return
        }
        #if canImport(SDWebImage)
        SDWebImageManager.shared.loadImage(
            with: url,
            options: [.retryFailed, .highPriority],
            progress: nil
        ) { image, _, error, _, _, _ in
            onMainAsync {
                if error != nil { completion(fallback) }
                else { completion(image ?? fallback) }
            }
        };return
        #endif
        #if canImport(Kingfisher)
        KingfisherManager.shared.retrieveImage(with: url) { result in
            onMainAsync {
                switch result {
                /// 处理 .success 分支
                case .success(let value): completion(value.image)
                /// 处理 .failure 分支
                case .failure: completion(fallback)
                }
            }
        };return
        #endif
        URLSession.shared.dataTask(with: url) { data, _, _ in
            onMainAsync {
                completion(data.flatMap { UIImage(data: $0) } ?? fallback)
            }
        }.resume()
    }
}
