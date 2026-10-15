//
//  Sequence.swift
//  JobsSwiftStandardLibrary
//
//  Created by Jobs on 2026年5月13日，星期三.
//

#if os(OSX)
import AppKit
#elseif os(iOS) || os(tvOS)
import UIKit
#endif

/// Sequence 协议就是 Swift 里“一串可以被遍历的东西”的最底层抽象，所有 for ... in、map、filter 这类操作，都是建立在它上面。
/// 告诉编译器：我这玩意儿可以一个一个把元素吐出来
/// 只保证“能从头到尾走一遍”，不保证能往回走、不保证能下标读、不保证能遍历第二遍

extension Sequence where Element: Comparable {
    /// 一次遍历拿到 (最小, 最大)
    public func minMax() -> (min: Element, max: Element)? {
        var iterator = makeIterator()
        guard let first = iterator.next() else { return nil }
        var minVal = first
        var maxVal = first
        while let next = iterator.next() {
            if next < minVal { minVal = next }
            if next > maxVal { maxVal = next }
        };return (min: minVal, max: maxVal)
    }
}
