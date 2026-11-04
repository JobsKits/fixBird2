//
//  CATextLayer.swift
//  JobsByQuartzCore
//
//  Created by Jobs on 2026年5月13日，星期三.
//

#if os(OSX)
import AppKit
#elseif os(iOS) || os(tvOS)
import UIKit
#endif

import QuartzCore
import CoreGraphics

extension CATextLayer {
    @discardableResult
    public func byString(_ value: Any?) -> Self {
        self.string = value
        return self
    }

    @discardableResult
    public func byFont(_ value: CFTypeRef?) -> Self {
        self.font = value
        return self
    }
    /// 可选：UIFont 便捷入口（同时同步 fontSize）
    @discardableResult
    public func byUIFont(_ value: UIFont) -> Self {
        self.font = value
        self.fontSize = value.pointSize
        return self
    }

    @discardableResult
    public func byFontSize(_ value: CGFloat) -> Self {
        self.fontSize = value
        return self
    }

    @discardableResult
    public func byForegroundColor(_ value: CGColor?) -> Self {
        self.foregroundColor = value
        return self
    }

    @discardableResult
    public func byWrapped(_ value: Bool) -> Self {
        self.isWrapped = value
        return self
    }

    @discardableResult
    public func byTruncationMode(_ value: CATextLayerTruncationMode) -> Self {
        self.truncationMode = value
        return self
    }

    @discardableResult
    public func byAlignmentMode(_ value: CATextLayerAlignmentMode) -> Self {
        self.alignmentMode = value
        return self
    }

    @discardableResult
    public func byAllowsFontSubpixelQuantization(_ value: Bool) -> Self {
        self.allowsFontSubpixelQuantization = value
        return self
    }
}
