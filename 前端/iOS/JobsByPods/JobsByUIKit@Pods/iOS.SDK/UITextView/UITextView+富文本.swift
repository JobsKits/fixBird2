//
//  UITextView+富文本.swift
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
import JobsSwiftBaseDefines

// MARK: 设置富文本
extension UITextView {
    public func richTextBy(_ runs: [JobsRichRun], paragraphStyle: NSMutableParagraphStyle? = nil) {
        attributedText = JobsRichText.make(runs, paragraphStyle: paragraphStyle)
        isEditable = false
        isScrollEnabled = false
        dataDetectorTypes = [] // 仅走自定义 link
    }
}
/**
 
     let ps = jobsMakeParagraphStyle {
         $0.alignment = .center
         $0.lineSpacing = 4
     }

     let runs: [JobsRichRun] = [
         JobsRichRun(.text("如需帮助，请联系 "))
             .font(JobsFont.systemFont(ofSize: 15))
             .color(JobsCor.secondaryLabel),

         JobsRichRun(.text("专属客服"))
             .font(JobsFont.systemFont(ofSize: 15))
             .color(JobsCor.systemBlue)
             .link("click://customer")
     ]
 */
