//
//  SnapKitBaseModel.swift
//  JobsSwiftBaseDefines
//
//  Created by Jobs on 2026年5月13日，星期三.
//

#if os(OSX)
import AppKit
#elseif os(iOS) || os(tvOS)
import UIKit
#endif

public enum SnapAxis {
    case horizontal
    case vertical
}

public struct SnapDistributeModel {
    /// 分布方向：横向一排 / 纵向一列
    public var axis: SnapAxis = .horizontal
    /// 沿 axis 方向的固定长度
    /// - horizontal: 固定每个 item 的宽度
    /// - vertical:   固定每个 item 的高度
    /// - nil:        不固定，改为“均分”（每个 item 长度相等）
    public var fixedItemLength: CGFloat? = nil
    /// 头部间距（第一个 item 到容器边的距离）
    /// - horizontal: 左边距
    /// - vertical:   上边距
    public var leadSpacing: CGFloat = 0
    /// 尾部间距（最后一个 item 到容器边的距离）
    /// - horizontal: 右边距
    /// - vertical:   下边距
    public var tailSpacing: CGFloat = 0
    /// 是否顺便给“容器本身”加约束（通常不需要，容器约束由外部控制更清晰）
    public var makeContainerConstraints: Bool = false
    /// 交叉方向的上边距
    /// - horizontal: item 的 top inset（常用）
    /// - vertical:   一般不用（vertical 通常用 left/right）
    public var top: CGFloat? = nil
    /// 交叉方向的下边距
    /// - horizontal: item 的 bottom inset（常用）
    /// - vertical:   一般不用（vertical 通常用 left/right）
    public var bottom: CGFloat? = nil
    /// 交叉方向的左边距
    /// - vertical: item 的 left inset（常用）
    /// - horizontal: 一般不用（horizontal 通常用 top/bottom）
    public var left: CGFloat? = nil
    /// 交叉方向的右边距
    /// - vertical: item 的 right inset（常用）
    /// - horizontal: 一般不用（horizontal 通常用 top/bottom）
    public var right: CGFloat? = nil
    /// 交叉方向固定尺寸
    /// - horizontal: 固定 item 高度 height
    /// - vertical:   固定 item 宽度 width
    /// - nil:        不固定（通过 top/bottom 或 left/right 拉伸）
    public var crossSize: CGFloat? = nil

    public init(
        axis: SnapAxis = .horizontal,
        fixedItemLength: CGFloat? = nil,
        leadSpacing: CGFloat = 0,
        tailSpacing: CGFloat = 0,
        makeContainerConstraints: Bool = false,
        top: CGFloat? = nil,
        bottom: CGFloat? = nil,
        left: CGFloat? = nil,
        right: CGFloat? = nil,
        crossSize: CGFloat? = nil
    ) {
        self.axis = axis
        self.fixedItemLength = fixedItemLength
        self.leadSpacing = leadSpacing
        self.tailSpacing = tailSpacing
        self.makeContainerConstraints = makeContainerConstraints
        self.top = top
        self.bottom = bottom
        self.left = left
        self.right = right
        self.crossSize = crossSize
    }
}

