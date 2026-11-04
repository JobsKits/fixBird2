//
//  JobsSwiftTimerProtocol.swift
//  JobsSwiftTimer
//
//  Created by Jobs on 2026年5月13日，星期三.
//

import Foundation
/**
 
     let t = JobsTimer(kind: kind, config: config) { [weak self] in
         guard let self else { return }
         guard self.state == .running else { return }
         guard let start = self.startDate else { return }
             /// TODO
     }

     timer?.stop()
     timer = t
     t.start()
 */
// MARK: - 统一协议
public protocol JobsSwiftTimerProtocol: AnyObject {
    /// 计时器当前是否处于运行中
    var isRunning: Bool { get }
    /// 生命周期操作是否必须路由到主线程；自定义实现默认按主线程安全策略处理
    var requiresMainThreadLifecycle: Bool { get }
    /// 启动计时器
    @discardableResult
    func start() -> Self
    /// 暂停计时器
    @discardableResult
    func pause() -> Self
    /// 恢复计时器
    @discardableResult
    func resume() -> Self
    /// 停止计时器并异步提交一次 tick，随后执行 finish；已停止时不重复投递。
    @discardableResult
    func fireOnce() -> Self
    /// 停止计时器（销毁@无回调）
    @discardableResult
    func stop() -> Self
    /// 注册回调（每 tick 执行一次）
    @discardableResult
    func onTick(_ block: @escaping JobsTimerCallback) -> Self
    /// 注册完成回调（用于一次性定时器或倒计时）
    @discardableResult
    func onFinish(_ block: @escaping JobsTimerCallback) -> Self
}

public extension JobsSwiftTimerProtocol {
    var requiresMainThreadLifecycle: Bool { true }
}
