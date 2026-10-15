//
//  UIPopoverPresentationController.swift
//  JobsByUIKit
//
//  Created by Jobs on 2026年5月13日，星期三.
//

#if os(OSX)
import AppKit
#elseif os(iOS) || os(tvOS)
import UIKit
#endif

extension UIPopoverPresentationController {
    @discardableResult
    public func bySourceView(_ view: UIView?) -> Self {
        self.sourceView = view
        return self
    }

    @discardableResult
    public func bySourceRect(_ rect: CGRect) -> Self {
        self.sourceRect = rect
        return self
    }

    @discardableResult
    public func byPermittedArrowDirections(_ directions: UIPopoverArrowDirection) -> Self {
        self.permittedArrowDirections = directions
        return self
    }

    @discardableResult
    public func byDelegate(_ delegate: UIPopoverPresentationControllerDelegate?) -> Self {
        self.delegate = delegate
        return self
    }
}
