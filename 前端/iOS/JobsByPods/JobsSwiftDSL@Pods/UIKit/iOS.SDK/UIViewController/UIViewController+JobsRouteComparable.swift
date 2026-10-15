//
//  UIViewController+JobsRouteComparable.swift
//  JobsSwiftDSL
//
//  Created by Jobs on 2026年6月24日，星期三.
//

#if os(OSX)
import AppKit
#elseif os(iOS) || os(tvOS)
import UIKit
#endif

import JobsSwiftBaseDefines

extension UIViewController: @retroactive JobsRouteComparable {
    @inline(__always)
    public func jobs_isSameDestination(as other: UIViewController) -> Bool {
        type(of: self) == type(of: other)
    }
}
