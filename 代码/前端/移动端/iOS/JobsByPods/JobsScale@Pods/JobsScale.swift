//
//  JobsScale.swift
//  JobsScale
//
//  Created by Jobs on 2026年5月13日，星期三.
//

#if os(OSX)
import AppKit
#elseif os(iOS) || os(tvOS)
import UIKit
#endif
#if canImport(JobsGetWindow)
import JobsGetWindow
#endif

// MARK: - 快捷屏幕宽高（保持你原来接口）
@inline(__always)
public func ScreenWidth(_ rate: CGFloat = 1) -> CGFloat { Screen.width * rate }

@inline(__always)
public func ScreenHeight(_ rate: CGFloat = 1) -> CGFloat { Screen.height * rate }
// MARK: - 字体缩放模式
public enum JobsFontScaleMode {
    /// 连续缩放：font = base * (screenWidth / designWidth)
    case continuous
    /// 分档缩放：更稳定、可控（推荐用于字体）
    case breakpoints
}
// MARK: - 核心比例器（UI + Font 合一）
public enum JobsScale {
    // MARK: Design Reference
    private static var designW: CGFloat = 375
    private static var designH: CGFloat = 812
    // MARK: Layout
    /// Safe Area 是“布局概念”，不适合作为全局比例尺的输入。
    /// 这里保留开关仅做兼容；当无法可靠获取主 window 时会自动回退到 Screen.size。
    private static var useSafeArea: Bool = false
    // MARK: Font Scale Config
    private static var fontMode: JobsFontScaleMode = .breakpoints
    private static var fontMinScale: CGFloat = 1.0
    private static var fontMaxScale: CGFloat = 1.15
    /// 字体分档（按屏幕点宽 pt）
    /// 你们可以按验收标准改：
    /// - 375: 1.00
    /// - 390: 1.05
    /// - 414: 1.08
    /// - 430+: 1.14
    private static var fontBreakpoints: [(maxWidth: CGFloat, scale: CGFloat)] = [
        (375, 1.00),
        (390, 1.05),
        (414, 1.08),
        (430, 1.14),
        (.greatestFiniteMagnitude, 1.14)
    ]
    // MARK: Setup
    public static func setup(
        designWidth: CGFloat,
        designHeight: CGFloat,
        useSafeArea: Bool = false,
        fontMode: JobsFontScaleMode = .breakpoints,
        fontMinScale: CGFloat = 1.0,
        fontMaxScale: CGFloat = 1.15,
        fontBreakpoints: [(maxWidth: CGFloat, scale: CGFloat)]? = nil
    ) {
        self.designW = designWidth.isFinite && designWidth > 0 ? designWidth : 375
        self.designH = designHeight.isFinite && designHeight > 0 ? designHeight : 812
        self.useSafeArea = useSafeArea
        self.fontMode = fontMode
        let minimum = fontMinScale.isFinite && fontMinScale > 0 ? fontMinScale : 1
        let maximum = fontMaxScale.isFinite && fontMaxScale > 0 ? fontMaxScale : 1.15
        self.fontMinScale = min(minimum, maximum)
        self.fontMaxScale = max(minimum, maximum)
        if let bps = fontBreakpoints, !bps.isEmpty {
            let normalized = bps.filter { $0.maxWidth.isFinite && $0.maxWidth > 0 && $0.scale.isFinite && $0.scale > 0 }
                .sorted { $0.maxWidth < $1.maxWidth }
            if !normalized.isEmpty { self.fontBreakpoints = normalized }
        }
    }
    // MARK: Screen Size（用于比例输入）
    /// 用于计算缩放比例的“屏幕尺寸”：
    /// - 默认用 Screen.size（优先 window.bounds，天然横竖屏正确，不依赖 connectedScenes）
    /// - 若启用 useSafeArea，则尝试从“主界面 normal window”扣除 safeAreaInsets；失败则回退 Screen.size
    public static var screenSize: CGSize {
        let base = Screen.size
        guard useSafeArea else { return base }
        if let window = UIApplication.jobsKeyWindow(preferMainScreen: true),
           window.windowLevel == .normal,
           !window.isHidden,
           window.alpha > 0.01,
           window.bounds.size != .zero {
            let insets = window.safeAreaInsets
            let w = max(0, window.bounds.width - (insets.left + insets.right))
            let h = max(0, window.bounds.height - (insets.top + insets.bottom))
            if w > 0, h > 0 {
                return CGSize(width: w, height: h)
            }
        };return base
    }
    // MARK: UI Scale
    public static var x: CGFloat { screenSize.width / designW }
    public static var y: CGFloat { screenSize.height / designH }
    // MARK: Font Scale（独立比例尺）
    /// 字体缩放只看“宽度”，避免 height / min(w,h) 在横屏/Pad 上乱跳
    public static var fontScale: CGFloat {
        let w = screenSize.width
        let raw: CGFloat
        switch fontMode {
        /// 处理 .continuous 分支
        case .continuous:
            raw = w / designW
        /// 处理 .breakpoints 分支
        case .breakpoints:
            raw = scaleFromBreakpoints(w)
        };return clamp(raw, fontMinScale, fontMaxScale)
    }

