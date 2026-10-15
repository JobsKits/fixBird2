//
//  UIButton+富文本.swift
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
// MARK: - UIButton@富文本
extension UIButton {
    @discardableResult
    public func byRichTitle(_ rich: NSAttributedString?,
                            for state: UIControl.State = .normal) -> Self {
        if #available(iOS 15.0, *) {
            var cfg = self.configuration ?? .plain()
            cfg.attributedTitle = rich.map { AttributedString($0) }
            self.configuration = cfg
            byUpdateConfig()
        } else {
            _setLegacyRichTitle(rich, for: state); _applyLegacyComposite(for: state)
        };return self
    }

    @discardableResult
    public func byRichSubTitle(_ rich: NSAttributedString?,
                               for state: UIControl.State = .normal) -> Self {
        if #available(iOS 15.0, *) {
            var cfg = self.configuration ?? .plain()
            cfg.attributedSubtitle = rich.map { AttributedString($0) }
            self.configuration = cfg
            byUpdateConfig()
        } else {
            _setLegacyRichSubTitle(rich, for: state); _applyLegacyComposite(for: state)
        };return self
    }
}
private var _richTitleKey: UInt8 = 0
private var _richSubKey:   UInt8 = 0
private var _jobsTitlePaddingKey: UInt8 = 0
extension UIButton {
    typealias StateRaw = UInt
    private var _legacyRichTitleMap: [StateRaw: NSAttributedString] {
        get { objc_getAssociatedObject(self, &_richTitleKey) as? [StateRaw: NSAttributedString] ?? [:] }
        set {
            objc_setAssociatedObject(
                self,
                &_richTitleKey,
                newValue,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
        }
    }

    private var _legacyRichSubMap: [StateRaw: NSAttributedString] {
        get { objc_getAssociatedObject(self, &_richSubKey) as? [StateRaw: NSAttributedString] ?? [:] }
        set {
            objc_setAssociatedObject(
                self,
                &_richSubKey,
                newValue,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }

    var _jobsTitlePadding: CGFloat {
        get {
            (objc_getAssociatedObject(self, &_jobsTitlePaddingKey) as? CGFloat) ?? 0
        }
        set {
            objc_setAssociatedObject(
                self,
                &_jobsTitlePaddingKey,
                newValue,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
        }
    }

    var _jobsLegacyTitlePadding: CGFloat {
        get { (objc_getAssociatedObject(self, &_jobsTitlePaddingKey) as? CGFloat) ?? 0 }
        set {
            objc_setAssociatedObject(
                self,
                &_jobsTitlePaddingKey,
                newValue,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
        }
    }

    private func _setLegacyRichTitle(_ rich: NSAttributedString?, for state: UIControl.State) {
        var m = _legacyRichTitleMap
        let k = state.rawValue
        if let r = rich { m[k] = r } else { m.removeValue(forKey: k) }
        _legacyRichTitleMap = m
    }

    private func _setLegacyRichSubTitle(_ rich: NSAttributedString?, for state: UIControl.State) {
        var m = _legacyRichSubMap
        let k = state.rawValue
        if let r = rich { m[k] = r } else { m.removeValue(forKey: k) }
        _legacyRichSubMap = m
    }

    func _applyLegacyComposite(for state: UIControl.State) {
        let k = state.rawValue
        let title = _legacyRichTitleMap[k]
        let sub   = _legacyRichSubMap[k]
        switch (title, sub) {
        /// 处理 (nil, nil) 分支
        case (nil, nil):
            setAttributedTitle(nil, for: state)
        /// 处理 (t?, nil) 分支
        case let (t?, nil):
            setAttributedTitle(t, for: state)
        /// 处理 (nil, s?) 分支
        case let (nil, s?):
            setAttributedTitle(s, for: state)
        /// 处理 (t?, s?) 分支
        case let (t?, s?):
            titleLabel?
                .byNumberOfLines(0)
                .byTextAlignment(.center)
            // ✅ 关键：用 paragraphSpacingBefore 控制“主副标题间距”
            let padding = _jobsLegacyTitlePadding
            let subMutable = NSMutableAttributedString(attributedString: s)
            if padding != 0 {
                let p = NSMutableParagraphStyle()
                p.paragraphSpacingBefore = padding
                // 如果你还想保持居中（也可以不写，取 label alignment）
                p.alignment = titleLabel?.textAlignment ?? .center
                subMutable.addAttribute(.paragraphStyle,
                                        value: p,
                                        range: NSRange(location: 0, length: subMutable.length))
            }
            let combined = NSMutableAttributedString()
            combined.append(t)
            combined.append(NSAttributedString(string: "\n")) // 保留换行（必须要有两行）
            combined.append(subMutable)
            byAttributedTitle(combined, for: state)
        }
    }
}
