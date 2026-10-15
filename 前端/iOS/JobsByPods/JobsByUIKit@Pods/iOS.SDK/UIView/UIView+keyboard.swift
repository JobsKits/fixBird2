//
//  UIView+keyboard.swift
//  JobsByUIKit
//
//  Created by Jobs on 2026年5月13日，星期三.
//

#if os(OSX)
import AppKit
#elseif os(iOS) || os(tvOS)
import UIKit
#endif

import RxSwift
import RxCocoa
import NSObject_Rx

// MARK: - UIView.keyboardHeight (Observable<CGFloat>)

#if canImport(RxSwift) && canImport(RxCocoa)
import RxSwift
import RxCocoa
private var kKeyboardHeightKey: UInt8 = 0
public extension UIView {
    /// 监听当前视图所处界面的键盘可见高度（单位：pt）
    /// - 说明：
    ///   - 当键盘显示/隐藏/高度变化时发出事件
    ///   - 已扣除 `safeAreaInsets.bottom`，拿到的是“真实遮挡高度”
    ///   - 已做去重（distinctUntilChanged）与主线程派发
    var keyboardHeight: Observable<CGFloat> {
        // 缓存：确保同一视图多次访问用同一个 Observable
        if let cached = objc_getAssociatedObject(self, &kKeyboardHeightKey) as? Observable<CGFloat> {
            return cached
        }
        // 通知源
        let willShow  = NotificationCenter.default.rx.notification(UIResponder.keyboardWillShowNotification)
        let willHide  = NotificationCenter.default.rx.notification(UIResponder.keyboardWillHideNotification)
        let willChangeFrame = NotificationCenter.default.rx.notification(UIResponder.keyboardWillChangeFrameNotification)
        // 统一拿键盘 endFrame → 计算与当前视图的遮挡高度
        func height(from note: Notification) -> CGFloat {
            guard let frame = note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else {
                return 0
            }
            // 键盘是屏幕坐标，这里转到当前视图的坐标系，计算遮挡
            let window = UIApplication.jobsKeyWindow()
            let endInView: CGRect = {
                if let win = window {
                    let rInWin = win.convert(frame, from: nil)
                    return self.convert(rInWin, from: win)
                } else {
                    // 没有 window 时退化处理
                    return self.convert(frame, from: nil)
                }
            }()
            // 视图底部到键盘顶部的重叠高度
            let overlap = max(0, self.bounds.maxY - endInView.minY)
            // 扣除底部安全区，得到真正需要上移/留白的高度
            let adjusted = max(0, overlap - self.safeAreaInsets.bottom)
            return adjusted.rounded(.towardZero) // 避免细微浮点波动
        }
        // 三类事件合并：
        // - show / changeFrame：计算高度
        // - hide：高度归零
        let showOrChange = Observable
            .merge(willShow, willChangeFrame)
            .map { height(from: $0) }
        let hide = willHide
            .map { _ in CGFloat(0) }
        let stream = Observable
            .merge(showOrChange, hide)
            .distinctUntilChanged()
            .observe(on: MainScheduler.instance)
            // 保证多订阅者共享一个上游订阅；最后一个订阅者取消后自动释放
            .share(replay: 1, scope: .whileConnected)
        objc_setAssociatedObject(self, &kKeyboardHeightKey, stream, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        return stream
    }
}
#endif
