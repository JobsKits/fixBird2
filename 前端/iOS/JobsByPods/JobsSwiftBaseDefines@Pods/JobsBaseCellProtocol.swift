//
//  JobsBaseCellProtocol.swift
//  JobsSwiftBaseDefines
//
//  Created by Jobs on 2026年5月13日，星期三.
//

#if os(OSX)
import AppKit
#elseif os(iOS) || os(tvOS)
import UIKit
#endif

// MARK: - UITableViewCell Height Protocol
public protocol UITableViewCellProtocol: ViewDataProtocol where Self: UITableViewCell {
    /// 数据定UITableViewCell的高
    static func cellHeightByData(_ data: Any?) -> CGFloat
}
// MARK: - UICollectionViewCell Size Protocol
public protocol UICollectionViewCellProtocol : ViewDataProtocol where Self: UICollectionViewCell {
    /// 数据定UICollectionViewCell的尺寸
    static func cellSizeByData(_ data: Any?) -> CGSize
}
/// UITableViewCellProtocol@默认空实现
public extension UITableViewCellProtocol {
    static func cellHeightByData(_ data: Any?) -> CGFloat {0}
}
/// UICollectionViewCellProtocol@默认空实现
public extension UICollectionViewCellProtocol {
    static func cellSizeByData(_ data: Any?) -> CGSize {CGSizeZero}
}
// MARK: - 在不修改外界 UITableViewCell 的正常调用的情况下，使得 UITableViewCell 和 UITableView 之间存在距离（系统默认是 UITableView 的宽度 == UITableViewCell 宽度）
public protocol UITableViewCellInsetProtocol: AnyObject {
    /// 四边缩进（支持上下左右）
    var contentInsets: UIEdgeInsets { get }
    /// 是否也缩进 separator（可选）
    var shouldInsetSeparator: Bool { get }
    /// 执行缩进（建议在 layoutSubviews 里调用）
    func applyInsets()
}

public extension UITableViewCellInsetProtocol where Self: UITableViewCell {
    var contentInsets: UIEdgeInsets { .init(top: 8, left: 16, bottom: 8, right: 16) }
    var shouldInsetSeparator: Bool { true }

    func applyInsets() {
        // ⚠️ 必须保证这是在 super.layoutSubviews() 之后调用
        // 因为系统会先计算 contentView.frame（包含 accessory/editing/indentation 的影响）
        let inset = contentInsets
        // 以系统给的 contentView.frame 为基准，每次重新计算，避免叠加
        var f = contentView.frame
        // 上下左右都支持
        f.origin.x += inset.left
        f.origin.y += inset.top
        f.size.width -= (inset.left + inset.right)
        f.size.height -= (inset.top + inset.bottom)
        // 防御：避免出现负数（例如极端小高度、或外界错误 insets）
        if f.size.width < 0 { f.size.width = 0 }
        if f.size.height < 0 { f.size.height = 0 }
        contentView.frame = f
        // layoutMargins 同步（可选，主要影响 cell 内部系统控件/constraints 的默认边距）
        contentView.layoutMargins = UIEdgeInsets(
            top: contentView.layoutMargins.top,
            left: inset.left,
            bottom: contentView.layoutMargins.bottom,
            right: inset.right
        )
        // separator 跟随 contentView 的左右边缘（更稳：不直接用 inset.left/right）
        if shouldInsetSeparator {
            let left = contentView.frame.minX
            let right = bounds.width - contentView.frame.maxX
            separatorInset = UIEdgeInsets(top: 0, left: left, bottom: 0, right: right)
            preservesSuperviewLayoutMargins = false
        }
        // 如果你用了 selectedBackgroundView / backgroundView 想和 contentView 一样“缩进去”
        // 也可以选择同步它们（看你需求；默认不动）
        if let bg = backgroundView {
            bg.frame = contentView.frame
        }
        if let sbg = selectedBackgroundView {
            sbg.frame = contentView.frame
        }
    }
}
// MARK: - 每个 UITableViewCell 都切圆角
public protocol UITableViewCellRoundable: AnyObject {
    var cornerRadius: CGFloat { get }
    func applyCornerStyle()
}

public extension UITableViewCellRoundable where Self: UITableViewCell {
    var cornerRadius: CGFloat { 8 }
    func applyCornerStyle() {
        // 如果你的内容都在 contentView 上：直接圆角 contentView
        contentView.layer.cornerRadius = cornerRadius
        contentView.layer.masksToBounds = true
        // 选中/高亮的圆角也要一致（重要）
        if selectedBackgroundView == nil {
            let v = UIView()
            v.layer.cornerRadius = cornerRadius
            v.layer.masksToBounds = true
            selectedBackgroundView = v
        } else {
            selectedBackgroundView?.layer.cornerRadius = cornerRadius
            selectedBackgroundView?.layer.masksToBounds = true
        }
        // 如果不想要系统分割线穿过圆角，通常要关掉 separator 或自己画
        // separatorInset = UIEdgeInsets(top: 0, left: 9999, bottom: 0, right: 0)
    }
}
// MARK: - UITableView的每一个Section的第一个Cell的左上角和右上角切圆角（默认8），每一个Section的最后一个Cell的左下角和右下角切圆角（默认8）
public enum SectionCellPosition {
    case single   // 该 section 只有 1 行：四个角都圆
    case first    // section 第一行：只圆上边两个角
    case middle   // 中间行：不圆角
    case last     // section 最后一行：只圆下边两个角
}

public protocol SectionCornerRoundable: AnyObject {
    var sectionCornerRadius: CGFloat { get }
    func applySectionCorners(_ position: SectionCellPosition)
}

extension SectionCornerRoundable where Self: UITableViewCell {
    public var sectionCornerRadius: CGFloat { 8 }
    public func applySectionCorners(_ position: SectionCellPosition) {
        // 先重置（避免复用残留）
        contentView.layer.cornerRadius = 0
        contentView.layer.maskedCorners = []
        contentView.layer.masksToBounds = true
        // 选中态也同步（不然选中时会变方）
        if selectedBackgroundView == nil {
            selectedBackgroundView = UIView()
        }
        selectedBackgroundView?.layer.cornerRadius = 0
        selectedBackgroundView?.layer.maskedCorners = []
        selectedBackgroundView?.layer.masksToBounds = true
        // 再按位置设置
        let radius = sectionCornerRadius
        switch position {
        /// 处理 .single 分支
        case .single:
            contentView.layer.cornerRadius = radius
            contentView.layer.maskedCorners = [
                .layerMinXMinYCorner, .layerMaxXMinYCorner,
                .layerMinXMaxYCorner, .layerMaxXMaxYCorner
            ]
            selectedBackgroundView?.layer.cornerRadius = radius
            selectedBackgroundView?.layer.maskedCorners = contentView.layer.maskedCorners
        /// 处理 .first 分支
        case .first:
            contentView.layer.cornerRadius = radius
            contentView.layer.maskedCorners = [
                .layerMinXMinYCorner, .layerMaxXMinYCorner
            ]
            selectedBackgroundView?.layer.cornerRadius = radius
            selectedBackgroundView?.layer.maskedCorners = contentView.layer.maskedCorners
        /// 处理 .last 分支
        case .last:
            contentView.layer.cornerRadius = radius
            contentView.layer.maskedCorners = [
                .layerMinXMaxYCorner, .layerMaxXMaxYCorner
            ]
            selectedBackgroundView?.layer.cornerRadius = radius
            selectedBackgroundView?.layer.maskedCorners = contentView.layer.maskedCorners
        /// 处理 .middle 分支
        case .middle:
            // 保持重置后的状态：无圆角
            break
        }
    }
}
