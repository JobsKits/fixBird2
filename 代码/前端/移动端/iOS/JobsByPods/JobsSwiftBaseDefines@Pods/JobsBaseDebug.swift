//
//  JobsBaseDebug.swift
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

// MARK: - DEBUG 模式下才允许做的事
/// ✅ Debug 才执行：并保证在 MainActor/主线程运行（复用 onMainAsync）
/// - 全系统可用（同步闭包）
@inline(__always)
public func debugOnly(_ work: @MainActor @escaping () -> Void) {
#if DEBUG
    onMainAsync(work)
#endif
}
/// ✅ Debug 才执行：支持 async/await，并保证在 MainActor/主线程运行
/// - async/Task/MainActor hop 依赖 Concurrency runtime：iOS/tvOS 13+、macOS 10.15+
#if compiler(>=5.5)
@available(iOS 13.0, tvOS 13.0, macOS 10.15, *)
@inline(__always)
public func debugOnly(_ work: @MainActor @escaping () async -> Void) {
#if DEBUG
    onMainAsync(work)
#endif
}
#endif
/// ✅ Debug 才执行：避免直接捕获 self（object 可能为 nil 直接跳过）
/// - 全系统可用（同步闭包）
@inline(__always)
public func debugOnly<Object: AnyObject>(
    _ object: Object?,
    _ work: @MainActor @escaping (Object) -> Void
) {
#if DEBUG
    onMainAsync(object, work)
#endif
}
/// ✅ Debug 才执行：async 版本（object 可能为 nil 直接跳过）
/// - async/Task/MainActor hop 依赖 Concurrency runtime：iOS/tvOS 13+、macOS 10.15+
#if compiler(>=5.5)
@available(iOS 13.0, tvOS 13.0, macOS 10.15, *)
@inline(__always)
public func debugOnly<Object: AnyObject>(
    _ object: Object?,
    _ work: @MainActor @escaping (Object) async -> Void
) {
#if DEBUG
    onMainAsync(object, work)
#endif
}
#endif
// MARK: - 私有：蓝色占位图（1x1）
/// 统一的纯色占位（1×1）；需要更大就改 size
public func jobsSolidBlue(
    color: UIColor = JobsCor.systemBlue,
    size: CGSize = .init(width: 1, height: 1),
    scale: CGFloat = 0
) -> UIImage {
    let fmt = UIGraphicsImageRendererFormat.default()
    fmt.scale = scale
    return UIGraphicsImageRenderer(size: size, format: fmt).image { ctx in
        color.setFill()
        ctx.fill(CGRect(origin: .zero, size: size))
    }
}
