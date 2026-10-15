//
//  UIView+手势（支持叠加不覆盖）.swift
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
import JobsSwiftDSL

/**
 // MARK: - 点击 Tap
 UIView().addGestureRecognizer(
     UITapGestureRecognizer
         .byConfig { gr in
             print("Tap 触发 on: \(String(describing: gr.view))")
         }
         .byTaps(2)                       // 双击
         .byTouches(1)                    // 单指
         .byCancelsTouchesInView(true)
         .byEnabled(true)
         .byName("customTap")
 )

 // MARK: - 长按 LongPress
 UIView().addGestureRecognizer(
     UILongPressGestureRecognizer
         .byConfig { gr in
             if gr.state == .began {
                 print("长按开始")
             } else if gr.state == .ended {
                 print("长按结束")
             }
         }
         .byMinDuration(0.8)              // 最小按压时长
         .byMovement(12)                  // 允许移动距离
         .byTouches(1)                    // 单指
 )

 // MARK: - 拖拽 Pan
 UIView().addGestureRecognizer(
     UIPanGestureRecognizer
         .byConfig { gr in
             let p = (gr as! UIPanGestureRecognizer).translation(in: gr.view)
             if gr.state == .changed {
                 print("拖拽中: \(p)")
             } else if gr.state == .ended {
                 print("拖拽结束")
             }
         }
         .byMinTouches(1)
         .byMaxTouches(2)
         .byCancelsTouchesInView(true)
 )

 // MARK: - 轻扫 Swipe（单方向）
 UIView().addGestureRecognizer(
     UISwipeGestureRecognizer
         .byConfig { _ in
             print("👉 右滑触发")
         }
         .byDirection(.right)
         .byTouches(1)
 )

 // MARK: - 轻扫 Swipe（多方向）
 let swipeContainer = UIView()
 swipeContainer.addGestureRecognizer(
     UISwipeGestureRecognizer
         .byConfig { _ in print("← 左滑") }
         .byDirection(.left)
 )
 swipeContainer.addGestureRecognizer(
     UISwipeGestureRecognizer
         .byConfig { _ in print("→ 右滑") }
         .byDirection(.right)
 )
 swipeContainer.addGestureRecognizer(
     UISwipeGestureRecognizer
         .byConfig { _ in print("↑ 上滑") }
         .byDirection(.up)
 )
 swipeContainer.addGestureRecognizer(
     UISwipeGestureRecognizer
         .byConfig { _ in print("↓ 下滑") }
         .byDirection(.down)
 )

 // MARK: - 捏合 Pinch
 UIView().addGestureRecognizer(
     UIPinchGestureRecognizer
         .byConfig { _ in }
         .byOnScaleChange { gr, scale in
             if gr.state == .changed {
                 print("缩放比例: \(scale)")
             }
         }
         .byScale(1.0)
 )

 // MARK: - 旋转 Rotate
 UIView().addGestureRecognizer(
     UIRotationGestureRecognizer
         .byConfig { _ in }
         .byOnRotationChange { gr, r in
             if gr.state == .changed {
                 print("旋转角度(弧度): \(r)")
             }
         }
         .byRotation(0)
 )
 // MARK: - 直接设置手势（已锚定视图）
 let views = UIView()
     .addTapAction { gr in
         print("点击 \(gr.view!)")
     }
     .addLongPressAction { gr in
         if gr.state == .began { print("长按开始") }
     }
     .addPanAction { gr in
         let p = (gr as! UIPanGestureRecognizer).translation(in: gr.view)
         print("拖拽中: \(p)")
     }
     .addPinchAction { gr in
         let scale = (gr as! UIPinchGestureRecognizer).scale
         print("缩放比例：\(scale)")
     }
     .addRotationAction { gr in
         let rotation = (gr as! UIRotationGestureRecognizer).rotation
         print("旋转角度：\(rotation)")
     }

 // MARK: - 在已有的手势触发事件里面新增手势行为
 UIView().addGestureRecognizer(UISwipeGestureRecognizer()
     .byDirection(.left)
     .byAction { gr in print("左滑 \(gr.view!)") })

 // MARK: - 多个方向的 swipe 并存
 // 同一 view 上同时添加四个方向的 swipe
 let idL = view.addSwipeActionMulti(direction: .left)  { gr in print("←") }
 let idR = view.addSwipeActionMulti(direction: .right) { gr in print("→") }
 let idU = view.addSwipeActionMulti(direction: .up)    { gr in print("↑") }
 let idD = view.addSwipeActionMulti(direction: .down)  { gr in print("↓") }

 // 指定 id，方便链式与管理
 view.addSwipeActionMulti(use: "swipe.left", direction: .left) { _ in }
     .addSwipeActionMulti(use: "swipe.right", direction: .right) { _ in }

 // 精确移除某一个
 view.removeSwipeActionMulti(id: idL)
 // 或批量移除该类手势
 view.removeAllSwipeActionsMulti()
 */
