//
//  JobsBaseMain.swift
//  JobsSwiftBaseDefines
//
//  Created by Jobs on 2026年5月13日，星期三.
//

#if os(OSX)
import AppKit
#elseif os(iOS) || os(tvOS)
import UIKit
#endif

import JobsSwiftBlock

// MARK: - 文件设计总览
/**
 `JobsBaseMain.swift`

 这个文件只做一件事：
 **把“与主线程 / MainActor 相关的调度行为”按语义分层整理清楚。**

 --------------------------------------------------
 一、为什么不能只写一个“runOnMain”
 --------------------------------------------------

 因为“切到主线程”至少存在三种完全不同的控制流语义：

 1. Async（异步投递）
    - 把任务安排到主线程 / MainActor 稍后执行
    - 当前调用点不会等待它执行完
    - 适合 UI 更新、回调切线程、事件响应
    - 不适合要求“当前返回前必须完成”的逻辑

 2. ImmediateOrAsync（主线程立即执行，否则异步）
    - 如果当前已经在主线程：立刻执行
    - 如果当前不在主线程：异步派发到主线程
    - 适合希望“已在主线程就不要再排队”的轻量 UI 逻辑
    - 依然不保证跨线程调用时同步完成

 3. Sync（同步切主线程）
    - 如果当前已经在主线程：立刻执行
    - 如果当前不在主线程：同步切到主线程并等待执行完成
    - 适合必须在当前返回前完成的逻辑
    - 例如：严格时序状态切换、同步读取、必须完成的清理 / 注销 / 收尾
    - 使用不当可能阻塞线程，甚至导致死锁

 --------------------------------------------------
 二、重要原则
 --------------------------------------------------

 1. “切到主线程执行” ≠ “当前函数返回前已经执行完”
    - Async / Task / DispatchQueue.main.async 都不保证同步完成
    - 只有 Sync 语义才保证“当前返回前执行完”

 2. Async 不能替代 Sync
    - UI 更新大多数时候用 Async 就够了
    - 但 deinit、严格清理、同步依赖场景绝不能偷换成 Async

 3. deinit 中禁止依赖 Async main dispatch 做清理
    - deinit 返回后对象就进入析构完成态
    - 若把依赖 self 的清理异步扔到未来，任务执行时 self 很可能已不存在
    - 所以 deinit 中若必须清理，通常只能用同步路径，或提前在生命周期中完成

 4. MainActor 语义 与 主线程语义 大多数 UI 场景一致，但不是一回事
    - `@MainActor` 属于 Swift Concurrency 隔离语义
    - `DispatchQueue.main` / `Thread.isMainThread` 属于线程 / GCD 语义
    - 二者在大量 UI 场景下表现接近，但不能机械地认为完全等价
    - 本文件会尽量把这两者的边界写清楚，不混淆

 5. API 的目标不是“越多越全”，而是“少而准”
    - 主入口要少
    - 命名要直给
    - 生命周期边界要清楚
    - 宁可明确，也不要靠调用者猜
 */
// MARK: - 命名约定说明
/**
 命名规则：

 1. `onMainAsync`
    表示：异步投递到主线程 / MainActor，不等待完成

 2. `onMainImmediateOrAsync`
    表示：若已在主线程则立即执行，否则异步投递

 3. `onMainImmediateOrAsyncWeak`
    表示：与 `onMainImmediateOrAsync` 语义相同，但 object 版本在主线程分支也坚持弱化

 4. `onMainSync`
    表示：若不在主线程则同步切过去，并等待完成

 5. `onMainTask`
    表示：返回 / 启动一个可取消的主线程 Task（本质仍是异步）

 6. `observeOnMain`
    表示：在 MainActor 上消费 AsyncSequence，并返回可取消任务；默认吞错以维持 `Never` 失败语义

 7. `observeOnMainThrowing`
    表示：在 MainActor 上消费 AsyncSequence，并把错误向上传递给调用方
 */
