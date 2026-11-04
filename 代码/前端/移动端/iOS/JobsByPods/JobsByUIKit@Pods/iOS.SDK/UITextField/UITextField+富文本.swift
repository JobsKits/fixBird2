//
//  UITextField+富文本.swift
//  JobsByUIKit
//
//  Created by Jobs on 2026年5月13日，星期三.
//

#if os(OSX)
import AppKit
#elseif os(iOS) || os(tvOS)
import UIKit
#endif

import JobsTextTools

// MARK: - 设置富文本（UITextField）
extension UITextField {
     public func richTextBy(_ runs: [JobsRichRun], paragraphStyle: NSMutableParagraphStyle? = nil) {
        self.attributedText = JobsRichText.make(runs, paragraphStyle: paragraphStyle)
    }
}