// ================================== UIView + 手势 DSL（全量、兼容） ==================================
extension UIView {
    // 每个手势类型独立 key（同时用于“view->gesture”和“gesture->box”）
    private struct GestureKeys {
        static var tapKey: UInt8 = 0
        static var longKey: UInt8 = 0
        static var panKey: UInt8 = 0
        static var swipeKey: UInt8 = 0
        static var pinchKey: UInt8 = 0
        static var rotateKey: UInt8 = 0
    }
    // MARK: - 手势通用闭包盒子
    private final class _GestureActionBox {
        let action: jobsByGRBlock
        init(_ action: @escaping jobsByGRBlock) { self.action = action }
    }
    // MARK: - Tap（点击）
    /// 新接口：带 gesture；兼容链式配置
    @discardableResult
    public func addTapAction(
        taps: Int = 1,
        cancelsTouchesInView: Bool = true,
        requiresExclusiveTouchType: Bool = false,
        _ action: @escaping jobsByGRBlock
    ) -> Self {
        isUserInteractionEnabled = true
        if let old = objc_getAssociatedObject(self, &GestureKeys.tapKey) as? UITapGestureRecognizer {
            removeGestureRecognizer(old)
        }
        let tap = jobs_addGesture(
            UITapGestureRecognizer
                .byConfig { gr in
                    (objc_getAssociatedObject(gr, &GestureKeys.tapKey) as? _GestureActionBox)?.action(gr)
                    print("Tap 触发 on: \(String(describing: gr.view))")
                }
                .byTaps(taps)                       // 双击
                .byTouches(1)                       // 单指
                .byCancelsTouchesInView(cancelsTouchesInView)
                .byRequiresExclusiveTouchType(requiresExclusiveTouchType)
                .byEnabled(true)
                .byName("customTap"))!
        objc_setAssociatedObject(
            self,
            &GestureKeys.tapKey,
            tap,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        objc_setAssociatedObject(
            tap,
            &GestureKeys.tapKey,
            _GestureActionBox(action),
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        return self
    }
    /// ✅ Tap 事件叠加：在既有 Tap 动作后继续追加
    /// - 行为：
    ///   - 若 view 已安装本 DSL 的 tap 手势：不移除手势，仅追加回调。
    ///   - 若尚未安装：等价于 `addTapAction(...)`。
    @discardableResult
    public func addTapActionAppend(
        taps: Int = 1,
        cancelsTouchesInView: Bool = true,
        requiresExclusiveTouchType: Bool = false,
        _ action: @escaping jobsByGRBlock
    ) -> Self {
        isUserInteractionEnabled = true
        if let tap = objc_getAssociatedObject(self, &GestureKeys.tapKey) as? UITapGestureRecognizer {
            // 复用既有 recognizer，只更新配置 + 叠加 action
            tap.numberOfTapsRequired = taps
            tap.cancelsTouchesInView = cancelsTouchesInView
            if #available(iOS 9.0, tvOS 9.0, *) {
                tap.requiresExclusiveTouchType = requiresExclusiveTouchType
            }
            let oldAction = (objc_getAssociatedObject(tap, &GestureKeys.tapKey) as? _GestureActionBox)?.action
            let composed: jobsByGRBlock = { gr in
                oldAction?(gr)
                action(gr)
            }
            objc_setAssociatedObject(
                tap,
                &GestureKeys.tapKey,
                _GestureActionBox(composed),
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            return self
        }
        // 没有旧手势，直接安装
        return addTapAction(
            taps: taps,
            cancelsTouchesInView: cancelsTouchesInView,
            requiresExclusiveTouchType: requiresExclusiveTouchType,
            action
        )
    }
    /// 旧接口：无参数（向下兼容）
    @discardableResult
    public func addTapAction(_ action: @escaping jobsByVoidBlock) -> Self {
        addTapAction { _ in action() }
    }
    /// ✅ 旧接口：把「view 本身」作为参数回调（符合常见 onTap(sender) 习惯）
    /// - 注意：如果手势未挂载到 view（理论上不会发生），该回调不会被触发。
    @discardableResult
    public func addTapAction(_ action: @escaping (UIView) -> Void) -> Self {
        addTapAction { gr in
            guard let v = gr.view else { return }
            action(v)
        }
    }
    /// ✅ 强类型接口：把「view 本身」以具体类型回调出去（例如 JobsButton / UIImageView / UILabel ...）
    /// - 用法：
    ///   `view.addTapAction { (sender: JobsButton) in ... }`
    @discardableResult
    public func addTapAction<T: UIView>(_ action: @escaping (T) -> Void) -> Self {
        addTapAction { gr in
            guard let v = gr.view as? T else { return }
            action(v)
        }
    }
    /// ✅ Tap 事件叠加：无参数版本（向下兼容调用习惯）
    @discardableResult
    public func addTapActionAppend(_ action: @escaping jobsByVoidBlock) -> Self {
        addTapActionAppend { _ in action() }
    }
    /// ✅ Tap 事件叠加：把「view 本身」作为参数回调
    @discardableResult
    public func addTapActionAppend(_ action: @escaping (UIView) -> Void) -> Self {
        addTapActionAppend { gr in
            guard let v = gr.view else { return }
            action(v)
        }
    }
    /// ✅ 强类型接口：Tap 事件叠加，把「view 本身」以具体类型回调出去（例如 JobsButton / UIImageView / UILabel ...）
    /// - 用法：
    ///   `view.addTapActionAppend { (sender: JobsButton) in ... }`
    @discardableResult
    public func addTapActionAppend<T: UIView>(_ action: @escaping (T) -> Void) -> Self {
        addTapActionAppend { gr in
            guard let v = gr.view as? T else { return }
            action(v)
        }
    }

    public func removeTapAction() {
        if let g = objc_getAssociatedObject(self, &GestureKeys.tapKey) as? UITapGestureRecognizer {
            removeGestureRecognizer(g)
        };objc_setAssociatedObject(
            self,
            &GestureKeys.tapKey,
            nil,
            .OBJC_ASSOCIATION_ASSIGN)
    }
    // MARK: - LongPress（长按）
    @discardableResult
    public func addLongPressAction(
        minimumPressDuration: TimeInterval = 0.5,
        allowableMovement: CGFloat = 10,
        numberOfTouchesRequired: Int = 1,
        _ action: @escaping jobsByGRBlock
    ) -> Self {
        isUserInteractionEnabled = true
        if let old = objc_getAssociatedObject(self, &GestureKeys.longKey) as? UILongPressGestureRecognizer {
            removeGestureRecognizer(old)
        }
        let long = jobs_addGesture(
            UILongPressGestureRecognizer
                .byConfig { gr in
                    (objc_getAssociatedObject(gr, &GestureKeys.longKey) as? _GestureActionBox)?.action(gr)
                }
                .byMinDuration(minimumPressDuration)              // 最小按压时长
                .byMovement(allowableMovement)                    // 允许移动距离
                .byTouches(numberOfTouchesRequired)               // 单指
        )!
        objc_setAssociatedObject(
            self,
            &GestureKeys.longKey,
            long,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        objc_setAssociatedObject(
            long,
            &GestureKeys.longKey,
            _GestureActionBox(action),
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        return self
    }
    /// ✅ LongPress 事件叠加：在既有 LongPress 动作后继续追加
    @discardableResult
    public func addLongPressActionAppend(
        minimumPressDuration: TimeInterval = 0.5,
        allowableMovement: CGFloat = 10,
        numberOfTouchesRequired: Int = 1,
        _ action: @escaping jobsByGRBlock
    ) -> Self {
        isUserInteractionEnabled = true
        if let long = objc_getAssociatedObject(self, &GestureKeys.longKey) as? UILongPressGestureRecognizer {
            long.minimumPressDuration = minimumPressDuration
            long.allowableMovement = allowableMovement
            long.numberOfTouchesRequired = numberOfTouchesRequired
            let oldAction = (objc_getAssociatedObject(long, &GestureKeys.longKey) as? _GestureActionBox)?.action
            let composed: jobsByGRBlock = { gr in
                oldAction?(gr)
                action(gr)
            }
            objc_setAssociatedObject(
                long,
                &GestureKeys.longKey,
                _GestureActionBox(composed),
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            return self
        };return addLongPressAction(
            minimumPressDuration: minimumPressDuration,
            allowableMovement: allowableMovement,
            numberOfTouchesRequired: numberOfTouchesRequired,
            action
        )
    }
    /// 旧接口兼容
    @discardableResult
    public func addLongPressAction(_ action: @escaping jobsByVoidBlock) -> Self {
        addLongPressAction { _ in action() }
    }
    /// ✅ LongPress 事件叠加：无参数版本（向下兼容调用习惯）
    @discardableResult
    public func addLongPressActionAppend(_ action: @escaping jobsByVoidBlock) -> Self {
        addLongPressActionAppend { _ in action() }
    }

    public func removeLongPressAction() {
        if let g = objc_getAssociatedObject(self, &GestureKeys.longKey) as? UILongPressGestureRecognizer {
            removeGestureRecognizer(g)
        };objc_setAssociatedObject(
            self,
            &GestureKeys.longKey,
            nil,
            .OBJC_ASSOCIATION_ASSIGN)
    }
    // MARK: - Pan（拖拽）
    @discardableResult
    public func addPanAction(
        minimumNumberOfTouches: Int = 1,
        maximumNumberOfTouches: Int = Int.max,
        _ action: @escaping jobsByGRBlock
    ) -> Self {
        isUserInteractionEnabled = true
        if let old = objc_getAssociatedObject(self, &GestureKeys.panKey) as? UIPanGestureRecognizer {
            removeGestureRecognizer(old)
        }
        let pan = jobs_addGesture(UIPanGestureRecognizer
            .byConfig { sender in
                (objc_getAssociatedObject(sender, &GestureKeys.panKey) as? _GestureActionBox)?.action(sender)
            }
            .byMinTouches(minimumNumberOfTouches)
            .byMaxTouches(maximumNumberOfTouches)
            .byCancelsTouchesInView(true))!
        objc_setAssociatedObject(
            self,
            &GestureKeys.panKey,
            pan,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        objc_setAssociatedObject(
            pan,
            &GestureKeys.panKey,
            _GestureActionBox(action),
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        return self
    }
    /// ✅ Pan 事件叠加：在既有 Pan 动作后继续追加
    @discardableResult
    public func addPanActionAppend(
        minimumNumberOfTouches: Int = 1,
        maximumNumberOfTouches: Int = Int.max,
        _ action: @escaping jobsByGRBlock
    ) -> Self {
        isUserInteractionEnabled = true
        if let pan = objc_getAssociatedObject(self, &GestureKeys.panKey) as? UIPanGestureRecognizer {
            pan.minimumNumberOfTouches = minimumNumberOfTouches
            pan.maximumNumberOfTouches = maximumNumberOfTouches
            let oldAction = (objc_getAssociatedObject(pan, &GestureKeys.panKey) as? _GestureActionBox)?.action
            let composed: jobsByGRBlock = { gr in
                oldAction?(gr)
                action(gr)
            }
            objc_setAssociatedObject(
                pan,
                &GestureKeys.panKey,
                _GestureActionBox(composed),
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC);return self
        };return addPanAction(
            minimumNumberOfTouches: minimumNumberOfTouches,
            maximumNumberOfTouches: maximumNumberOfTouches,
            action
        )
    }
    /// 旧接口兼容
    @discardableResult
    public func addPanAction(_ action: @escaping jobsByVoidBlock) -> Self {
        addPanAction { _ in action() }
    }
    /// ✅ Pan 事件叠加：无参数版本
    @discardableResult
    public func addPanActionAppend(_ action: @escaping jobsByVoidBlock) -> Self {
        addPanActionAppend { _ in action() }
    }
    public func removePanAction() {
        if let g = objc_getAssociatedObject(self, &GestureKeys.panKey) as? UIPanGestureRecognizer {
            removeGestureRecognizer(g)
        }
        objc_setAssociatedObject(
            self,
            &GestureKeys.panKey,
            nil,
            .OBJC_ASSOCIATION_ASSIGN)
    }
    // MARK: - Swipe（轻扫）
    @discardableResult
    public func addSwipeAction(
        direction: UISwipeGestureRecognizer.Direction = .right,
        numberOfTouchesRequired: Int = 1,
        _ action: @escaping jobsByGRBlock
    ) -> Self {
        isUserInteractionEnabled = true
        if let old = objc_getAssociatedObject(self, &GestureKeys.swipeKey) as? UISwipeGestureRecognizer {
            removeGestureRecognizer(old)
        }
        let swipe = jobs_addGesture(
            UISwipeGestureRecognizer
                .byConfig { sender in
                    print("👉 右滑触发")
                    (objc_getAssociatedObject(sender, &GestureKeys.swipeKey) as? _GestureActionBox)?.action(sender)
                }
                .byDirection(direction)
                .byTouches(numberOfTouchesRequired))!
        objc_setAssociatedObject(
            self,
            &GestureKeys.swipeKey,
            swipe,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        objc_setAssociatedObject(
            swipe,
            &GestureKeys.swipeKey,
            _GestureActionBox(action),
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        return self
    }
    /// ✅ Swipe 事件叠加：在既有 Swipe 动作后继续追加（单实例版）
    /// - 注意：此方法只针对「单实例 swipe」。如果你需要一个 view 同时存在多方向 swipe，继续用 `addSwipeActionMulti`。
    @discardableResult
    public func addSwipeActionAppend(
        direction: UISwipeGestureRecognizer.Direction = .right,
        numberOfTouchesRequired: Int = 1,
        _ action: @escaping jobsByGRBlock
    ) -> Self {
        isUserInteractionEnabled = true
        if let swipe = objc_getAssociatedObject(self, &GestureKeys.swipeKey) as? UISwipeGestureRecognizer {
            swipe.byDirection(direction)
            swipe.numberOfTouchesRequired = numberOfTouchesRequired
            let oldAction = (objc_getAssociatedObject(swipe, &GestureKeys.swipeKey) as? _GestureActionBox)?.action
            let composed: jobsByGRBlock = { gr in
                oldAction?(gr)
                action(gr)
            }
            objc_setAssociatedObject(
                swipe,
                &GestureKeys.swipeKey,
                _GestureActionBox(composed),
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC);return self
        };return addSwipeAction(
            direction: direction,
            numberOfTouchesRequired: numberOfTouchesRequired,
            action
        )
    }
    /// 旧接口兼容
    @discardableResult
    public func addSwipeAction(_ action: @escaping jobsByVoidBlock) -> Self {
        addSwipeAction { _ in action() }
    }
    /// ✅ Swipe 事件叠加：无参数版本
    @discardableResult
    public func addSwipeActionAppend(_ action: @escaping jobsByVoidBlock) -> Self {
        addSwipeActionAppend { _ in action() }
    }
    public func removeSwipeAction() {
        if let g = objc_getAssociatedObject(self, &GestureKeys.swipeKey) as? UISwipeGestureRecognizer {
            removeGestureRecognizer(g)
        }
        objc_setAssociatedObject(self, &GestureKeys.swipeKey, nil, .OBJC_ASSOCIATION_ASSIGN)
    }
    // MARK: - Pinch（捏合缩放）
    @discardableResult
    public func addPinchAction(_ action: @escaping jobsByGRBlock) -> Self {
        isUserInteractionEnabled = true
        if let old = objc_getAssociatedObject(self, &GestureKeys.pinchKey) as? UIPinchGestureRecognizer {
            removeGestureRecognizer(old)
        }
        let pinch = jobs_addGesture(UIPinchGestureRecognizer
            .byConfig { _ in }
            .byOnScaleChange { sender, scale in
                (objc_getAssociatedObject(sender, &GestureKeys.pinchKey) as? _GestureActionBox)?.action(sender)
            }
        )!
        objc_setAssociatedObject(
            self,
            &GestureKeys.pinchKey,
            pinch,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        objc_setAssociatedObject(
            pinch,
            &GestureKeys.pinchKey,
            _GestureActionBox(action),
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        return self
    }
    /// ✅ Pinch 事件叠加：在既有 Pinch 动作后继续追加
    @discardableResult
    public func addPinchActionAppend(_ action: @escaping jobsByGRBlock) -> Self {
        isUserInteractionEnabled = true
        if let pinch = objc_getAssociatedObject(self, &GestureKeys.pinchKey) as? UIPinchGestureRecognizer {
            let oldAction = (objc_getAssociatedObject(pinch, &GestureKeys.pinchKey) as? _GestureActionBox)?.action
            let composed: jobsByGRBlock = { gr in
                oldAction?(gr)
                action(gr)
            }
            objc_setAssociatedObject(
                pinch,
                &GestureKeys.pinchKey,
                _GestureActionBox(composed),
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            return self
        };return addPinchAction(action)
    }
    /// 旧接口兼容
    @discardableResult
    public func addPinchAction(_ action: @escaping jobsByVoidBlock) -> Self {
        addPinchAction { _ in action() }
    }
    /// ✅ Pinch 事件叠加：无参数版本
    @discardableResult
    public func addPinchActionAppend(_ action: @escaping jobsByVoidBlock) -> Self {
        addPinchActionAppend { _ in action() }
    }
    public func removePinchAction() {
        if let g = objc_getAssociatedObject(self, &GestureKeys.pinchKey) as? UIPinchGestureRecognizer {
            removeGestureRecognizer(g)
        };objc_setAssociatedObject(
            self,
            &GestureKeys.pinchKey,
            nil,
            .OBJC_ASSOCIATION_ASSIGN)
    }
    // MARK: - Rotation（旋转）
    @discardableResult
    public func addRotationAction(_ action: @escaping jobsByGRBlock) -> Self {
        isUserInteractionEnabled = true
        if let old = objc_getAssociatedObject(self, &GestureKeys.rotateKey) as? UIRotationGestureRecognizer {
            removeGestureRecognizer(old)
        }
        let rotate = jobs_addGesture(UIRotationGestureRecognizer
            .byConfig { _ in }
            .byOnRotationChange { sender, r in
                (objc_getAssociatedObject(sender, &GestureKeys.rotateKey) as? _GestureActionBox)?.action(sender)
            })!
        objc_setAssociatedObject(
            self,
            &GestureKeys.rotateKey,
            rotate,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        objc_setAssociatedObject(
            rotate,
            &GestureKeys.rotateKey,
            _GestureActionBox(action),
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        return self
    }
    /// ✅ Rotation 事件叠加：在既有 Rotation 动作后继续追加
    @discardableResult
    public func addRotationActionAppend(_ action: @escaping jobsByGRBlock) -> Self {
        isUserInteractionEnabled = true
        if let rotate = objc_getAssociatedObject(self, &GestureKeys.rotateKey) as? UIRotationGestureRecognizer {
            let oldAction = (objc_getAssociatedObject(rotate, &GestureKeys.rotateKey) as? _GestureActionBox)?.action
            let composed: jobsByGRBlock = { gr in
                oldAction?(gr)
                action(gr)
            }
            objc_setAssociatedObject(
                rotate,
                &GestureKeys.rotateKey,
                _GestureActionBox(composed),
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            return self
        };return addRotationAction(action)
    }
    /// 旧接口兼容
    @discardableResult
    public func addRotationAction(_ action: @escaping jobsByVoidBlock) -> Self {
        addRotationAction { _ in action() }
    }
    /// ✅ Rotation 事件叠加：无参数版本
    @discardableResult
    public func addRotationActionAppend(_ action: @escaping jobsByVoidBlock) -> Self {
        addRotationActionAppend { _ in action() }
    }
    @objc
    private func _gestureHandleRotate(_ sender: UIRotationGestureRecognizer) {
        (objc_getAssociatedObject(sender, &GestureKeys.rotateKey) as? _GestureActionBox)?.action(sender)
    }
    public func removeRotationAction() {
        if let g = objc_getAssociatedObject(self, &GestureKeys.rotateKey) as? UIRotationGestureRecognizer {
            removeGestureRecognizer(g)
        };objc_setAssociatedObject(
            self,
            &GestureKeys.rotateKey,
            nil,
            .OBJC_ASSOCIATION_ASSIGN)
    }
    // MARK: - 便利方法：一次性清理
    public func removeAllGestureActions() {
        removeTapAction()
        removeLongPressAction()
        removePanAction()
        removeSwipeAction()
        removePinchAction()
        removeRotationAction()
    }
}
/**
     // 同一 view 上同时添加四个方向的 swipe
     let idL = view.addSwipeActionMulti(direction: .left)  { gr in print("←") }
     let idR = view.addSwipeActionMulti(direction: .right) { gr in print("→") }
     let idU = view.addSwipeActionMulti(direction: .up)    { gr in print("↑") }
     let idD = view.addSwipeActionMulti(direction: .down)  { gr in print("↓") }

     // 指定 id，方便链式与管理
     view.addSwipeActionMulti(use: "swipe.left", direction: .left) { _ in }
         .addSwipeActionMulti(use: "swipe.right", direction: .right) { _ in }

     // 精确移除某一个
     view.removeSwipeActionMulti(id: idL)
     // 或批量移除该类手势
     view.removeAllSwipeActionsMulti()
 */
// MARK: - 多个方向的 swipe 并存
extension UIView {
    // 为每种手势维护一个 “id -> gesture” 的字典
    private struct GestureMultiKeys {
        static var tapMap:    UInt8 = 0
        static var longMap:   UInt8 = 0
        static var panMap:    UInt8 = 0
        static var swipeMap:  UInt8 = 0
        static var pinchMap:  UInt8 = 0
        static var rotateMap: UInt8 = 0
    }
    // 取/存 通用 map（view 维度）
    private func _grMap(for key: UnsafeRawPointer) -> [String: UIGestureRecognizer] {
        (objc_getAssociatedObject(self, key) as? [String: UIGestureRecognizer]) ?? [:]
    }
    private func _setGrMap(_ map: [String: UIGestureRecognizer], for key: UnsafeRawPointer) {
        objc_setAssociatedObject(
            self,
            key,
            map,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }
    // MARK: - Tap（多实例）
    /// 返回生成的 id（便于后续精确移除）
    @discardableResult
    public func addTapActionMulti(
            id: String = UUID().uuidString,
            taps: Int = 1,
            cancelsTouchesInView: Bool = true,
            requiresExclusiveTouchType: Bool = false,
            _ action: @escaping jobsByGRBlock
    ) -> String {
        isUserInteractionEnabled = true
        var map = _grMap(for: &GestureMultiKeys.tapMap)
        // 如果同 id 已存在，先移除再覆盖
        if let old = map[id] as? UITapGestureRecognizer { removeGestureRecognizer(old) }
        let gr = jobs_addGesture(
            UITapGestureRecognizer
                .byConfig { gr in
                    (objc_getAssociatedObject(gr, &GestureKeys.tapKey) as? _GestureActionBox)?.action(gr)
                    print("Tap 触发 on: \(String(describing: gr.view))")
                }
                .byTaps(taps)                       // 双击
                .byTouches(1)                       // 单指
                .byCancelsTouchesInView(cancelsTouchesInView)
                .byRequiresExclusiveTouchType(requiresExclusiveTouchType)
                .byEnabled(true)
                .byName("customTap"))!
        // 复用单实例版里“gesture -> box”的关联键（每个 recognizer 独立存一份）
        objc_setAssociatedObject(gr, &GestureKeys.tapKey, _GestureActionBox(action), .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        map[id] = gr
        _setGrMap(map, for: &GestureMultiKeys.tapMap)
        return id
    }
    /// 提供一个便于链式的重载：自己指定 id，可继续链式
    @discardableResult
    public func addTapActionMulti(
            use id: String,
            taps: Int = 1,
            cancelsTouchesInView: Bool = true,
            requiresExclusiveTouchType: Bool = false,
            _ action: @escaping jobsByGRBlock
    ) -> Self {
        _ = addTapActionMulti(
            id: id,
            taps: taps,
            cancelsTouchesInView: cancelsTouchesInView,
            requiresExclusiveTouchType: requiresExclusiveTouchType, action)
        return self
    }

    public func removeTapActionMulti(id: String) {
        var map = _grMap(for: &GestureMultiKeys.tapMap)
        if let g = map[id] {
            removeGestureRecognizer(g)
            map.removeValue(forKey: id)
            _setGrMap(map, for: &GestureMultiKeys.tapMap)
        }
    }
    public func removeAllTapActionsMulti() {
        var map = _grMap(for: &GestureMultiKeys.tapMap)
        map.values.forEach { removeGestureRecognizer($0) }
        map.removeAll()
        _setGrMap(map, for: &GestureMultiKeys.tapMap)
    }
    // MARK: - LongPress（多实例）
    @discardableResult
    public func addLongPressActionMulti(
        id: String = UUID().uuidString,
        minimumPressDuration: TimeInterval = 0.5,
        allowableMovement: CGFloat = 10,
        numberOfTouchesRequired: Int = 1,
        _ action: @escaping jobsByGRBlock
    ) -> String {
        isUserInteractionEnabled = true
        var map = _grMap(for: &GestureMultiKeys.longMap)
        if let old = map[id] as? UILongPressGestureRecognizer { removeGestureRecognizer(old) }
        let gr = jobs_addGesture(UILongPressGestureRecognizer
            .byConfig { gr in
                (objc_getAssociatedObject(gr, &GestureKeys.longKey) as? _GestureActionBox)?.action(gr)
            }
            .byMinDuration(minimumPressDuration)              // 最小按压时长
            .byMovement(allowableMovement)                    // 允许移动距离
            .byTouches(numberOfTouchesRequired)               // 单指
        )!
        objc_setAssociatedObject(
            gr,
            &GestureKeys.longKey,
            _GestureActionBox(action),
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        map[id] = gr
        _setGrMap(map, for: &GestureMultiKeys.longMap)
        return id
    }

    @discardableResult
    public func addLongPressActionMulti(
            use id: String,
            minimumPressDuration: TimeInterval = 0.5,
            allowableMovement: CGFloat = 10,
            numberOfTouchesRequired: Int = 1,
            _ action: @escaping jobsByGRBlock
    ) -> Self {
        _ = addLongPressActionMulti(
            id: id,
            minimumPressDuration: minimumPressDuration,
            allowableMovement: allowableMovement,
            numberOfTouchesRequired: numberOfTouchesRequired,
            action);return self
    }

    public func removeLongPressActionMulti(id: String) {
        var map = _grMap(for: &GestureMultiKeys.longMap)
        if let g = map[id] {
            removeGestureRecognizer(g); map.removeValue(forKey: id)
            _setGrMap(map, for: &GestureMultiKeys.longMap)
        }
    }

    public func removeAllLongPressActionsMulti() {
        var map = _grMap(for: &GestureMultiKeys.longMap)
        map.values.forEach { removeGestureRecognizer($0) }
        map.removeAll(); _setGrMap(map, for: &GestureMultiKeys.longMap)
    }
    // MARK: - Pan（多实例）
    @discardableResult
    public func addPanActionMulti(
        id: String = UUID().uuidString,
        minimumNumberOfTouches: Int = 1,
        maximumNumberOfTouches: Int = Int.max,
        _ action: @escaping jobsByGRBlock
    ) -> String {
        isUserInteractionEnabled = true
        var map = _grMap(for: &GestureMultiKeys.panMap)
        if let old = map[id] as? UIPanGestureRecognizer { removeGestureRecognizer(old) }
        let gr = jobs_addGesture(UIPanGestureRecognizer
            .byConfig { sender in
                (objc_getAssociatedObject(sender, &GestureKeys.panKey) as? _GestureActionBox)?.action(sender)
            }
            .byMinTouches(minimumNumberOfTouches)
            .byMaxTouches(maximumNumberOfTouches)
            .byCancelsTouchesInView(true))!
        objc_setAssociatedObject(
            gr,
            &GestureKeys.panKey,
            _GestureActionBox(action),
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
        map[id] = gr
        _setGrMap(map, for: &GestureMultiKeys.panMap)
        return id
    }

    @discardableResult
    public func addPanActionMulti(
        use id: String,
        minimumNumberOfTouches: Int = 1,
        maximumNumberOfTouches: Int = Int.max,
        _ action: @escaping jobsByGRBlock
    ) -> Self {
        _ = addPanActionMulti(
            id: id,
            minimumNumberOfTouches: minimumNumberOfTouches,
            maximumNumberOfTouches: maximumNumberOfTouches,
            action);return self
    }

    public func removePanActionMulti(id: String) {
        var map = _grMap(for: &GestureMultiKeys.panMap)
        if let g = map[id] {
            removeGestureRecognizer(g); map.removeValue(forKey: id)
            _setGrMap(map, for: &GestureMultiKeys.panMap)
        }
    }

    public func removeAllPanActionsMulti() {
        var map = _grMap(for: &GestureMultiKeys.panMap)
        map.values.forEach { removeGestureRecognizer($0) }
        map.removeAll(); _setGrMap(map, for: &GestureMultiKeys.panMap)
    }
    // MARK: - Swipe（多实例）
    @discardableResult
    public func addSwipeActionMulti(
        id: String = UUID().uuidString,
        direction: UISwipeGestureRecognizer.Direction = .right,
        numberOfTouchesRequired: Int = 1,
        _ action: @escaping jobsByGRBlock
    ) -> String {
        isUserInteractionEnabled = true
        var map = _grMap(for: &GestureMultiKeys.swipeMap)
        if let old = map[id] as? UISwipeGestureRecognizer { removeGestureRecognizer(old) }
        let gr = jobs_addGesture(UISwipeGestureRecognizer
            .byConfig { sender in
                print("👉 右滑触发")
                (objc_getAssociatedObject(sender, &GestureKeys.swipeKey) as? _GestureActionBox)?.action(sender)
            }
            .byDirection(direction)
            .byTouches(numberOfTouchesRequired))!
        objc_setAssociatedObject(
            gr,
            &GestureKeys.swipeKey,
            _GestureActionBox(action),
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        map[id] = gr
        _setGrMap(map, for: &GestureMultiKeys.swipeMap)
        return id
    }

    @discardableResult
    public func addSwipeActionMulti(
        use id: String,
        direction: UISwipeGestureRecognizer.Direction = .right,
        numberOfTouchesRequired: Int = 1,
        _ action: @escaping jobsByGRBlock
    ) -> Self {
        _ = addSwipeActionMulti(
            id: id,
            direction: direction,
            numberOfTouchesRequired: numberOfTouchesRequired,
            action);return self
    }

    public func removeSwipeActionMulti(id: String) {
        var map = _grMap(for: &GestureMultiKeys.swipeMap)
        if let g = map[id] {
            removeGestureRecognizer(g); map.removeValue(forKey: id)
            _setGrMap(map, for: &GestureMultiKeys.swipeMap)
        }
    }

    public func removeAllSwipeActionsMulti() {
        var map = _grMap(for: &GestureMultiKeys.swipeMap)
        map.values.forEach { removeGestureRecognizer($0) }
        map.removeAll(); _setGrMap(map, for: &GestureMultiKeys.swipeMap)
    }
    // MARK: - Pinch（多实例）
    @discardableResult
    public func addPinchActionMulti(
            id: String = UUID().uuidString,
            _ action: @escaping jobsByGRBlock
    ) -> String {
        isUserInteractionEnabled = true
        var map = _grMap(for: &GestureMultiKeys.pinchMap)
        if let old = map[id] as? UIPinchGestureRecognizer { removeGestureRecognizer(old) }
        let gr = jobs_addGesture(UIPinchGestureRecognizer
            .byConfig { _ in }
            .byOnScaleChange { sender, scale in
                (objc_getAssociatedObject(sender, &GestureKeys.pinchKey) as? _GestureActionBox)?.action(sender)
            }
        )!
        objc_setAssociatedObject(
            gr,
            &GestureKeys.pinchKey,
            _GestureActionBox(action),
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        map[id] = gr
        _setGrMap(map, for: &GestureMultiKeys.pinchMap)
        return id
    }
    @discardableResult
    public func addPinchActionMulti(use id: String, _ action: @escaping jobsByGRBlock) -> Self {
        _ = addPinchActionMulti(id: id, action)
        return self
    }
    public func removePinchActionMulti(id: String) {
        var map = _grMap(for: &GestureMultiKeys.pinchMap)
        if let g = map[id] {
            removeGestureRecognizer(g); map.removeValue(forKey: id)
            _setGrMap(map, for: &GestureMultiKeys.pinchMap)
        }
    }
    public func removeAllPinchActionsMulti() {
        var map = _grMap(for: &GestureMultiKeys.pinchMap)
        map.values.forEach { removeGestureRecognizer($0) }
        map.removeAll(); _setGrMap(map, for: &GestureMultiKeys.pinchMap)
    }
    // MARK: - Rotation（多实例）
    @discardableResult
    public func addRotationActionMulti(
        id: String = UUID().uuidString,
        _ action: @escaping jobsByGRBlock
    ) -> String {
        isUserInteractionEnabled = true
        var map = _grMap(for: &GestureMultiKeys.rotateMap)
        if let old = map[id] as? UIRotationGestureRecognizer { removeGestureRecognizer(old) }
        let gr = UIRotationGestureRecognizer(target: self, action: #selector(_gestureHandleRotate(_:)))
        addGestureRecognizer(gr)
        objc_setAssociatedObject(
            gr,
            &GestureKeys.rotateKey,
            _GestureActionBox(action),
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        map[id] = gr
        _setGrMap(map, for: &GestureMultiKeys.rotateMap)
        return id
    }

    @discardableResult
    public func addRotationActionMulti(use id: String, _ action: @escaping jobsByGRBlock) -> Self {
        _ = addRotationActionMulti(id: id, action)
        return self
    }

    public func removeRotationActionMulti(id: String) {
        var map = _grMap(for: &GestureMultiKeys.rotateMap)
        if let g = map[id] {
            removeGestureRecognizer(g); map.removeValue(forKey: id)
            _setGrMap(map, for: &GestureMultiKeys.rotateMap)
        }
    }

    public func removeAllRotationActionsMulti() {
        var map = _grMap(for: &GestureMultiKeys.rotateMap)
        map.values.forEach { removeGestureRecognizer($0) }
        map.removeAll(); _setGrMap(map, for: &GestureMultiKeys.rotateMap)
    }
}
