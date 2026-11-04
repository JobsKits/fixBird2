//
//  UIImagePickerController+Proxy.swift
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
import JobsSwiftDSL

extension UIImagePickerController {
    /// 只负责 UIImagePickerControllerDelegate 回调（nav 的闭包能力在 UINavigationController+Blocks.swift 里）
    /// 但 proxy 必须同时 conform UIImagePickerControllerDelegate & UINavigationControllerDelegate
    /// 因为 UIImagePickerController.delegate 的类型就是这两个协议的组合
    @discardableResult
    public func byTarget(_ target: AnyObject) -> Self {
        let p = jobs_imagePickerBlocksProxy()!
        p.target = target
        delegate = p
        return self
    }

    @discardableResult
    public func didFinishPickingMediaWithInfo(_ block: @escaping (AnyObject,
                                                                  UIImagePickerController,
                                                                  [UIImagePickerController.InfoKey: Any]) -> Void) -> Self {
        jobs_imagePickerBlocksProxy()?.didFinishPickingMediaWithInfo = block
        return self
    }

    @discardableResult
    public func didCancel(_ block: @escaping (AnyObject, UIImagePickerController) -> Void) -> Self {
        jobs_imagePickerBlocksProxy()?.didCancel = block
        return self
    }
}
// MARK: - Proxy
private final class JobsImagePickerBlocksProxy: NSObject,
                                                UIImagePickerControllerDelegate,
                                                UINavigationControllerDelegate {
    weak var target: AnyObject?
    var didFinishPickingMediaWithInfo: ((AnyObject,
                                         UIImagePickerController,
                                         [UIImagePickerController.InfoKey: Any]) -> Void)?

    var didCancel: ((AnyObject, UIImagePickerController) -> Void)?
    func imagePickerController(_ picker: UIImagePickerController,
                               didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        guard let t = target else { return }
        didFinishPickingMediaWithInfo?(t, picker, info)
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        guard let t = target else { return }
        didCancel?(t, picker)
    }
    // 不在这里提供 UINavigationControllerDelegate 的闭包 API
    // 如需 willShow/didShow/转场动画，请对 picker 自己（它是 UINavigationController 子类）调用：
    // picker.byNavTarget(self) ... （见 UINavigationController+Blocks.swift）
}
// MARK: - Associated
private var proxyImagePickerCtrlKey: UInt8 = 0
extension UIImagePickerController {
    private func jobs_imagePickerBlocksProxy(createIfNeeded: Bool = true) -> JobsImagePickerBlocksProxy? {
        if let p = objc_getAssociatedObject(self, &proxyImagePickerCtrlKey) as? JobsImagePickerBlocksProxy {
            return p
        }
        guard createIfNeeded else { return nil }
        let p = JobsImagePickerBlocksProxy()
        objc_setAssociatedObject(
            self,
            &proxyImagePickerCtrlKey,
            p,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        );return p
    }
}
