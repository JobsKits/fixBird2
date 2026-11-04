//
//  UIGestureRecognizer+DSL.swift
//  JobsByUIKit
//
//  Created by Jobs on 2026年5月13日，星期三.
//

#if os(OSX)
import AppKit
#elseif os(iOS) || os(tvOS)
import UIKit
#endif

/**
 
     let tap = UITapGestureRecognizer()
         .byTarget(self, action: #selector(onTap))
         .byCancelsTouchesInView(true)
         .byRequiresExclusiveTouchType(false)
         .byName("customTap")
         .byEnabled(true)
 */
extension UIGestureRecognizer {
    /// 初始化方法封装
    @discardableResult
    public func byTarget(_ target: Any?, action: Selector?) -> Self {
        // ⚠️ 注意：这里不是安全复用的做法，仅供链式设置使用
        if let target, let action {
            self.addTarget(target, action: action)
        };return self
    }
    /// Delegate
    @discardableResult
    public func byDelegate(_ delegate: UIGestureRecognizerDelegate?) -> Self {
        self.delegate = delegate
        return self
    }
    /// 是否启用
    @discardableResult
    public func byEnabled(_ isEnabled: Bool) -> Self {
        self.isEnabled = isEnabled
        return self
    }
    /// 触摸控制属性
    @discardableResult
    public func byCancelsTouchesInView(_ value: Bool) -> Self {
        self.cancelsTouchesInView = value
        return self
    }

    @discardableResult
    public func byDelaysTouchesBegan(_ value: Bool) -> Self {
        self.delaysTouchesBegan = value
        return self
    }

    @discardableResult
    public func byDelaysTouchesEnded(_ value: Bool) -> Self {
        self.delaysTouchesEnded = value
        return self
    }
    /// iOS9+ 触摸类型
    @available(iOS 9.0, *)
    @discardableResult
    public func byAllowedTouchTypes(_ types: [NSNumber]) -> Self {
        self.allowedTouchTypes = types
        return self
    }

    @available(iOS 9.0, *)
    @discardableResult
    public func byAllowedPressTypes(_ types: [NSNumber]) -> Self {
        self.allowedPressTypes = types
        return self
    }
    /// iOS9.2+ 独占触摸
    @available(iOS 9.2, *)
    @discardableResult
    public func byRequiresExclusiveTouchType(_ value: Bool) -> Self {
        self.requiresExclusiveTouchType = value
        return self
    }
    /// iOS11+ 手势命名
    @available(iOS 11.0, *)
    @discardableResult
    public func byName(_ name: String?) -> Self {
        self.name = name
        return self
    }
    /// iOS13.4+ 键盘修饰符 / 鼠标按钮
    @available(iOS 13.4, *)
    @discardableResult
    public func byModifierFlags(_ flags: UIKeyModifierFlags) -> Self {
        // modifierFlags 是只读属性，仅供获取，无可写入 setter
        // 所以这里只能做空实现以保持风格统一
        return self
    }

    @available(iOS 13.4, *)
    @discardableResult
    public func byButtonMask(_ mask: UIEvent.ButtonMask) -> Self {
        // 同上，buttonMask 也是只读
        return self
    }
    /// 公共辅助方法
    @discardableResult
    public func byRequireToFail(_ other: UIGestureRecognizer) -> Self {
        self.require(toFail: other)
        return self
    }
}
// MARK: 子类专属链式扩展@UITapGestureRecognizer
extension UITapGestureRecognizer {
    @discardableResult
    public func byTaps(_ count: Int) -> Self {
        numberOfTapsRequired = count
        return self
    }

    @discardableResult
    public func byTouches(_ count: Int) -> Self {
        numberOfTouchesRequired = count
        return self
    }
}
// MARK: 子类专属链式扩展@UILongPressGestureRecognizer
extension UILongPressGestureRecognizer {
    @discardableResult
    public func byMinDuration(_ t: TimeInterval) -> Self {
        minimumPressDuration = t
        return self
    }

    @discardableResult
    public func byMovement(_ v: CGFloat) -> Self {
        allowableMovement = v
        return self
    }

    @discardableResult
    public func byTouches(_ n: Int) -> Self {
        numberOfTouchesRequired = n
        return self
    }
}
// MARK: 子类专属链式扩展@UIPanGestureRecognizer
extension UIPanGestureRecognizer {
    @discardableResult
    public func byMinTouches(_ n: Int) -> Self {
        minimumNumberOfTouches = n
        return self
    }

    @discardableResult
    public func byMaxTouches(_ n: Int) -> Self {
        if maximumNumberOfTouches != Int.max {maximumNumberOfTouches = n;};return self
    }
}
// MARK: 子类专属链式扩展@UISwipeGestureRecognizer
extension UISwipeGestureRecognizer {
    @discardableResult
    public func byDirection(_ d: UISwipeGestureRecognizer.Direction) -> Self {
        direction = d
        return self
    }

    @discardableResult
    public func byTouches(_ n: Int) -> Self {
        numberOfTouchesRequired = n
        return self
    }
}
// MARK: 子类专属链式扩展@UIRotationGestureRecognizer
/// Rotation（旋转）
extension UIRotationGestureRecognizer {
    /// 当前旋转角度（弧度）
    @discardableResult
    public func byRotation(_ value: CGFloat) -> Self {
        self.rotation = value
        return self
    }
    /// 复位旋转角度为 0
    @discardableResult
    public func byResetRotation() -> Self {
        self.rotation = 0
        return self
    }
    /// 在闭包里获取旋转角度
    @discardableResult
    public func byOnRotationChange(_ block: @escaping (UIRotationGestureRecognizer, CGFloat) -> Void) -> Self {
        self.byAction { gesture in
            if let rot = gesture as? UIRotationGestureRecognizer {
                block(rot, rot.rotation)
            }
        };return self
    }
}
// MARK: 子类专属链式扩展@UITapGestureRecognizer
#if canImport(RxSwift) && canImport(RxCocoa)
import RxSwift
import RxCocoa
extension UITapGestureRecognizer {
    /// 语义属性：等价于 `.rx.event`
    public var event: ControlEvent<UITapGestureRecognizer> {
        self.rx.event
    }
}
#endif
// MARK: 子类专属链式扩展@UIPinchGestureRecognizer
/// Pinch（捏合缩放）
extension UIPinchGestureRecognizer {
    /// 当前缩放比例（scale）
    @discardableResult
    public func byScale(_ value: CGFloat) -> Self {
        self.scale = value
        return self
    }
    /// 复位缩放比例到默认值 1.0
    @discardableResult
    public func byResetScale() -> Self {
        self.scale = 1.0
        return self
    }
    /// 在闭包里获取当前 scale
    @discardableResult
    public func byOnScaleChange(_ block: @escaping (UIPinchGestureRecognizer, CGFloat) -> Void) -> Self {
        self.byAction { gesture in
            if let pinch = gesture as? UIPinchGestureRecognizer {
                block(pinch, pinch.scale)
            }
        };return self
    }
}
