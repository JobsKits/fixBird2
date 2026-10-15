//
//  NSMutableAttributedString.swift
//  JobsSwiftFoundation
//
//  Created by Jobs on 2026年5月13日，星期三.
//

#if os(OSX)
import AppKit
#elseif os(iOS) || os(tvOS)
import UIKit
#endif

extension NSMutableAttributedString {
    // MARK: - 添加单个属性
    @discardableResult
    public func byAddAttribute(_ name: NSAttributedString.Key, value: Any, range: NSRange? = nil) -> Self {
        if let range = range {
            self.addAttribute(name, value: value, range: range)
        } else {
            self.addAttribute(name, value: value, range: NSRange(location: 0, length: self.length))
        };return self
    }
    // MARK: - 添加多个属性
    @discardableResult
    public func byAddAttributes(_ attrs: [NSAttributedString.Key : Any], range: NSRange? = nil) -> Self {
        let targetRange = range ?? NSRange(location: 0, length: self.length)
        self.addAttributes(attrs, range: targetRange)
        return self
    }
    // MARK: - 移除属性
    @discardableResult
    public func byRemoveAttribute(_ name: NSAttributedString.Key, range: NSRange? = nil) -> Self {
        let targetRange = range ?? NSRange(location: 0, length: self.length)
        self.removeAttribute(name, range: targetRange)
        return self
    }
    // MARK: - 替换内容
    @discardableResult
    public func byReplace(in range: NSRange, with attrString: NSAttributedString) -> Self {
        self.replaceCharacters(in: range, with: attrString)
        return self
    }
    // MARK: - 插入
    @discardableResult
    public func byInsert(_ attrString: NSAttributedString, at index: Int) -> Self {
        self.insert(attrString, at: index)
        return self
    }
    // MARK: - 追加
    @discardableResult
    public func byAdd(_ attrString: NSAttributedString) -> Self {
        self.append(attrString)
        return self
    }
    // MARK: - 删除
    @discardableResult
    public func byDelete(in range: NSRange) -> Self {
        self.deleteCharacters(in: range)
        return self
    }
    // MARK: - 重置为新的富文本
    @discardableResult
    public func bySet(_ attrString: NSAttributedString) -> Self {
        self.setAttributedString(attrString)
        return self
    }
    // MARK: - 编辑批处理
    @discardableResult
    public func byBeginEditing() -> Self {
        self.beginEditing()
        return self
    }

    @discardableResult
    public func byEndEditing() -> Self {
        self.endEditing()
        return self
    }
}
