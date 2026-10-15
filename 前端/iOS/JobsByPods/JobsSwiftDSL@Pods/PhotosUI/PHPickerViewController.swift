//
//  PHPickerViewController.swift
//  JobsByPhotosUI
//
//  Created by Jobs on 2026年5月13日，星期三.
//

#if os(OSX)
import AppKit
#elseif os(iOS) || os(tvOS)
import UIKit
#endif

import PhotosUI

@available(iOS 14.0, *)
@available(watchOS, unavailable)
@available(tvOS, unavailable)
extension PHPickerViewController {
    // MARK: - Delegate
    /// 设置 `PHPickerViewControllerDelegate`
    ///
    /// 示例：
    /// ```swift
    /// let picker = PHPickerViewController(configuration: config)
    ///     .byDelegate(proxy)
    /// ```
    @discardableResult
    public func byDelegate(_ delegate: PHPickerViewControllerDelegate?) -> Self {
        self.delegate = delegate
        return self
    }
    // MARK: - Presentation
    /// 设置 `isModalInPresentation`
    ///
    /// `true` 时通常表示禁止下拉关闭。
    @discardableResult
    public func byIsModalInPresentation(_ value: Bool) -> Self {
        isModalInPresentation = value
        return self
    }
    /// 设置 `presentationController.delegate`
    ///
    /// 注意：
    /// - 一般要先让控制器进入展示流程后，`presentationController` 才一定存在
    /// - 若当前时机还未创建 `presentationController`，此调用不会生效
    @discardableResult
    public func byPresentationControllerDelegate(_ delegate: UIAdaptivePresentationControllerDelegate?) -> Self {
        presentationController?.delegate = delegate
        return self
    }
    // MARK: - Parent / Containment
    /// 添加为子控制器，并把 view 加到指定父视图
    ///
    /// 示例：
    /// ```swift
    /// picker.byAddTo(self, in: view)
    /// ```
    @discardableResult
    public func byAddTo(
        _ parent: UIViewController,
        in containerView: UIView
    ) -> Self {
        parent.addChild(self)
        containerView.addSubview(view)
        didMove(toParent: parent)
        return self
    }
    /// 添加为子控制器，并通过外部布局闭包处理 `view`
    ///
    /// 示例：
    /// ```swift
    /// picker.byAddTo(self) { picker in
    ///     picker.view.frame = self.view.bounds
    /// }
    /// ```
    @discardableResult
    public func byAddTo(
        _ parent: UIViewController,
        layout: (PHPickerViewController) -> Void
    ) -> Self {
        parent.addChild(self)
        parent.view.addSubview(view)
        layout(self)
        didMove(toParent: parent)
        return self
    }
    // MARK: - Present
    /// 由指定控制器 present 当前 picker
    @discardableResult
    public func byPresent(
        from presenter: UIViewController,
        animated: Bool = true,
        completion: (() -> Void)? = nil
    ) -> Self {
        presenter.present(self, animated: animated, completion: completion)
        return self
    }
    /// 若传入 presenter 不为空，则 present 当前 picker
    @discardableResult
    public func byPresent(
        from presenter: UIViewController?,
        animated: Bool = true,
        completion: (() -> Void)? = nil
    ) -> Self {
        guard let presenter else { return self }
        presenter.present(self, animated: animated, completion: completion)
        return self
    }
}
