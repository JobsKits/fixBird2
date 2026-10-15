//
//  UIButton+声音.swift
//  JobsByUIKit
//
//  Created by Jobs on 2026年5月13日，星期三.
//

#if os(OSX)
import AppKit
#elseif os(iOS) || os(tvOS)
import UIKit
#endif

import AVFoundation

// =============== 全局默认值（保持不变） ===============
public enum JobsSound {
    public static var defaults = Defaults()
    public struct Defaults {
        public var bundle: Bundle = .main
        public var ignoreSilentSwitch = false   // 遵从静音键
        public var mixWithOthers = true         // 允许与其它 App 混音
        public init() {}
    }
}
// =============== 内部存储 ===============
private final class _JobsSoundBox: NSObject {
    let url: URL
    let ignoreSilentSwitch: Bool
    let mixWithOthers: Bool
    init(url: URL, ignoreSilentSwitch: Bool, mixWithOthers: Bool) {
        self.url = url
        self.ignoreSilentSwitch = ignoreSilentSwitch
        self.mixWithOthers = mixWithOthers
    }
}

private var _kTapSoundBoxKey: UInt8 = 0
private var _kTapSoundPlayerKey: UInt8 = 0
private var _kTapSoundActionIDKey: UInt8 = 0   // 仅 iOS14+ 用于 removeAction
private var _kTapSoundActionKey: UInt8 = 0
extension UIButton {
    @discardableResult
    public func byTapSound(_ nameWithExt: String) -> Self {
        // 查找资源
        let ns = nameWithExt as NSString
        let ext = ns.pathExtension
        let base = ns.deletingPathExtension
        guard !base.isEmpty,
              let url = JobsSound.defaults.bundle.url(forResource: base,
                                                      withExtension: ext.isEmpty ? nil : ext)
        else {
            // 找不到：解绑并静默
            _jobs_unbindTapHandler()
            objc_setAssociatedObject(
                self,
                &_kTapSoundBoxKey,
                nil,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
            objc_setAssociatedObject(
                self,
                &_kTapSoundPlayerKey,
                nil,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            );return self
        }
        // 固化当前默认配置
        let box = _JobsSoundBox(url: url,
                                ignoreSilentSwitch: JobsSound.defaults.ignoreSilentSwitch,
                                mixWithOthers: JobsSound.defaults.mixWithOthers)
        objc_setAssociatedObject(
            self,
            &_kTapSoundBoxKey,
            box,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
        // 绑定点击：iOS14+ 用 UIAction(闭包)，老系统回退到 target-action
        _jobs_bindTapHandler()
        return self
    }

    @discardableResult
    public func byRemoveTapSound() -> Self {
        _jobs_unbindTapHandler()
        objc_setAssociatedObject(
            self,
            &_kTapSoundBoxKey,
            nil,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
        objc_setAssociatedObject(
            self,
            &_kTapSoundPlayerKey,
            nil,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        );return self
    }
    // MARK: - 点击时播放（核心逻辑）
    @objc private func _jobs_onTapPlaySound() {
        guard let box = objc_getAssociatedObject(self, &_kTapSoundBoxKey) as? _JobsSoundBox else { return }
        let session = AVAudioSession.sharedInstance()
        let category: AVAudioSession.Category = box.ignoreSilentSwitch ? .playback : .ambient
        var options: AVAudioSession.CategoryOptions = []
        if box.mixWithOthers { options.insert(.mixWithOthers) }
        try? session.setCategory(category, mode: .default, options: options)
        try? session.setActive(true, options: [])
        var player = objc_getAssociatedObject(self, &_kTapSoundPlayerKey) as? AVAudioPlayer
        if player == nil {
            player = try? AVAudioPlayer(contentsOf: box.url)
            player?.numberOfLoops = 0
            player?.prepareToPlay()
            objc_setAssociatedObject(
                self,
                &_kTapSoundPlayerKey,
                player,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
        }
        guard let p = player else { return }
        if p.isPlaying {
            p.stop()
            p.currentTime = 0
        };p.play()
    }

    private func _jobs_bindTapHandler() {
        if #available(iOS 14.0, *) {
            // 先移除旧 UIAction
            if let old = objc_getAssociatedObject(self, &_kTapSoundActionKey) as? UIAction {
                removeAction(old, for: .touchUpInside)
            }
            // 新建并保存 UIAction（闭包回调）
            let action = UIAction { [weak self] _ in
                self?._jobs_onTapPlaySound()
            }
            addAction(action, for: .touchUpInside)
            objc_setAssociatedObject(
                self,
                &_kTapSoundActionKey,
                action,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
        } else {
            // 回退：target-action
            removeTarget(self, action: #selector(_jobs_onTapPlaySound), for: .touchUpInside)
            addTarget(self, action: #selector(_jobs_onTapPlaySound), for: .touchUpInside)
        }
    }

    private func _jobs_unbindTapHandler() {
        if #available(iOS 14.0, *) {
            if let old = objc_getAssociatedObject(self, &_kTapSoundActionKey) as? UIAction {
                removeAction(old, for: .touchUpInside)   // ✅ 正确的移除方式
                objc_setAssociatedObject(
                    self,
                    &_kTapSoundActionKey,
                    nil,
                    .OBJC_ASSOCIATION_RETAIN_NONATOMIC
                )
            }
        } else {
            removeTarget(self, action: #selector(_jobs_onTapPlaySound), for: .touchUpInside)
        }
    }
}
