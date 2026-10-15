//
//  Optional.swift
//  JobsSwiftStandardLibrary
//
//  Created by Jobs on 2026年5月13日，星期三.
//

#if os(OSX)
import AppKit
#elseif os(iOS) || os(tvOS)
import UIKit
#endif

import CoreGraphics

#if canImport(JobsSwiftBaseDefines)
import JobsSwiftBaseDefines
#endif

// MARK: - 标准库：纯值与集合
extension String: @retroactive SafeUnwrappedInitializable {}
extension Bool: @retroactive SafeUnwrappedInitializable {}

extension Int: @retroactive SafeUnwrappedInitializable {}
extension Int8: @retroactive SafeUnwrappedInitializable {}
extension Int16: @retroactive SafeUnwrappedInitializable {}
extension Int32: @retroactive SafeUnwrappedInitializable {}
extension Int64: @retroactive SafeUnwrappedInitializable {}

extension UInt: @retroactive SafeUnwrappedInitializable {}
extension UInt8: @retroactive SafeUnwrappedInitializable {}
extension UInt16: @retroactive SafeUnwrappedInitializable {}
extension UInt32: @retroactive SafeUnwrappedInitializable {}
extension UInt64: @retroactive SafeUnwrappedInitializable {}

extension Double: @retroactive SafeUnwrappedInitializable {}
extension Float: @retroactive SafeUnwrappedInitializable {}

extension Array: @retroactive SafeUnwrappedInitializable {}
extension Dictionary: @retroactive SafeUnwrappedInitializable {}
extension Set: @retroactive SafeUnwrappedInitializable {}
// MARK: - CoreGraphics 结构体
extension CGPoint: @retroactive SafeUnwrappedInitializable {}
extension CGSize: @retroactive SafeUnwrappedInitializable {}
extension CGRect: @retroactive SafeUnwrappedInitializable {}
extension CGVector: @retroactive SafeUnwrappedInitializable {}
extension CGAffineTransform: @retroactive SafeUnwrappedInitializable {}
// MARK: - UIKit/SwiftUI 常用结构体（非 UI 类）
extension UIEdgeInsets: @retroactive SafeUnwrappedInitializable {}
extension UIOffset: @retroactive SafeUnwrappedInitializable {}
@available(iOS 11.0, *)
extension NSDirectionalEdgeInsets: @retroactive SafeUnwrappedInitializable {}
// MARK: - Foundation 常用值类型
extension Data: @retroactive SafeUnwrappedInitializable {}
extension Date: @retroactive SafeUnwrappedInitializable {}
extension Decimal: @retroactive SafeUnwrappedInitializable {}
extension DateComponents: @retroactive SafeUnwrappedInitializable {
    public init() {
        self.init(calendar: nil,
                  timeZone: nil,
                  era: nil,
                  year: nil,
                  month: nil,
                  day: nil,
                  hour: nil,
                  minute: nil,
                  second: nil,
                  nanosecond: nil,
                  weekday: nil,
                  weekdayOrdinal: nil,
                  quarter: nil,
                  weekOfMonth: nil,
                  weekOfYear: nil,
                  yearForWeekOfYear: nil)
    }
}
extension IndexSet: @retroactive SafeUnwrappedInitializable {}
extension CharacterSet: @retroactive SafeUnwrappedInitializable {}
// 如需：NSAttributedString/AttributedString 也可打开（它们有空 init）
extension NSAttributedString: @retroactive SafeUnwrappedInitializable {}
@available(iOS 15.0, *)
extension AttributedString: @retroactive SafeUnwrappedInitializable {}
// MARK: - 通用 safelyUnwrapped：给“允许兜底构造”的类型使用
extension Optional where Wrapped: SafeUnwrappedInitializable {
    public func safelyUnwrapped(_ defaultValue: Wrapped? = nil) -> Wrapped {
        self ?? (defaultValue ?? Wrapped())
    }
}
// MARK: - UI 类禁用（编译期直接报错；与上面通用版互不影响）
extension UIViewController: @retroactive _UISafeUnwrappedBan {}
extension UIView: @retroactive _UISafeUnwrappedBan {}
extension UIImage: @retroactive _UISafeUnwrappedBan {}
extension UIColor: @retroactive _UISafeUnwrappedBan {}
extension Optional where Wrapped: _UISafeUnwrappedBan {
    @available(*, unavailable, message: "🚫 UI 类型禁止使用 safelyUnwrapped()，请显式处理 nil 或提供业务兜底。")
    public func safelyUnwrapped(_ defaultValue: Wrapped? = nil) -> Wrapped { fatalError() }
}
