//
//  UITableViewCell+数据渲染.swift
//  JobsByUIKit
//
//  Created by Jobs on 2026年5月13日，星期三.
//

#if os(OSX)
import AppKit
#elseif os(iOS) || os(tvOS)
import UIKit
#endif

import JobsSwiftDSL
import JobsSwiftBaseDefines

@MainActor
public extension ViewDataProtocol where Self: UITableViewCell {
    @discardableResult
    func byData(_ any: Any?) -> Self {
        guard let cfg = any as? JobsBaseCellConfig else { return self }
        if #available(iOS 14.0, *) {
            return self
                .byJobsText(cfg.title)
                .bySecondaryJobsText(cfg.detail)
                .byImage(cfg.image)
        } else {
            if let title = cfg.title { textLabel?.byJobsAttributedText(title) }
            if let detail = cfg.detail { detailTextLabel?.byJobsAttributedText(detail) }
            if let image = cfg.image { imageView?.byImage(image) };return self
        }
    }
}
