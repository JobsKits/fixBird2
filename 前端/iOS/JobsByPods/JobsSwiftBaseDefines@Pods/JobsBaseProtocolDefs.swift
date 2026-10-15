//
//  JobsBaseProtocolDefs.swift
//  JobsSwiftBaseDefines
//
//  Created by Jobs on 2026年5月13日，星期三.
//

#if os(OSX)
import AppKit
#elseif os(iOS) || os(tvOS)
import UIKit
#endif

// MARK: - 查找当前对象所在的控制器
public protocol ViewControllerFindable {}
public protocol _UISafeUnwrappedBan {}     // 标记“UI 禁用默认兜底”
// MARK: - 安全解包 Optional
public protocol SafeUnwrappedInitializable { init() }
// MARK: - 路由目的地等价（避免重名-前缀化）
/// 默认“同类型 = 同目的地”。需要区分同类不同参数时，在目标 VC 里 override `jobs_isSameDestination(as:)`
public protocol JobsRouteComparable {
    func jobs_isSameDestination(as other: UIViewController) -> Bool
}
public extension UIAccessibilityIdentification where Self: AnyObject {
    /// 链式设置 `accessibilityIdentifier`
    @MainActor
    @discardableResult
    func byAccessibilityIdentifier(_ id: String?) -> Self {
        self.accessibilityIdentifier = id
        return self
    }
}

@available(iOS 10.0, *)
public extension UIContentSizeCategoryAdjusting where Self: AnyObject {
    /// 开/关 Dynamic Type 自动缩放（默认开），返回 Self 以便链式调用
    @discardableResult
    func byAdjustsFontForContentSizeCategory(_ flag: Bool = true) -> Self {
        self.adjustsFontForContentSizeCategory = flag
        return self
    }
}
// MARK: - 延迟执行
public protocol JobsAsyncable: AnyObject {}
public extension JobsAsyncable {
    /// 延迟执行，自动 weak self；默认主线程
    func doAsync(
        after delay: TimeInterval = 1.0,
        on queue: DispatchQueue = .main,
        _ block: @escaping (Self) -> Void
    ) -> Void {
        queue.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self = self else { return }
            block(self)     // ✅ 此处就是 Self，无需 as! 强转
        }
    }
}
/// MARK: - 统一的「任意配置」协议（覆盖 UIView / UIViewController）
///  正向：byData（单参 + 不定参）
///  逆向：onResult + sendResult（单参 + 不定参）
@MainActor
/// ViewDataProtocol@单参数
public protocol ViewDataProtocol: AnyObject {
    /// 正向@入参
    @discardableResult
    func byData(_ data: Any?) -> Self
    /// 逆向@入参
    func sendResult(_ data: Any?)
    /// 逆向@出参
    @discardableResult
    func onResult(_ callback: @escaping (Any?) -> Void) -> Self
}
/// ViewDataProtocol@不定参数
public extension ViewDataProtocol {
    /// 正向@入参
    @_disfavoredOverload
    @discardableResult
    func byData(_ items: Any?...) -> Self {
        items.count == 1 ? byData(items[0]) : byData(items)
    }
    /// 逆向@入参
    @_disfavoredOverload
    func sendResult(_ items: Any?...) {
        if items.count == 1 { sendResult(items[0]) }
        else { sendResult(items) }
    }
    /// 逆向@出参
    @_disfavoredOverload
    @discardableResult
    func onResult(_ callback: @escaping ([Any?]) -> Void) -> Self {
        onResult { payload in
            if let arr = payload as? [Any?] {
                callback(arr)
            } else {
                callback([payload])
            }
        }
    }
}
/// ViewDataProtocol@默认空实现
public extension ViewDataProtocol {
    /// 正向@入参
    @discardableResult
    func byData(_ data: Any?) -> Self { self }
    /// 逆向@入参
    func sendResult(_ data: Any?) {}
    /// 逆向@出参
    @discardableResult
    func onResult(_ callback: @escaping (Any?) -> Void) -> Self { self }
}

public extension ViewDataProtocol {
    /// 逆向@无（入）参数；便捷重载，等价于“发一个nil”
    func sendResult() {
        sendResult(nil as Any?)
    }
}
