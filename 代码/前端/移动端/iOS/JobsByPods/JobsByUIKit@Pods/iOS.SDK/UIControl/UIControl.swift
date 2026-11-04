//
//  UIControl.swift
//  JobsByUIKit
//
//  Created by Jobs on 2026年5月13日，星期三.
//

#if os(OSX)
import AppKit
#elseif os(iOS) || os(tvOS)
import UIKit
#endif

import JobsSwiftBlock

public final class _JobsClosureWrapper: NSObject {
    private let closure: jobsByVoidBlock

    init(_ closure: @escaping jobsByVoidBlock) {
        self.closure = closure
    }

    @objc func invoke() {
        closure()
    }
}
