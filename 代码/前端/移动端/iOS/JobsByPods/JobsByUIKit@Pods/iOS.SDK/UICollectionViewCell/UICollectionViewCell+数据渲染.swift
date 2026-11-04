//
//  UICollectionViewCell+数据渲染.swift
//  JobsByUIKit
//
//  Created by Jobs on 2026年5月13日，星期三.
//

#if os(OSX)
import AppKit
#elseif os(iOS) || os(tvOS)
import UIKit
#endif

import JobsSwiftBaseDefines

@MainActor
public extension ViewDataProtocol where Self: UICollectionViewCell {
    @discardableResult
    func byData(_ any: Any?) -> Self { self }
}