    private static func scaleFromBreakpoints(_ width: CGFloat) -> CGFloat {
        for item in fontBreakpoints {
            if width <= item.maxWidth { return item.scale }
        }
        return fontBreakpoints.last?.scale ?? 1
    }

    /// 多窗口调用传入实际 window，避免改变全局比例上下文。
    public static func screenSize(in window: UIWindow) -> CGSize {
        let bounds = window.bounds.size
        guard useSafeArea else { return bounds }
        let inset = window.safeAreaInsets
        return CGSize(width: max(1, bounds.width - inset.left - inset.right),
                      height: max(1, bounds.height - inset.top - inset.bottom))
    }

    public static func widthScale(in window: UIWindow) -> CGFloat {
        screenSize(in: window).width / designW
    }

    public static func heightScale(in window: UIWindow) -> CGFloat {
        screenSize(in: window).height / designH
    }

    // MARK: Pixel Align（像素对齐）
    public static func pixelAlign(_ value: CGFloat) -> CGFloat {
        #if os(iOS) || os(tvOS)
        let s = UIScreen.main.scale
        return (value * s).rounded() / s
        #else
        return value
        #endif
    }

    private static func clamp(_ v: CGFloat,
                              _ lo: CGFloat,
                              _ hi: CGFloat) -> CGFloat {
        min(max(v, lo), hi)
    }
}
// MARK: - Sugar：你要的 33.w / 33.h / 33.fz
extension BinaryInteger {
    /// UI 宽度缩放（像素对齐）
    public var w: CGFloat { JobsScale.pixelAlign(CGFloat(self) * JobsScale.x) }
    /// UI 高度缩放（像素对齐）
    public var h: CGFloat { JobsScale.pixelAlign(CGFloat(self) * JobsScale.y) }
    /// 字体缩放（独立比例尺，像素对齐）
    public var fz: CGFloat { JobsScale.pixelAlign(CGFloat(self) * JobsScale.fontScale) }
}

extension BinaryFloatingPoint {
     public var w: CGFloat { JobsScale.pixelAlign(CGFloat(self) * JobsScale.x) }
     public var h: CGFloat { JobsScale.pixelAlign(CGFloat(self) * JobsScale.y) }
     public var fz: CGFloat { JobsScale.pixelAlign(CGFloat(self) * JobsScale.fontScale) }
}

// MARK: - Screen（兼容横竖屏，不依赖 connectedScenes）
public enum Screen {
    /// 屏幕尺寸（以点为单位）
    /// - 优先 window.bounds.size：天然随横竖屏变化
    /// - 回退 UIScreen.main.bounds.size：在 iOS 8+ 通常是“竖屏坐标系”，但作为兜底足够
    public static var size: CGSize {
        #if os(iOS) || os(tvOS)
        if let window = UIApplication.jobsKeyWindow(preferMainScreen: true),
           window.bounds.size != .zero {
            return window.bounds.size
        };return UIScreen.main.bounds.size
        #else
        return .zero
        #endif
    }

    public static var width: CGFloat  { size.width }
    public static var height: CGFloat { size.height }
}
