//
//  UIAction.swift
//  JobsByUIKit
//
//  Created by Jobs on 2026年7月10日，星期五.
//

#if os(OSX)
import AppKit
#elseif os(iOS) || os(tvOS)
import UIKit
#endif

@available(iOS 13.0, tvOS 13.0, *)
public extension UIAction {
    static func make(
        title: String,
        image: UIImage? = nil,
        identifier: UIAction.Identifier? = nil,
        discoverabilityTitle: String? = nil,
        attributes: UIMenuElement.Attributes = [],
        state: UIMenuElement.State = .off,
        handler: @escaping UIActionHandler
    ) -> UIAction {
        UIAction(
            title: title,
            image: image,
            identifier: identifier,
            discoverabilityTitle: discoverabilityTitle,
            attributes: attributes,
            state: state,
            handler: handler
        )
    }
}