// MARK: - Async：异步投递到主线程 / MainActor（不等待完成）
#if compiler(>=5.5)
/// 异步投递到 MainActor。
///
/// - 语义：
///   - 永远是“异步安排稍后执行”
///   - 不保证立即执行
///   - 不保证在当前函数返回前执行完
///
/// - 适用场景：
///   - UI 更新
///   - 异步回调切回主线程
///   - 用户交互后的主线程收尾
///
/// - 不适用场景：
///   - deinit
///   - 必须当前完成的清理 / 注销
///   - 后续逻辑依赖它已执行完成的路径
///
/// - 兼容性：
///   - iOS/tvOS 13+、macOS 10.15+：使用 MainActor / Task
///   - 更低系统：降级为 DispatchQueue.main.async
@inline(__always)
public func onMainAsync(
    _ block: @MainActor @escaping () -> Void) {
    if #available(iOS 13.0, tvOS 13.0, macOS 10.15, *) {
        Task { @MainActor in
            block()
        }
    } else {
        DispatchQueue.main.async {
            block()
        }
    }
}
/// 异步投递到 MainActor，支持 async 闭包（内部允许 await）。
///
/// - 语义与 `onMainAsync(_ block: @MainActor @escaping () -> Void)` 相同，
///   只是 block 内允许 `await`。
///
/// - 兼容性：
///   - async/await / MainActor 仅在 Swift 5.5 且 iOS/tvOS 13+、macOS 10.15+ 可用
@available(iOS 13.0, tvOS 13.0, macOS 10.15, *)
@inline(__always)
public func onMainAsync(
    _ block: @MainActor @escaping () async -> Void) {
    Task { @MainActor in
        await block()
    }
}
/// 异步投递到 MainActor，并把 object 作为参数传入。
///
/// - 注意：
///   - object 采用 **weak capture**
///   - 若真正执行时 object 已释放，则 block 不会执行
///
/// - 适用场景：
///   - UIViewController / ViewModel / Coordinator 等生命周期绑定对象
///   - 避免在闭包里直接强捕获 self
///
/// - 不适用场景：
///   - 必须执行的收尾逻辑
///   - deinit 中依赖 self 的析构清理
@inline(__always)
public func onMainAsync<Object: AnyObject>(
    _ object: Object?,
    _ block: @MainActor @escaping (Object) -> Void) {
    guard let object else { return }
    if #available(iOS 13.0, tvOS 13.0, macOS 10.15, *) {
        Task { @MainActor [weak object] in
            guard let object else { return }
            block(object)
        }
    } else {
        DispatchQueue.main.async { [weak object] in
            guard let object else { return }
            block(object)
        }
    }
}
/// 异步投递到 MainActor，并把 object 作为参数传入；block 可 await。
///
/// - 注意：
///   - object 采用 **weak capture**
///   - 若真正执行时 object 已释放，则 block 不会执行
@available(iOS 13.0, tvOS 13.0, macOS 10.15, *)
@inline(__always)
public func onMainAsync<Object: AnyObject>(
    _ object: Object?,
    _ block: @MainActor @escaping (Object) async -> Void) {
    guard let object else { return }
    Task { @MainActor [weak object] in
        guard let object else { return }
        await block(object)
    }
}
#else
/// Swift < 5.5：没有 MainActor / async/await，只能保证异步切到主线程。
///
/// - 语义仍然是“异步投递，不等待完成”。
@inline(__always)
public func onMainAsync(
    _ block: @escaping () -> Void) {
    DispatchQueue.main.async(execute: block)
}

