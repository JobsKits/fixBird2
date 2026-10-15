//
//  JobsImageCacheCleanerByUIKit.swift
//  JobsImageTools
//
//  Created by Jobs on 2026年5月13日，星期三.
//

#if os(OSX)
import AppKit
#elseif os(iOS) || os(tvOS)
import UIKit
#endif

import JobsSwiftBaseDefines
import JobsSwiftDSL

public var _jobsCfgBgImageKey: UInt8 = 0
private var _jobsBGGenerationKey: UInt8 = 0
private var _jobsBGURLKey:   UInt8 = 0   // URL?
private var _jobsBGStateKey: UInt8 = 0   // UIControl.State.RawValue
extension UIButton {
    var jobs_bgBindingGeneration: UUID? {
        objc_getAssociatedObject(self, &_jobsBGGenerationKey) as? UUID
    }
}

public extension UIButton {
    /// 最近一次设置“背景图”的 URL（供克隆或复用）
    var jobs_bgURL: URL? {
        get { objc_getAssociatedObject(self, &_jobsBGURLKey) as? URL }
        set {
            objc_setAssociatedObject(self, &_jobsBGURLKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            objc_setAssociatedObject(self, &_jobsBGGenerationKey, UUID(), .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
    /// 最近一次设置背景图时使用的 state
    var jobs_bgState: UIControl.State {
        get { UIControl.State(rawValue: (objc_getAssociatedObject(self, &_jobsBGStateKey) as? UInt) ?? UIControl.State.normal.rawValue) }
        set { objc_setAssociatedObject(self, &_jobsBGStateKey, newValue.rawValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    var jobs_cfgBgImage: UIImage? {
        get { objc_getAssociatedObject(self, &_jobsCfgBgImageKey) as? UIImage }
        set { objc_setAssociatedObject(self, &_jobsCfgBgImageKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    @available(iOS 15.0, *)
    @discardableResult
    func byUpdateConfig() -> Self {
        self.setNeedsUpdateConfiguration()
        self.updateConfiguration()
        self.automaticallyUpdatesConfiguration = true
        return self
    }
    @MainActor
    func jobsResetBtnImage(_ image: UIImage?, for state: UIControl.State) {
        if #available(iOS 15.0, *) {
            var cfg = self.configuration ?? .plain()  // ✅ 没有也创建；前景建议用 .plain()
            cfg.image = image                         // ✅ 前景图写到 configuration.image
            self.configuration = cfg
            byUpdateConfig()
        } else {
            self.setImage(image, for: state)          // ✅ 旧系统走 legacy API
        }
        if #available(iOS 15.0, *) {
            self.setNeedsUpdateConfiguration()
        }
    }
    @MainActor
    func jobsResetBtnBgImage(_ image: UIImage?, for state: UIControl.State) {
        // 先把最终图粘住，供后续任何 config 重建时回填
        self.jobs_cfgBgImage = image
        // ① legacy 背景图：立刻可见，最稳
        self.setBackgroundImage(image, for: state)
        // ② iOS 15+：把同一张图同步到 configuration.background，避免被下一次重建抹掉
        if #available(iOS 15.0, *) {
            var cfg = self.configuration ?? .plain()
            var bg  = cfg.background
            bg.image = image
            if bg.imageContentMode == .scaleToFill { bg.imageContentMode = .scaleAspectFill }
            bg.byBackgroundColor(JobsCor.clear)
            cfg.background = bg
            self.configuration = cfg
            // 让生命周期继续，但这里不要马上“强制”刷新，避免刚设的图被别的 handler 抢写
            self.automaticallyUpdatesConfiguration = true
            // self.setNeedsUpdateConfiguration()  // ← 刻意不在这里触发
        }
        // 保险刷新
        self.setNeedsLayout()
        self.layoutIfNeeded()
        self.setNeedsDisplay()
    }
}
