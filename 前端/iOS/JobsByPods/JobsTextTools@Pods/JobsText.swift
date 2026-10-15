//
//  JobsText.swift
//  JobsTextTools
//
//  Created by Jobs on 2026年5月13日，星期三.
//

#if os(OSX)
import AppKit
#elseif os(iOS) || os(tvOS)
import UIKit
#endif

/// 统一载体：既可承载纯文本，也可承载富文本（不依赖 UIKit）
/// Swift 并发里，跨 actor / 跨任务传递的数据，如果是 Sendable，编译器才认为这么用是安全的。

/// 富文本可包含调用方自定义的可变属性或附件，因此不承诺 Sendable。
/// 跨 actor 传递纯文本使用 asString；富文本在所属 UI/调用执行域内消费。
public struct JobsText {
    public enum Storage {
        case plain(String)
        case attributed(NSAttributedString)
    }

    public let storage: Storage // 内部实现：真正的数据、复制策略、观察逻辑
    // MARK: - 构造
    public init(_ string: String) {
        self.storage = .plain(string)
    }

    public init(_ attributed: NSAttributedString) {
        // 固定字符与属性字典；自定义属性值及附件仍遵守调用方所有权合同。
        self.storage = .attributed(attributed.copy() as! NSAttributedString)
    }

    @available(iOS 15.0, macOS 12.0, *)
    public init(_ swiftAttr: AttributedString) {
        self.storage = .attributed(NSAttributedString(swiftAttr))
    }
    // 字面量支持：可直接写 let t: JobsText = "hello"
    public init(stringLiteral value: StringLiteralType) {
        self.storage = .plain(value)
    }
}
// MARK: - 字面量协议 & 描述
extension JobsText: ExpressibleByStringLiteral {}
extension JobsText: CustomStringConvertible {
    public var description: String { asString }
}
// MARK: - 基础访问
public extension JobsText {
    /// 仅当是纯文本时为 true
    var isPlain: Bool {
        if case .plain = storage { return true } else { return false }
    }
    /// ⬆️ 不管 plain/attributed，都给 NSAttributedString
    var asAttributed: NSAttributedString {
        switch storage {
        /// 处理 .plain 分支
        case .plain(let s):
            return NSAttributedString(string: s)
        /// 处理 .attributed 分支
        case .attributed(let at):
            return at
        }
    }
    /// ⬇️ 不管 plain/attributed，都给String（富文本会丢失样式，只保留 .string）
    var asString: String {
        switch storage {
        /// 处理 .plain 分支
        case .plain(let s): return s
        /// 处理 .attributed 分支
        case .attributed(let a): return a.string
        }
    }
    /// 只关心富文本时用；纯文本则返回 nil
    var attributed: NSAttributedString? {
        switch storage {
        /// 处理 .plain 分支
        case .plain:              return nil
        /// 处理 .attributed 分支
        case .attributed(let at): return at
        }
    }
    /// 以 NSAttributedString 取出
    /// - Parameter baseAttributes: 若本体是纯文本，应用这些基础属性生成富文本；若本体是富文本则忽略。
    func asAttributedString(baseAttributes: [NSAttributedString.Key: Any]? = nil) -> NSAttributedString {
        switch storage {
        /// 处理 .plain 分支
        case .plain(let s):
            if let attrs = baseAttributes, !attrs.isEmpty {
                return NSAttributedString(string: s, attributes: attrs)
            } else {
                return NSAttributedString(string: s)
            }
        /// 处理 .attributed 分支
        case .attributed(let a):
            // 返回不可变容器副本；属性对象不承诺深拷贝。
            return a.copy() as! NSAttributedString
        }
    }
}
// MARK: - 变换 & 组合
public extension JobsText {
    /// 在现有文本上“叠加”属性：
    /// - 若为纯文本：直接用 new 包一层。
    /// - 若为富文本：在每个 range 上 merge（已有的属性保持，冲突键以 new 覆盖）。
    func applying(_ new: [NSAttributedString.Key: Any]) -> JobsText {
        guard !new.isEmpty else { return self }
        switch storage {
        /// 处理 .plain 分支
        case .plain(let s):
            return JobsText(NSAttributedString(string: s, attributes: new))
        /// 处理 .attributed 分支
        case .attributed(let a):
            let m = NSMutableAttributedString(attributedString: a)
            let full = NSRange(location: 0, length: m.length)
            m.enumerateAttributes(in: full, options: []) { attrs, range, _ in
                var merged = attrs
                new.forEach { k, v in merged[k] = v } // 以 new 覆盖冲突
                m.setAttributes(merged, range: range)
            };return JobsText(m) // 新实例，保持不可变存储
        }
    }
    /// 自定义映射到底层 NSAttributedString（给完全控制权）
    func mapAttributed(_ transform: (NSAttributedString) -> NSAttributedString) -> JobsText {
        switch storage {
        /// 处理 .plain 分支
        case .plain(let s):
            return JobsText(transform(NSAttributedString(string: s)))
        /// 处理 .attributed 分支
        case .attributed(let a):
            return JobsText(transform(a))
        }
    }
    /// 拼接
    static func + (lhs: JobsText, rhs: JobsText) -> JobsText {
        switch (lhs.storage, rhs.storage) {
        /// 处理 .plain 分支
        case (.plain(let l), .plain(let r)):
            return JobsText(l + r)
        /// 未匹配已知分支时执行兜底处理
        default:
            let lm = NSMutableAttributedString(attributedString: lhs.asAttributedString())
            lm.append(rhs.asAttributedString())
            return JobsText(lm)
        }
    }
}
// MARK: - 相等性（基于 NSAttributedString 的 isEqual）
extension JobsText: Equatable {
    public static func == (l: JobsText, r: JobsText) -> Bool {
        switch (l.storage, r.storage) {
        /// 处理 .plain 分支
        case (.plain(let ls), .plain(let rs)):
            return ls == rs
        /// 未匹配已知分支时执行兜底处理
        default:
            return l.asAttributedString().isEqual(r.asAttributedString())
        }
    }
}
// MARK: - （可选）序列化：RTF/HTML 编解码帮助
public extension JobsText {
    /// 尝试以 RTF 表示导出（纯文本将被转换为带默认属性的 RTF）
    func rtfData() -> Data? {
        let a = asAttributedString()
        return try? a.data(from: NSRange(location: 0, length: a.length),
                           documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf])
    }
    /// 从 RTF/RTFD/HTML 等数据恢复富文本
    static func from(data: Data,
                     options: [NSAttributedString.DocumentReadingOptionKey: Any] = [:]) -> JobsText? {
        if let a = try? NSAttributedString(data: data, options: options, documentAttributes: nil) {
            return JobsText(a)
        };return nil
    }
}
