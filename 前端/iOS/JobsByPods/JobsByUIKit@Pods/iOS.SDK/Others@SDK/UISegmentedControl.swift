//
//  UISegmentedControl.swift
//  JobsByUIKit
//
//  Created by Jobs on 2026年5月13日，星期三.
//

#if os(OSX)
import AppKit
#elseif os(iOS) || os(tvOS)
import UIKit
#endif

extension UISegmentedControl {
    @discardableResult
    public func bySelectedSegmentIndex(_ index: Int) -> Self {
        self.selectedSegmentIndex = index
        return self
    }

    @discardableResult
    public func byTitle(_ title: String, forSegmentAt index: Int) -> Self {
        self.setTitle(title, forSegmentAt: index)
        return self
    }

    @discardableResult
    public func byTitleTextAttributes(_ attributes: [NSAttributedString.Key: Any], for state: UIControl.State) -> Self {
        self.setTitleTextAttributes(attributes, for: state)
        return self
    }

    @discardableResult
    public func insertSegmentByAnimated(withTitle title: String, at index: Int) -> Self {
        self.insertSegment(withTitle: title, at: index, animated: true)
        return self
    }

    @discardableResult
    public func insertSegment(withTitle title: String, at index: Int) -> Self {
        self.insertSegment(withTitle: title, at: index, animated: false)
        return self
    }

    @discardableResult
    public func removeSegmentByAnimated(at index: Int) -> Self {
        self.removeSegment(at: index, animated: true)
        return self
    }

    @discardableResult
    public func removeSegment(at index: Int) -> Self {
        self.removeSegment(at: index, animated: false)
        return self
    }
}
