//
//  UIButton+呼吸占位效果.swift
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
import JobsSwiftBaseDefines
/// 用于区分不同图片加载器的 token 空间，避免互相干扰。

internal enum JobsButtonImageLoader: UInt8 {
    case sd = 1
    case kf = 2
}
/// 用于区分前景/背景请求的 token 空间。
internal enum JobsButtonTokenChannel: UInt8 {
    case foreground = 1
    case background = 2
}
private enum _JobsButtonTokenAOKey { static var tokenMap: UInt8 = 0 }
extension UIButton {
    // MARK: - Main thread helper
    /// ✅ 统一主线程执行：避免占位/回调乱序覆盖
    internal func _jobs_runOnMain(_ work: @escaping (UIButton) -> Void) {
        onMainImmediateOrAsync(self) { button in
            work(button)
        }
    }
    // MARK: - Token helpers（解决：旧请求回调/取消回调把新请求的 shimmer 停掉）
    @discardableResult
    internal func _jobs_nextToken(loader: JobsButtonImageLoader,
                                  channel: JobsButtonTokenChannel,
                                  for state: UIControl.State) -> Int {
        var map = (objc_getAssociatedObject(self, &_JobsButtonTokenAOKey.tokenMap) as? [UInt64: Int]) ?? [:]
        let key = (UInt64(loader.rawValue) << 56) | (UInt64(channel.rawValue) << 48) | UInt64(state.rawValue)
        let next = (map[key] ?? 0) + 1
        map[key] = next
        objc_setAssociatedObject(
            self,
            &_JobsButtonTokenAOKey.tokenMap,
            map,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        );return next
    }

    func _jobs_isCurrentToken(_ token: Int,
                             loader: JobsButtonImageLoader,
                             channel: JobsButtonTokenChannel,
                             for state: UIControl.State) -> Bool {
        let map = (objc_getAssociatedObject(self, &_JobsButtonTokenAOKey.tokenMap) as? [UInt64: Int]) ?? [:]
        let key = (UInt64(loader.rawValue) << 56) | (UInt64(channel.rawValue) << 48) | UInt64(state.rawValue)
        return map[key] == token
    }
    // MARK: - Shimmer helpers（loading 占位）
    func _jobs_startForegroundShimmer(targetSize: CGSize) {
        self._jobs_startForegroundShimmerOverlay(targetSize: targetSize)
    }

    func _jobs_stopForegroundShimmer() {
        self._jobs_stopForegroundShimmerOverlay()
    }
    /// ✅ 背景 shimmer：默认必须保证文字层在最上面（避免被 overlay 盖住）
    func _jobs_startBackgroundShimmer() {
        self.jobs_startShimmer()
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            // ✅ 关键：把文字层提到最前，避免被 shimmer overlay 盖住
            if let tl = self.titleLabel { self.bringSubviewToFront(tl) }
            // subTitle 很可能也是 UILabel（bySubTitle 添加的），一起提到最前
            for v in self.subviews where v is UILabel {
                self.bringSubviewToFront(v)
            }
            // 如果按钮还有前景图，也一并提到最前（可选）
            if let iv = self.imageView { self.bringSubviewToFront(iv) }
            self.jobs_updateShimmerLayout()
        }
    }

    func _jobs_stopBackgroundShimmer() {
        self.jobs_stopShimmer()
    }
    // MARK: - Force set image helpers（避免 jobsReset 的“已有 image 不覆盖”保护挡掉最终图）
    /// ✅ 强制写入“前景图”（先走 jobsReset；如果没生效再强制覆盖）
    func _jobs_forceSetForegroundImage(_ image: UIImage?, for state: UIControl.State) {
        self.jobsResetBtnImage(image, for: state)
        if #available(iOS 15.0, *), state == .normal, var cfg = self.configuration {
            let current = cfg.image
            if (current !== image) && !(current == nil && image == nil) {
                cfg.image = image
                self.configuration = cfg
            }
        } else {
            let current = self.image(for: state)
            if (current !== image) && !(current == nil && image == nil) {
                self.setImage(image, for: state)
            }
        }
    }
    /// ✅ 强制写入“背景图”（逻辑同上）
    func _jobs_forceSetBackgroundImage(_ image: UIImage?, for state: UIControl.State) {
        self.jobsResetBtnBgImage(image, for: state)
        if #available(iOS 15.0, *), state == .normal, var cfg = self.configuration {
            let current = cfg.background.image
            if (current !== image) && !(current == nil && image == nil) {
                cfg.background.image = image
                self.configuration = cfg
            }
        } else {
            let current = self.backgroundImage(for: state)
            if (current !== image) && !(current == nil && image == nil) {
                self.setBackgroundImage(image, for: state)
            }
        }
    }
    // MARK: - Target size guessing
    func _jobs_guessForegroundTargetSize() -> CGSize {
        if let s = self.jobs_remoteImageTargetSize, s.width > 1, s.height > 1 { return s }
        if let iv = self.imageView {
            let s = iv.bounds.size
            if s.width > 1, s.height > 1 { return s }
        }
        let h = self.bounds.size.height
        if h > 1 {
            let side = max(24, h - 16)
            return CGSize(width: side, height: side)
        };return CGSize(width: 48, height: 48)
    }

    internal func _jobs_guessBackgroundTargetSize() -> CGSize {
        if let s = self.jobs_bgImageTargetSize, s.width > 1, s.height > 1 { return s }
        let s = self.bounds.size
        if s.width > 1, s.height > 1 { return s };return CGSize(width: 320, height: 64)
    }
    // MARK: - Loading placeholder
    /// 用于撑开 imageView frame，便于 overlay 精准覆盖
    internal func _jobs_loadingPlaceholderImage(targetPointSize: CGSize, fallback: UIImage?) -> UIImage? {
        guard let fallback else {
            return UIImage._jobs_transparentPlaceholder(size: targetPointSize)
        };return fallback
    }
}
// MARK: - Transparent placeholder (internal)
extension UIImage {
    static func _jobs_transparentPlaceholder(size: CGSize,
                                             scale: CGFloat = UIScreen.main.scale) -> UIImage {
        let w = max(1, size.width)
        let h = max(1, size.height)
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        format.opaque = false
        return UIGraphicsImageRenderer(size: CGSize(width: w, height: h), format: format).image { _ in }
    }
}
