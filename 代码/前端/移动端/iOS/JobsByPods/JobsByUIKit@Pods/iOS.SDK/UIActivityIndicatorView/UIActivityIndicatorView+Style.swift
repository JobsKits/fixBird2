//
//  UIActivityIndicatorView+Style.swift
//  JobsByUIKit
//
//  Created by Jobs on 2026年5月13日，星期三.
//

#if os(OSX)
import AppKit
#elseif os(iOS) || os(tvOS)
import UIKit
#endif

public enum JobsIndicatorStyle {
    case medium
    case large

    var uiStyle: UIActivityIndicatorView.Style {
        switch self {
        /// 处理 .medium 分支
        case .medium:
            if #available(iOS 13.0, *) { return .medium };return .gray
        /// 处理 .large 分支
        case .large:
            if #available(iOS 13.0, *) { return .large };return .whiteLarge
        }
    }
}

public extension UIActivityIndicatorView {
    convenience init(jobsStyle: JobsIndicatorStyle) {
        self.init(style: jobsStyle.uiStyle)
    }
}
