//
//  UIButton+Subtitle.swift
//  JobsByUIKit
//
//  Created by Jobs on 2026年5月13日，星期三.
//

#if os(OSX)
import AppKit
#elseif os(iOS) || os(tvOS)
import UIKit
#endif

import JobsSwiftBaseDefines

private extension UIControl.State { var raw: UInt { rawValue } }
// MARK: - Subtitle（无富文本）
public struct _JobsSubPackNoAttr {
    public var text: String = ""
    public var font: UIFont?
    public var color: UIColor?
}
public var _jobsSubDictKey_noAttr: UInt8 = 0
// MARK: - Subtitle（富文本）
public struct _JobsSubPackAttr {
    public var attr: NSAttributedString?
}
public var _jobsSubDictKey_attr: UInt8 = 0
public var _jobsSubtitleHandlerInstalledKey: UInt8 = 0
public var _jobsCfgBgImageKey: UInt8 = 0
extension UIButton {
    public var jobs_cfgBgImage: UIImage? {
        get { objc_getAssociatedObject(self, &_jobsCfgBgImageKey) as? UIImage }
        set {
            objc_setAssociatedObject(
                self,
                &_jobsCfgBgImageKey,
                newValue,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
        }
    }
    // no-attr dict
    public var _subDict_noAttr: [UInt: _JobsSubPackNoAttr] {
        get { (objc_getAssociatedObject(self, &_jobsSubDictKey_noAttr) as? [UInt: _JobsSubPackNoAttr]) ?? [:] }
        set {
            objc_setAssociatedObject(
                self,
                &_jobsSubDictKey_noAttr,
                newValue,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
        }
    }
    // attr dict
    public var _subDict_attr: [UInt: _JobsSubPackAttr] {
        get { (objc_getAssociatedObject(self, &_jobsSubDictKey_attr) as? [UInt: _JobsSubPackAttr]) ?? [:] }
        set {
            objc_setAssociatedObject(self,
                                     &_jobsSubDictKey_attr,
                                     newValue,
                                     .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
        }
    }
    // MARK: packs
    public func _subPack_noAttr(for state: UIControl.State, create: Bool = true) -> _JobsSubPackNoAttr {
        var d = _subDict_noAttr
        if let p = d[state.raw] { return p }
        if create {
            let p = _JobsSubPackNoAttr()
            d[state.raw] = p
            _subDict_noAttr = d
            return p
        };return _JobsSubPackNoAttr()
    }

    public func _setSubPack_noAttr(_ p: _JobsSubPackNoAttr, for state: UIControl.State) {
        var d = _subDict_noAttr; d[state.raw] = p; _subDict_noAttr = d
        if #available(iOS 15.0, *) {
            _ensureSubtitleHandler_noAttrInstalled()
            setNeedsUpdateConfiguration()
        }
    }

    public func _subPack_attr(for state: UIControl.State, create: Bool = true) -> _JobsSubPackAttr {
        var d = _subDict_attr
        if let p = d[state.raw] { return p }
        if create {
            let p = _JobsSubPackAttr(attr: nil)
            d[state.raw] = p
            _subDict_attr = d
            return p
        };return _JobsSubPackAttr(attr: nil)
    }

    public func _setSubPack_attr(_ p: _JobsSubPackAttr, for state: UIControl.State) {
        var d = _subDict_attr; d[state.raw] = p; _subDict_attr = d
        if #available(iOS 15.0, *) {
            _ensureSubtitleHandler_noAttrInstalled()
            setNeedsUpdateConfiguration()
        }
    }

    @available(iOS 15.0, *)
    public func _ensureSubtitleHandler_noAttrInstalled() {
        // 已安装就不重复装
        if (objc_getAssociatedObject(self, &_jobsSubtitleHandlerInstalledKey) as? Bool) == true { return }
        objc_setAssociatedObject(self, &_jobsSubtitleHandlerInstalledKey, true, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        let existing = self.configurationUpdateHandler
        self.automaticallyUpdatesConfiguration = true
        self.configurationUpdateHandler = { [weak self] btn in
            // 先把外部原有的 handler 执行（不抢控制权）
            existing?(btn)
            guard let self = self else { return }
            // 当前状态
            let st = btn.state
            // 拿到（或创建）当前配置
            var cfg = btn.configuration ?? .plain()
            cfg.titleAlignment = .center
            // ---------- 主标题：防丢 ----------
            if cfg.title == nil,
               let t = btn.title(for: .normal),
               !t.isEmpty {
                cfg.title = t
            }
            // ---------- 副标题：优先富文本（✅ NEW） ----------
            let apack = self._subDict_attr[st.rawValue] ?? self._subDict_attr[UIControl.State.normal.rawValue]
            if let a = apack?.attr, a.length > 0 {
                cfg.subtitle = nil
                cfg.attributedSubtitle = AttributedString(a)
                // 提交背景等后续逻辑仍然走
            } else {
                // ---------- 副标题：无富文本（原逻辑） ----------
                let pack = self._subDict_noAttr[st.rawValue] ?? self._subDict_noAttr[UIControl.State.normal.rawValue]
                let subText = pack?.text ?? ""
                cfg.subtitle = subText.isEmpty ? nil : subText
                let f = pack?.font
                let c = pack?.color
                cfg.subtitleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
                    var a = incoming
                    if let f { a.font = f }
                    if let c { a.foregroundColor = c };return a
                }
            }
            // ---------- 背景图：优先“粘住”的，再兜底 legacy ----------
            var bg = cfg.background
            if let keep = self.jobs_cfgBgImage {
                if bg.image !== keep {
                    bg.image = keep
                    if bg.imageContentMode == .scaleToFill { bg.imageContentMode = .scaleAspectFill }
                    bg.backgroundColor = JobsCor.clear
                }
            } else if bg.image == nil {
                if let legacy = self.backgroundImage(for: st) ?? self.backgroundImage(for: .normal) {
                    bg.image = legacy
                    if bg.imageContentMode == .scaleToFill { bg.imageContentMode = .scaleAspectFill }
                    bg.backgroundColor = JobsCor.clear
                }
            }
            cfg.background = bg
            // ---------- 提交 ----------
            btn.configuration = cfg
        }
    }

    public func _legacy_applySubtitle_noAttr(text: String?, for state: UIControl.State) {
        let titleText = self.title(for: state)
            ?? self.attributedTitle(for: state)?.string
            ?? self.title(for: .normal)
            ?? self.attributedTitle(for: .normal)?.string
            ?? ""
        let full = text.map { titleText.isEmpty ? $0 : "\(titleText)\n\($0)" } ?? titleText
        setTitle(full, for: state)
        titleLabel?.numberOfLines = 2
        titleLabel?.textAlignment = .center
    }
    // iOS15 以下富文本副标题兜底（合成 attributedTitle）
    public func _legacy_applySubtitle_attr(_ subAttr: NSAttributedString?, for state: UIControl.State) {
        // title 取当前状态优先，再 normal
        let titleAttr: NSAttributedString? =
        self.attributedTitle(for: state)
        ?? self.attributedTitle(for: .normal)
        ?? {
            let t = self.title(for: state) ?? self.title(for: .normal) ?? ""
            if t.isEmpty { return nil };return NSAttributedString(string: t, attributes: [.font: self.titleLabel?.font ?? JobsFont.systemFont(ofSize: 15)])
        }()
        let sub = subAttr
        if titleAttr == nil, sub == nil {
            setAttributedTitle(nil, for: state)
            return
        }
        let full = NSMutableAttributedString()
        if let titleAttr { full.append(titleAttr) }
        if let sub {
            if full.length > 0 { full.append(NSAttributedString(string: "\n")) }
            full.append(sub)
        }
        setAttributedTitle(full, for: state)
        titleLabel?.numberOfLines = 2
        titleLabel?.textAlignment = .center
    }
}

extension UIButton {
    @discardableResult
    public func bySubTitle(_ text: String?, for state: UIControl.State = .normal) -> Self {
        if #available(iOS 15.0, *) {
            var p = _subPack_noAttr(for: state); p.text = text ?? ""; _setSubPack_noAttr(p, for: state)
            // ⬇️ 立刻写入配置，保证首次就能看到（该方法你工程里已存在时正常生效）
            _applySubtitleToConfigurationNow(targetState: state)
        } else {
            _legacy_applySubtitle_noAttr(text: text, for: state)
        };return self
    }

