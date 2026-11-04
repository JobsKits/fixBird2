//
//  JobsBaseStructDefs.swift
//  JobsSwiftBaseDefines
//
//  Created by Jobs on 2026年5月13日，星期三.
//

#if os(OSX)
import AppKit
#elseif os(iOS) || os(tvOS)
import UIKit
#endif

public struct FramePatch {
    public var x: CGFloat?
    public var y: CGFloat?
    public var width: CGFloat?
    public var height: CGFloat?

    public init(x: CGFloat? = nil,
                y: CGFloat? = nil,
                width: CGFloat? = nil,
                height: CGFloat? = nil) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}
// MARK: - ShadowDirection
public struct ShadowDirection: OptionSet {
    public let rawValue: UInt
    public static let top        = ShadowDirection([])
    public static let down       = ShadowDirection(rawValue: 1 << 0)
    public static let left       = ShadowDirection(rawValue: 1 << 1)
    public static let right      = ShadowDirection(rawValue: 1 << 2)
    public static let leftTop    = ShadowDirection(rawValue: 1 << 3)
    public static let leftDown   = ShadowDirection(rawValue: 1 << 4)
    public static let rightTop   = ShadowDirection(rawValue: 1 << 5)
    public static let rightDown  = ShadowDirection(rawValue: 1 << 6)
    public static let all: ShadowDirection = [.top, .down, .left, .right, .leftTop, .leftDown, .rightTop, .rightDown]

    public init(rawValue: UInt) {
        self.rawValue = rawValue
    }
}
// MARK: - UIBorderSideType
public struct UIBorderSideType: OptionSet {
    public let rawValue: UInt
    public static let all    = UIBorderSideType([])
    public static let top    = UIBorderSideType(rawValue: 1 << 0)
    public static let bottom = UIBorderSideType(rawValue: 1 << 1)
    public static let left   = UIBorderSideType(rawValue: 1 << 2)
    public static let right  = UIBorderSideType(rawValue: 1 << 3)

    public init(rawValue: UInt) {
        self.rawValue = rawValue
    }
}
// MARK: - 这样写的话，外面可以JobsIndexPath.section 进行调用
public struct JobsIndexPath {
    public var section: Int
    public var rowOrItem: Int
}
// MARK: - 无数据占位图的类型
public struct JobsEmptyViewType: OptionSet {
    public let rawValue: UInt
    public static let none       = JobsEmptyViewType([])
    public static let label      = JobsEmptyViewType(rawValue: 1 << 0)
    public static let button     = JobsEmptyViewType(rawValue: 1 << 1)
    public static let customView = JobsEmptyViewType(rawValue: 1 << 2)

    public init(rawValue: UInt) {
        self.rawValue = rawValue
    }
}