/// Swift < 5.5：object 版本，弱持有 object。
///
/// - 若真正执行时 object 已释放，则 block 不会执行。
@inline(__always)
public func onMainAsync<Object: AnyObject>(
    _ object: Object?,
    _ block: @escaping (Object) -> Void) {
    guard let object else { return }
    DispatchQueue.main.async { [weak object] in
        guard let object else { return }
        block(object)
    }
}
#endif
// MARK: - ImmediateOrAsync：若已在主线程则立即执行，否则异步派发
/**
 若当前已在主线程则立即执行，否则异步派发到主线程。

 - 语义：
   - 当前在主线程：立刻执行，不排队
   - 当前不在主线程：DispatchQueue.main.async

 - 适用场景：
   - UI 刷新
   - “如果已经在主线程就不要再排队”的轻量工作
   - 希望减少主线程不必要的再次派发

 - 不适用场景：
   - 需要同步完成的逻辑
   - deinit 中依赖 self 的清理
   - 后续代码依赖此处已经执行完

 - 边界说明：
   - 这里判断的是“当前是否在主线程”，不是“当前是否处于 MainActor 隔离上下文”
   - 对 UIKit / AppKit 的绝大多数场景这已经足够
   - 若你的团队要求严格的 Concurrency 风格，应优先使用 `onMainAsync` / `onMainTask`
 */
@inline(__always)
public func onMainImmediateOrAsync(
    _ block: @escaping jobsByVoidBlock) {
    Thread.isMainThread ? block() : DispatchQueue.main.async(execute: block)
}
/// object 版本：若当前已在主线程则立即执行，否则异步派发到主线程。
///
/// - 注意：
///   - 仅在“非主线程分支”下使用 weak capture
///   - 若异步派发后 object 已释放，则 block 不会执行
///
/// - 这样设计的原因：
///   - 当前已在主线程时，既然调用者此刻就持有 object，立即执行是最直接、最低开销的路径
///   - 跨线程异步派发时再使用 weak capture，避免生命周期被延长
///
/// - 这是默认推荐策略：
///   - 它优先保证当前栈内执行路径的直接性与低开销
///   - 若业务明确需要“始终弱化”的特殊语义，应使用下方 `onMainImmediateOrAsyncWeak`
@inline(__always)
public func onMainImmediateOrAsync<Object: AnyObject>(
    _ object: Object?,
    _ block: @escaping (Object) -> Void) {
    guard let object else { return }
    if Thread.isMainThread {
        block(object)
    } else {
        DispatchQueue.main.async { [weak object] in
            guard let object else { return }
            block(object)
        }
    }
}
// MARK: - ImmediateOrAsyncWeak：若已在主线程则立即执行，否则异步派发；但 object 版本始终弱化
/**
 `onMainImmediateOrAsyncWeak` 与 `onMainImmediateOrAsync` 的差异只在 object 版本：

 - 默认版：
   - 主线程分支直接执行
   - 非主线程分支 weak capture

 - Weak 版：
   - 无论主线程还是非主线程分支，都坚持以“弱化 object”为优先策略

 适用场景：
 - 团队强调 object 版本在所有路径下都保持一致的弱化语义
 - 希望 API 层面更保守地处理生命周期
 */
@inline(__always)
public func onMainImmediateOrAsyncWeak(
    _ block: @escaping jobsByVoidBlock) {
    Thread.isMainThread ? block() : DispatchQueue.main.async(execute: block)
}
/// object 版本：始终弱化 object。
///
/// - 注意：
///   - 即使当前已经在主线程，也会先通过弱引用重新检查 object 是否仍然有效
///   - 这会比默认版略微保守，但语义更统一
@inline(__always)
public func onMainImmediateOrAsyncWeak<Object: AnyObject>(
    _ object: Object?,
    _ block: @escaping (Object) -> Void) {
    guard object != nil else { return }
    if Thread.isMainThread {
        weak var weakObject = object
        guard let object = weakObject else { return }
        block(object)
    } else {
        DispatchQueue.main.async { [weak object] in
            guard let object else { return }
            block(object)
        }
    }
}
// MARK: - Sync：同步切到主线程并等待完成
/**
 同步在主线程执行一个无返回值任务。

 - 语义：
   - 当前已在主线程：立即执行
   - 当前不在主线程：同步切到主线程，并等待执行完成后才返回

 - 适用场景：
   - 必须在当前返回前完成的收尾逻辑
   - 注销 / 解绑 / 状态切换
   - 必须同步主线程访问的代码

 - 风险：
   - 会阻塞当前线程
   - 若主线程与当前线程存在互等关系，可能死锁
   - 请勿在复杂锁竞争链上滥用
 */