    @discardableResult
    public func bySubTitleFont(_ font: UIFont?, for state: UIControl.State = .normal) -> Self {
        if #available(iOS 15.0, *) {
            var p = _subPack_noAttr(for: state); p.font = font; _setSubPack_noAttr(p, for: state)
            _applySubtitleToConfigurationNow(targetState: state)
        };return self
    }

    @discardableResult
    public func bySubTitleColor(_ color: UIColor?, for state: UIControl.State = .normal) -> Self {
        if #available(iOS 15.0, *) {
            var p = _subPack_noAttr(for: state); p.color = color; _setSubPack_noAttr(p, for: state)
            _applySubtitleToConfigurationNow(targetState: state)
        };return self
    }
    // 副标题富文本（按 state 存储 + iOS15 configuration 同步）
    @discardableResult
    public func byAttributedSubTitle(_ attr: NSAttributedString?, for state: UIControl.State = .normal) -> Self {
        if #available(iOS 15.0, *) {
            var p = _subPack_attr(for: state)
            p.attr = attr
            _setSubPack_attr(p, for: state)
            _applySubtitleToConfigurationNow(targetState: state)
        } else {
            // legacy：直接合成 attributedTitle 显示
            _legacy_applySubtitle_attr(attr, for: state)
        };return self
    }
}
