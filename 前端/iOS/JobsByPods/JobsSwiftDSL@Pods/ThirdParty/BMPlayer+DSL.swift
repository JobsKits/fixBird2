//
//  BMPlayer+DSL.swift
//  JobsBy3rdTools
//
//  Created by Jobs on 2026年5月13日，星期三.
//

#if os(OSX)
import AppKit
#elseif os(iOS) || os(tvOS)
import UIKit
#endif

import AVFoundation
import MediaPlayer
import JobsSwiftBlock

#if canImport(SnapKit) && canImport(BMPlayer)
import SnapKit
import BMPlayer
// MARK: - 链式配置（byX）
extension BMPlayer {
    // 代理
    @discardableResult
    public func byDelegate(_ delegate: BMPlayerDelegate?) -> Self {
        self.delegate = delegate
        return self
    }
    // 返回按钮回调
    @discardableResult
    public func byBack(_ block: ((Bool) -> Void)?) -> Self {
        self.backBlock = block
        return self
    }
    // 视频重力模式（填充策略）
    @discardableResult
    public func byVideoGravity(_ gravity: AVLayerVideoGravity) -> Self {
        self.videoGravity = gravity
        return self
    }
    // 是否开启/禁用手势（整体开关）
    @discardableResult
    public func byPanGestureEnabled(_ enabled: Bool) -> Self {
        self.panGesture?.isEnabled = enabled
        return self
    }
    // 更新全屏/非全屏 UI（外部状态机驱动时可主动触发）
    @discardableResult
    public func byUpdateUI(isFullScreen: Bool) -> Self {
        self.updateUI(isFullScreen)
        return self
    }
    // 音量微调（增量，默认 0.1）
    @discardableResult
    public func byVolumeUp(step: Float = 0.1) -> Self {
        self.addVolume(step: step)
        return self
    }

    @discardableResult
    public func byVolumeDown(step: Float = 0.1) -> Self {
        self.reduceVolume(step: step)
        return self
    }
    // 绑定播放资源（可选首选清晰度、是否立即自动播）
    @discardableResult
    public func byResource(_ resource: BMPlayerResource,
                           definitionIndex: Int = 0,
                           autoPlay: Bool = BMPlayerConf.shouldAutoPlay) -> Self {
        self.setVideo(resource: resource, definitionIndex: definitionIndex)
        if autoPlay { self.autoPlay() };return self
    }
    // 仅设置资源，不自动播放
    @discardableResult
    public func byResourceNoAutoPlay(_ resource: BMPlayerResource,
                              definitionIndex: Int = 0) -> Self {
        self.setVideo(resource: resource, definitionIndex: definitionIndex)
        return self
    }
    // 约束辅助：将播放器添加到指定视图并用 SnapKit 约束
    @discardableResult
    public func byAddTo(_ container: UIView,
                 make: (_ make: ConstraintMaker) -> Void) -> Self {
        container.addSubview(self)
        self.snp.makeConstraints { make($0) };return self
    }
}
// MARK: - 行为（byX）与控制（onX）
extension BMPlayer {
    // 播放 / 暂停 / 自动播放
    @discardableResult
    public func byPlay() -> Self {
        self.play()
        return self
    }
    /// allowAutoPlay = false 表示用户主动暂停（将阻断 viewWillAppear 的 autoPlay）
    @discardableResult
    public func byPause(allowAutoPlay: Bool = false) -> Self {
        self.pause(allowAutoPlay: allowAutoPlay)
        return self
    }

    @discardableResult
    public func byAutoPlayIfNeeded() -> Self {
        self.autoPlay()
        return self
    }
    // Seek
    @discardableResult
    public func bySeek(to seconds: TimeInterval,
                completion: (jobsByVoidBlock)? = nil) -> Self {
        self.seek(seconds, completion: completion)
        return self
    }
}
// MARK: - 事件回调（onX）
extension BMPlayer {
    /// 播放进度回调 (current, total)
    @discardableResult
    public func onPlayTimeChanged(_ block: @escaping (TimeInterval, TimeInterval) -> Void) -> Self {
        self.playTimeDidChange = block
        return self
    }
    /// 兼容旧回调（已废弃，尽量不用）
    @available(*, deprecated, message: "Use onIsPlayingStateChanged or onPlayStateChanged instead.")
    @discardableResult
    public func onPlayStateDidChange(_ block: @escaping (Bool) -> Void) -> Self {
        self.playStateDidChange = block
        return self
    }
    /// 横竖屏/全屏状态变化（isFullScreen）
    @discardableResult
    public func onOrientChanged(_ block: @escaping (Bool) -> Void) -> Self {
        self.playOrientChanged = block
        return self
    }
    /// 是否处于播放中状态变化（轻量）
    @discardableResult
    public func onIsPlayingStateChanged(_ block: @escaping (Bool) -> Void) -> Self {
        self.isPlayingStateChanged = block
        return self
    }
    /// 播放器业务状态变化（更细粒度，BMPlayerState）
    @discardableResult
    public func onPlayStateChanged(_ block: @escaping (BMPlayerState) -> Void) -> Self {
        self.playStateChanged = block
        return self
    }
}
// MARK: - 语义糖（状态读取）
extension BMPlayer {
    /// 是否在播（对外镜像，避免直接读内部图层）
    public var isPlayingNow: Bool { self.isPlaying }
    /// 当前 AVPlayer（若需要向下扩展）
    public var av: AVPlayer? { self.avPlayer }
}
#endif