@inline(__always)
public func onMainSync(
    _ work: () -> Void) {
    if Thread.isMainThread {
        work()
    } else {
        DispatchQueue.main.sync(execute: work)
    }
}
/// 同步在主线程执行并返回结果。
///
/// - 适用场景：
//   - 必须在主线程读取某个值
//   - 后续逻辑立刻依赖该结果
@inline(__always)
@discardableResult
public func onMainSync<T>(
    _ work: () -> T) -> T {
    if Thread.isMainThread {
        return work()
    } else {
        return DispatchQueue.main.sync(execute: work)
    }
}
/// 同步在主线程执行并返回结果，支持 throws。
///
/// - 若当前已在主线程，直接执行并透传错误
/// - 若当前不在主线程，则同步切到主线程执行并透传错误
@inline(__always)
@discardableResult
public func onMainSync<T>(
    _ work: () throws -> T) rethrows -> T {
    if Thread.isMainThread {
        return try work()
    } else {
        return try DispatchQueue.main.sync(execute: work)
    }
}
// MARK: - Main Task：返回/启动一个可取消的主线程任务
#if compiler(>=5.5)
/// 在 MainActor 上启动一个 async Task，并返回 Task 句柄。
///
/// - 语义：
///   - 仍然是异步调度
///   - 返回 Task 只是为了让调用方可以持有 / cancel / 绑定生命周期
///
/// - 适用场景：
///   - 需要取消的主线程异步任务
///   - 想把任务句柄保存到属性中
///   - 与生命周期联动的 UI 异步任务
///
/// - 不适用场景：
///   - 误以为“返回 Task 就等于同步执行”
///   - deinit 中依赖 self 的异步清理
@available(iOS 13.0, tvOS 13.0, macOS 10.15, *)
@discardableResult
@inline(__always)
public func onMainTask(
    _ block: @MainActor @escaping () async -> Void) -> Task<Void, Never> {
    Task { @MainActor in
        await block()
    }
}
/// object 版本：在 MainActor 上启动 async Task，并弱持有 object。
///
/// - 注意：
///   - object 为 weak capture
///   - 若 Task 真正执行时 object 已释放，则 block 不会执行
@available(iOS 13.0, tvOS 13.0, macOS 10.15, *)
@discardableResult
@inline(__always)
public func onMainTask<Object: AnyObject>(
    _ object: Object?,
    _ block: @MainActor @escaping (Object) async -> Void) -> Task<Void, Never>? {
    guard let object else { return nil };return Task { @MainActor [weak object] in
        guard let object else { return }
        await block(object)
    }
}
/// 在主线程 / MainActor 上启动一个“无需 await 的任务”。
///
/// - 说明：
///   - block 自己不是 async
///   - 但调度本质仍然是异步
///
/// - 兼容性：
///   - 新系统返回真正的 Task
///   - 老系统退化为 GCD 异步派发，因此无法返回可取消 Task，返回 nil
///
/// - 设计说明：
///   - 这里的 `nil` 不是失败，而是低版本平台没有 `Task` 句柄这一能力
///   - 换句话说：低版本仍然保留“调度语义”，只是没有“取消语义”
@discardableResult
@inline(__always)
public func onMainTask(
    _ block: @MainActor @escaping () -> Void) -> Task<Void, Never>? {
    if #available(iOS 13.0, tvOS 13.0, macOS 10.15, *) {
        return Task { @MainActor in
            block()
        }
    } else {
        DispatchQueue.main.async {
            block()
        };return nil
    }
}
/// object 版本：在主线程 / MainActor 上启动一个“无需 await 的任务”。
///
/// - 注意：
///   - object 为 weak capture
///   - 若执行时 object 已释放，则 block 不会执行
///
/// - 兼容性：
///   - 新系统返回 Task
///   - 老系统仅做异步派发，返回 nil
@discardableResult
@inline(__always)
public func onMainTask<Object: AnyObject>(
    _ object: Object?,
    _ block: @MainActor @escaping (Object) -> Void) -> Task<Void, Never>? {
    guard let object else { return nil }
    if #available(iOS 13.0, tvOS 13.0, macOS 10.15, *) {
        return Task { @MainActor [weak object] in
            guard let object else { return }
            block(object)
        }
    } else {
        DispatchQueue.main.async { [weak object] in
            guard let object else { return }
            block(object)
        };return nil
    }
}
#endif
// MARK: - Observe AsyncSequence on MainActor
#if compiler(>=5.5)

