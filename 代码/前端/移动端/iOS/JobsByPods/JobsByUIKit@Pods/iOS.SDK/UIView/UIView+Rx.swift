//
//  UIView+Rx.swift
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
import RxSwift
import RxCocoa
import NSObject_Rx

extension Reactive where Base: UIView {
    /// 监听键盘高度变化（0 = 隐藏）
    var keyboardHeight: Observable<CGFloat> {
        let willShow = NotificationCenter.default.rx.notification(UIResponder.keyboardWillShowNotification)
            .compactMap { $0.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect }
            .map { $0.height }
        let willHide = NotificationCenter.default.rx.notification(UIResponder.keyboardWillHideNotification)
            .map { _ in CGFloat(0) };return Observable.merge(willShow, willHide)
            .distinctUntilChanged()
            .observe(on: MainScheduler.instance)
    }
}
