//
//  SnapKit+DSL.swift
//  JobsBy3rdTools
//
//  Created by Jobs on 2026年5月13日，星期三.
//

#if os(OSX)
import AppKit
#elseif os(iOS) || os(tvOS)
import UIKit
#endif

import SnapKit

#if os(OSX)
public typealias MASView = NSView
public typealias MASGuide = NSLayoutGuide
#elseif os(iOS) || os(tvOS)
public typealias MASView = UIView
public typealias MASGuide = UILayoutGuide
#endif

// MARK: - View Masonry-style entry
extension MASView {
    public func mas_makeConstraints(_ closure: (ConstraintMaker) -> Void) { snp.makeConstraints(closure) }
    public func mas_updateConstraints(_ closure: (ConstraintMaker) -> Void) { snp.updateConstraints(closure) }
    public func mas_remakeConstraints(_ closure: (ConstraintMaker) -> Void) { snp.remakeConstraints(closure) }
    public func mas_removeConstraints() { snp.removeConstraints() }
    @discardableResult
    public func mas_prepareConstraints(_ closure: (ConstraintMaker) -> Void) -> [Constraint] { snp.prepareConstraints(closure) }
    #if !os(OSX)
    @available(iOS 11.0, tvOS 11.0, *)
    public var mas_safeArea: MASGuide { safeAreaLayoutGuide }
    #endif
}
// MARK: - Masonry-like aliases on SnapKit chain objects
extension ConstraintMakerExtendable {
    @discardableResult
    public func mas_equalTo(_ other: ConstraintRelatableTarget) -> ConstraintMakerEditable { equalTo(other) }
    @discardableResult
    public func mas_greaterThanOrEqualTo(_ other: ConstraintRelatableTarget) -> ConstraintMakerEditable { greaterThanOrEqualTo(other) }
    @discardableResult
    public func mas_lessThanOrEqualTo(_ other: ConstraintRelatableTarget) -> ConstraintMakerEditable { lessThanOrEqualTo(other) }
    @discardableResult
    public func mas_equalToSuperview() -> ConstraintMakerEditable { equalToSuperview() }
    @discardableResult
    public func mas_greaterThanOrEqualToSuperview() -> ConstraintMakerEditable { greaterThanOrEqualToSuperview() }
    @discardableResult
    public func mas_lessThanOrEqualToSuperview() -> ConstraintMakerEditable { lessThanOrEqualToSuperview() }
}
// MARK: - Masonry-style anchors (view.mas_left / view.mas_right ...)
extension MASView {
    public var mas_left: ConstraintItem { snp.left }
    public var mas_right: ConstraintItem { snp.right }
    public var mas_top: ConstraintItem { snp.top }
    public var mas_bottom: ConstraintItem { snp.bottom }
    public var mas_centerX: ConstraintItem { snp.centerX }
    public var mas_centerY: ConstraintItem { snp.centerY }
    public var mas_width: ConstraintItem { snp.width }
    public var mas_height: ConstraintItem { snp.height }
    public var mas_edges: ConstraintItem { snp.edges }
    public var mas_size: ConstraintItem { snp.size }
}
// MARK: - Masonry-style anchors (guide.mas_left ...) for safeArea/layoutGuide
extension MASGuide {
    public var mas_left: ConstraintItem { snp.left }
    public var mas_right: ConstraintItem { snp.right }
    public var mas_top: ConstraintItem { snp.top }
    public var mas_bottom: ConstraintItem { snp.bottom }
    public var mas_centerX: ConstraintItem { snp.centerX }
    public var mas_centerY: ConstraintItem { snp.centerY }
    public var mas_width: ConstraintItem { snp.width }
    public var mas_height: ConstraintItem { snp.height }
    public var mas_edges: ConstraintItem { snp.edges }
    public var mas_size: ConstraintItem { snp.size }
}
// MARK: - Tiny sugar (non-conflicting)
extension ConstraintMakerEditable {
    @discardableResult
    public func insets(_ amount: ConstraintInsetTarget) -> ConstraintMakerEditable { inset(amount) }
}

extension ConstraintMakerFinalizable {
    @discardableResult
    public func key(_ key: String) -> ConstraintMakerFinalizable { labeled(key) }
}
