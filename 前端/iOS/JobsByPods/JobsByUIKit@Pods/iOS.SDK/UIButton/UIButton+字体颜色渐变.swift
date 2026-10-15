//
//  UIButton+字体颜色渐变.swift
//  JobsByUIKit
//
//  Created by Jobs on 2026年5月13日，星期三.
//

#if os(OSX)
import AppKit
#elseif os(iOS) || os(tvOS)
import UIKit
#endif

import ObjectiveC
import JobsByQuartzCore
import JobsSwiftDSL
import JobsSwiftBaseDefines
import SnapKit

// MARK: - Associated Object Keys (NO WARNING)
private enum _JobsBtnGradientKey {
    /// 使用静态 UInt8 做 key，避免 “UnsafeRawPointer + String” 的黄色警告
    static var subtitleLabel: UInt8 = 0
    static var mainLayer: UInt8 = 0
    static var subLayer: UInt8 = 0
    static var mainColors: UInt8 = 0
    static var subColors: UInt8 = 0
    static var mainDir: UInt8 = 0
    static var subDir: UInt8 = 0
    static var stateRaw: UInt8 = 0
}
// MARK: - UIButton Subtitle Label (SnapKit)
extension UIButton {
    /// 副标题 Label（第二个 Label）。不存在就自动创建并加到按钮里。
    /// 默认布局：在 titleLabel 下面 2pt，水平居中（全部 SnapKit）
    public var jobs_subtitleLabel: UILabel {
        if let lb = objc_getAssociatedObject(self, &_JobsBtnGradientKey.subtitleLabel) as? UILabel {
            return lb
        }
        let lb = UILabel().byNumberOfLines(1).byTextAlignment(.center).byAddTo(self)
        self.titleLabel?.byVisible(YES)
        if let tl = self.titleLabel {
            lb.snp.makeConstraints { make in
                make.centerX.equalToSuperview()
                make.top.equalTo(tl.snp.bottom).offset(2)
                make.leading.greaterThanOrEqualToSuperview()
                make.trailing.lessThanOrEqualToSuperview()
                make.bottom.lessThanOrEqualToSuperview()
            }
        } else {
            lb.snp.makeConstraints { make in
                make.center.equalToSuperview()
            }
        }
        objc_setAssociatedObject(
            self,
            &_JobsBtnGradientKey.subtitleLabel,
            lb,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        );return lb
    }
    /// DSL：设置副标题文本（不做渐变，只管 text/font）
    @discardableResult
    public func jobs_setSubtitle(_ text: String?, font: UIFont? = nil) -> Self {
        jobs_subtitleLabel
            .byText(text)
            .byFont(font)
        return self
    }
}
// MARK: - Public DSL (3 APIs)
extension UIButton {
    /// 1) 只处理主标题（titleLabel）
    @discardableResult
    public func byGradientMainTitle(
        colors: [UIColor],
        direction: JobsGradientDirection = .leftToRight,
        for state: UIControl.State = .normal,
        autoLayout: Bool = true
    ) -> Self {
        if autoLayout {
            layoutIfNeeded()
            titleLabel?.layoutIfNeeded()
        }
        objc_setAssociatedObject(
            self,
            &_JobsBtnGradientKey.mainColors,
            colors,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
        objc_setAssociatedObject(
            self,
            &_JobsBtnGradientKey.mainDir,
            direction,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
        objc_setAssociatedObject(
            self,
            &_JobsBtnGradientKey.stateRaw,
            state.rawValue,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
        _jobs_applyMainGradient(colors: colors, direction: direction, for: state)
        return self
    }
    /// 2) 只处理副标题（jobs_subtitleLabel）
    @discardableResult
    public func byGradientSubtitle(
        colors: [UIColor],
        direction: JobsGradientDirection = .leftToRight,
        autoLayout: Bool = true
    ) -> Self {
        if autoLayout {
            layoutIfNeeded()
            jobs_subtitleLabel.layoutIfNeeded()
        }
        objc_setAssociatedObject(
            self,
            &_JobsBtnGradientKey.subColors,
            colors,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
        objc_setAssociatedObject(
            self,
            &_JobsBtnGradientKey.subDir,
            direction,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
        _jobs_applySubGradient(colors: colors, direction: direction)
        return self
    }
    /// 3) 主标题 + 副标题一致（同一套 colors + direction）
    @discardableResult
    public func byGradientTitlesSame(
        colors: [UIColor],
        direction: JobsGradientDirection = .leftToRight,
        for state: UIControl.State = .normal,
        autoLayout: Bool = true
    ) -> Self {
        if autoLayout {
            layoutIfNeeded()
            titleLabel?.layoutIfNeeded()
            jobs_subtitleLabel.layoutIfNeeded()
        }
        objc_setAssociatedObject(
            self,
            &_JobsBtnGradientKey.mainColors,
            colors,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
        objc_setAssociatedObject(
            self,
            &_JobsBtnGradientKey.subColors,
            colors,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
        objc_setAssociatedObject(
            self,
            &_JobsBtnGradientKey.mainDir,
            direction,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
        objc_setAssociatedObject(
            self,
            &_JobsBtnGradientKey.subDir,
            direction,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
        objc_setAssociatedObject(
            self,
            &_JobsBtnGradientKey.stateRaw,
            state.rawValue,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
        _jobs_applyMainGradient(colors: colors, direction: direction, for: state)
        _jobs_applySubGradient(colors: colors, direction: direction)
        return self
    }

    /// 布局/约束变化后刷新（按缓存 colors/direction 重刷主+副）
    @discardableResult
    public func jobs_updateGradientTitlesLayout(autoLayout: Bool = true) -> Self {
        if autoLayout {
            layoutIfNeeded()
            titleLabel?.layoutIfNeeded()
            jobs_subtitleLabel.layoutIfNeeded()
        }
        let stateRaw = (objc_getAssociatedObject(self, &_JobsBtnGradientKey.stateRaw) as? UInt) ?? UIControl.State.normal.rawValue
        let state = UIControl.State(rawValue: stateRaw)
        if let mainColors = objc_getAssociatedObject(self, &_JobsBtnGradientKey.mainColors) as? [UIColor],
           let mainDir = objc_getAssociatedObject(self, &_JobsBtnGradientKey.mainDir) as? JobsGradientDirection {
            _jobs_applyMainGradient(colors: mainColors, direction: mainDir, for: state)
        }
        if let subColors = objc_getAssociatedObject(self, &_JobsBtnGradientKey.subColors) as? [UIColor],
           let subDir = objc_getAssociatedObject(self, &_JobsBtnGradientKey.subDir) as? JobsGradientDirection {
            _jobs_applySubGradient(colors: subColors, direction: subDir)
        };return self
    }
}
// MARK: - Private Apply
extension UIButton {
    private func _jobs_applyMainGradient(
        colors: [UIColor],
        direction: JobsGradientDirection,
        for state: UIControl.State
    ) {
        guard let tl = titleLabel else { return }
        let text = self.title(for: state) ?? self.title(for: self.state) ?? tl.text
        _jobs_applyGradient(
            on: tl,
            text: text,
            colors: colors,
            direction: direction,
            layerKey: &_JobsBtnGradientKey.mainLayer
        )
    }

    private func _jobs_applySubGradient(
        colors: [UIColor],
        direction: JobsGradientDirection
    ) {
        let lb = jobs_subtitleLabel
        _jobs_applyGradient(
            on: lb,
            text: lb.text,
            colors: colors,
            direction: direction,
            layerKey: &_JobsBtnGradientKey.subLayer
        )
    }

    private func _jobs_applyGradient(
        on label: UILabel,
        text: String?,
        colors: [UIColor],
        direction: JobsGradientDirection,
        layerKey: UnsafeRawPointer
    ) {
        guard let text, !text.isEmpty else { return }
        let b = label.bounds
        guard b.width > 0, b.height > 0 else { return }
        if let old = objc_getAssociatedObject(self, layerKey) as? CAGradientLayer {
            old.removeFromSuperlayer()
        }
        let g = CAGradientLayer()
            .byFrame(b)
            .byColors(colors.map(\.cgColor))
            .byStartPoint(direction.points.start)
            .byEndPoint(direction.points.end)
            .byMask(
                CATextLayer()
                    .byString(text)
                    .byFont(label.font)
                    .byFontSize(label.font.pointSize)
                    .byAlignmentMode(.center)
                    .byContentsScale(UIScreen.main.scale)
                    .byFrame(b))
        label.byTextColor(JobsCor.clear).byAddSublayer(g)
        objc_setAssociatedObject(
            self,
            layerKey,
            g,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
    }
}