/// 在 MainActor 上消费一个 AsyncSequence，并返回可取消任务。
///
/// - 适用场景：
///   - UI 层观察异步流
///   - 确保每次回调都发生在 MainActor
///
/// - 注意：
///   - 这是长期任务，调用方通常应该持有返回的 Task
///   - 在适当时机 cancel，例如 viewDidDisappear / 生命周期收尾阶段
///   - 该版本会吞掉 sequence 抛出的错误，以维持 `Task<Void, Never>` 语义
///   - 若业务需要感知错误，请使用下方 `observeOnMainThrowing`
@available(iOS 13.0, tvOS 13.0, macOS 10.15, *)
@discardableResult
@inline(__always)
public func observeOnMain<S: AsyncSequence>(
    _ sequence: S,
    _ handler: @MainActor @escaping (S.Element) -> Void) -> Task<Void, Never> {
    Task { @MainActor in
        do {
            for try await value in sequence {
                handler(value)
            }
        } catch {
            // 保持 Never 失败语义：吞掉 sequence 抛出的错误
        }
    }
}
/// object 版本：在 MainActor 上观察 AsyncSequence，并弱持有 object。
///
/// - 语义：
///   - object 不会被强持有
///   - 每次消费到新元素时，都会检查 object 是否仍然存活
///   - 一旦 object 已释放，任务立即停止处理并返回
///
/// - 适用场景：
///   - UIViewController / ViewModel / Coordinator 生命周期绑定观察
///
/// - 重要说明：
///   - 这里不要在 Task 刚开始时先 `guard let object` 一次，
///     否则后续循环里 object 会变成非 Optional 常量，
///     再次 `guard let object` 会直接编译报错。
///   - 正确做法是：每次消费到 value 时重新检查弱引用。
///
/// - 错误策略：
///   - 该版本会吞掉 sequence 抛出的错误，以维持 `Task<Void, Never>` 语义
///   - 若业务需要感知错误，请使用下方 `observeOnMainThrowing`
@available(iOS 13.0, tvOS 13.0, macOS 10.15, *)
@discardableResult
@inline(__always)
public func observeOnMain<Object: AnyObject, S: AsyncSequence>(
    _ object: Object?,
    sequence: S,
    _ handler: @MainActor @escaping (Object, S.Element) -> Void) -> Task<Void, Never>? {
    guard object != nil else { return nil };return Task { @MainActor [weak object] in
        do {
            for try await value in sequence {
                guard let object else { return }
                handler(object, value)
            }
        } catch {
            // 保持 Never 失败语义：吞掉 sequence 抛出的错误
        }
    }
}
/// 在 MainActor 上消费一个 AsyncSequence，并把错误向上传递。
///
/// - 适用场景：
///   - 调用方需要感知 sequence 抛出的错误
///   - 不希望静默吞错
///
/// - 错误来源：
///   - sequence 本身抛错
///   - handler 内部主动抛错
///
/// - 返回值：
///   - `Task<Void, Error>`
///   - 调用方可通过 `try await task.value` 感知结果
@available(iOS 13.0, tvOS 13.0, macOS 10.15, *)
@discardableResult
@inline(__always)
public func observeOnMainThrowing<S: AsyncSequence>(
    _ sequence: S,
    _ handler: @MainActor @escaping (S.Element) throws -> Void) -> Task<Void, Error> {
    Task { @MainActor in
        for try await value in sequence {
            try handler(value)
        }
    }
}

