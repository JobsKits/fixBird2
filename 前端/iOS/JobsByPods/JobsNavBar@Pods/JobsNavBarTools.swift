//
//  JobsNavBarTools.swift
//  JobsNavBar
//
//  Created by Jobs on 2026年5月13日，星期三.
//

#if os(OSX)
import AppKit
#elseif os(iOS) || os(tvOS)
import UIKit
#endif

import SwiftMessages
import JobsSwiftDSL

public enum JobsSwiftMessageToast {
    @MainActor public static func show(
        _ text: String,
        duration: TimeInterval = 1.0
    ) {
        let view = MessageView.viewFromNib(layout: .messageView)
        view.configureTheme(.info)
        view.configureDropShadow()
        view.button?.byHidden(true)
        // 标题可留空，只用 body
        view.configureContent(title: "", body: text)
        var config = SwiftMessages.Config()
        config.presentationStyle = .top // 或 .bottom
        config.presentationContext = .window(windowLevel: .statusBar)
        config.duration = .seconds(seconds: duration)
        config.interactiveHide = false
        config.dimMode = .none
        SwiftMessages.show(config: config, view: view)
    }
}
