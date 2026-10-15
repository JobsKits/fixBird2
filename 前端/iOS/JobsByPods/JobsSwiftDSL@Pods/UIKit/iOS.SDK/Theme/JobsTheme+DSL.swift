//
//  JobsTheme+DSL.swift
//  JobsSwiftDSL
//
//  Created by Jobs on 2026年7月29日，星期三.
//

#if os(iOS) || os(tvOS)
import UIKit
import JobsSwiftBaseDefines

public extension UIView {
    @discardableResult
    func byThemeBackground(_ key: JobsThemeColorKey) -> Self {
        byBackgroundColor(JobsThemeCenter.shared.color(key))
    }
}

public extension UILabel {
    @discardableResult
    func byThemeTextColor(_ key: JobsThemeColorKey) -> Self {
        byTextColor(JobsThemeCenter.shared.color(key))
    }
}

public extension UITextField {
    @discardableResult
    func byThemeTextColor(_ key: JobsThemeColorKey) -> Self {
        byTextColor(JobsThemeCenter.shared.color(key))
    }
}

public extension UITextView {
    @discardableResult
    func byThemeTextColor(_ key: JobsThemeColorKey) -> Self {
        byTextColor(JobsThemeCenter.shared.color(key))
    }
}

public extension UIButton {
    @discardableResult
    func byThemeTitleColor(_ key: JobsThemeColorKey,
                           for state: UIControl.State = .normal) -> Self {
        byTitleColor(JobsThemeCenter.shared.color(key), for: state)
    }

    @discardableResult
    func byThemeImage(_ key: JobsThemeImageKey,
                      for state: UIControl.State = .normal) -> Self {
        byImage(JobsThemeCenter.shared.image(key), for: state)
    }

    @discardableResult
    func byThemeBackgroundImage(_ key: JobsThemeImageKey,
                                for state: UIControl.State = .normal) -> Self {
        byBackgroundImage(JobsThemeCenter.shared.image(key), for: state)
    }
}

public extension UIImageView {
    @discardableResult
    func byThemeImage(_ key: JobsThemeImageKey) -> Self {
        byImage(JobsThemeCenter.shared.image(key))
    }
}
#endif