/// object 版本：在 MainActor 上观察 AsyncSequence，并把错误向上传递。
///
/// - 语义：
///   - object 为 weak capture
///   - 若 object 在观察过程中释放，则任务安静结束，不把“对象释放”视为错误
///   - 若 sequence 抛错或 handler 抛错，则任务失败并向上传递 Error
@available(iOS 13.0, tvOS 13.0, macOS 10.15, *)
@discardableResult
@inline(__always)
public func observeOnMainThrowing<Object: AnyObject, S: AsyncSequence>(
    _ object: Object?,
    sequence: S,
    _ handler: @MainActor @escaping (Object, S.Element) throws -> Void) -> Task<Void, Error>? {
    guard object != nil else { return nil };return Task { @MainActor [weak object] in
        for try await value in sequence {
            guard let object else { return }
            try handler(object, value)
        }
    }
}
#endif
// MARK: - 使用建议（强烈建议团队遵守）
/**
 推荐使用规则：

 --------------------------------------------------
 1. UI 更新 / 回调切回主线程
 --------------------------------------------------
 用：
     onMainAsync { ... }

 示例：
     onMainAsync {
         self.tableView.reloadData()
     }

 --------------------------------------------------
 2. 若当前已在主线程就立刻执行，否则异步派发
 --------------------------------------------------
 用：
     onMainImmediateOrAsync { ... }

 示例：
     onMainImmediateOrAsync {
         self.setNeedsLayout()
     }

 --------------------------------------------------
 3. 若团队希望 object 版本“始终弱化”
 --------------------------------------------------
 用：
     onMainImmediateOrAsyncWeak(self) { object in
         object.render()
     }

 --------------------------------------------------
 4. 必须在当前返回前完成
 --------------------------------------------------
 用：
     onMainSync { ... }

 示例：
     onMainSync {
         cleanupNow()
     }

 --------------------------------------------------
 5. 需要可取消的主线程异步任务
 --------------------------------------------------
 用：
     onMainTask { ... }

 示例：
     self.renderTask = onMainTask { [weak self] in
         guard let self else { return }
         await self.renderAsync()
     }

 --------------------------------------------------
 6. UI 层观察 AsyncSequence
 --------------------------------------------------
 默认吞错：
     observeOnMain(...)

 需要向上传递错误：
     observeOnMainThrowing(...)

 示例：
     self.observeTask = observeOnMain(manager.statusChanges()) { [weak self] change in
         self?.handle(change)
     }

 --------------------------------------------------
 7. deinit 规则
 --------------------------------------------------
 - 禁止：
     onMainAsync { ... }
     DispatchQueue.main.async { ... }
     Task { @MainActor in ... }

 - 原因：
   deinit 返回后，对象可能已经析构完成；
   若清理依赖 self，异步派发到未来通常是不可靠的。

 - 若确实必须在 deinit 中做主线程清理：
     只能考虑同步路径，例如 onMainSync { ... }
   但依然要警惕死锁风险。

 --------------------------------------------------
 8. 关于 weak object 版本
 --------------------------------------------------
 所有 object 版本都明确表示：
 - object 不会被强持有到未来
 - 若执行时 object 已释放，则 block / handler 不会执行
 - 这是特性，不是 bug

 --------------------------------------------------
 9. 关于 MainActor 与主线程的选择
 --------------------------------------------------
 - 若你主要在 UIKit / AppKit 场景工作，且需求是“把事放到主线程”，
   `onMainAsync` / `onMainImmediateOrAsync` / `onMainSync` 已足够清晰。

 - 若你在更强的 Swift Concurrency 风格项目中工作，
   更应优先使用带 `@MainActor` 的 API，
   并把 `Thread.isMainThread` 视为线程层面的工具，而不是 actor 隔离证明。
 */
