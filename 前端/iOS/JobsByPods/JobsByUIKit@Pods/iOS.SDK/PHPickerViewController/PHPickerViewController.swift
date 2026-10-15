//
//  PHPickerViewController.swift
//  JobsByUIKit
//
//  Created by Jobs on 2026年5月13日，星期三.
//

#if os(OSX)
import AppKit
#elseif os(iOS) || os(tvOS)
import UIKit
#endif

import PhotosUI
import ObjectiveC

// MARK: - DSL
@available(iOS 14, *)
extension PHPickerViewController {
    @discardableResult
    public func byTarget(_ target: AnyObject) -> Self {
        let p = jobs_phpickerBlocksProxy()!
        p.target = target
        delegate = p
        return self
    }

    @discardableResult
    public func didFinishPicking(_ block: @escaping (AnyObject,
                                                    PHPickerViewController,
                                                    [PHPickerResult]) -> Void) -> Self {
        jobs_phpickerBlocksProxy()?.didFinishPicking = block
        return self
    }
}
// MARK: - Proxy
@available(iOS 14, *)
private final class JobsPHPickerBlocksProxy: NSObject, PHPickerViewControllerDelegate {
    weak var target: AnyObject?
    var didFinishPicking: ((AnyObject,
                            PHPickerViewController,
                            [PHPickerResult]) -> Void)?
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        guard let t = target else { return }
        didFinishPicking?(t, picker, results)
    }
}
// MARK: - Associated
private var proxyPHPickerVCKey: UInt8 = 0
@available(iOS 14, *)
extension PHPickerViewController {
    private func jobs_phpickerBlocksProxy(createIfNeeded: Bool = true) -> JobsPHPickerBlocksProxy? {
        if let p = objc_getAssociatedObject(self, &proxyPHPickerVCKey) as? JobsPHPickerBlocksProxy {
            return p
        }
        guard createIfNeeded else { return nil }
        let p = JobsPHPickerBlocksProxy()
        objc_setAssociatedObject(
            self,
            &proxyPHPickerVCKey,
            p,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        );return p
    }
}
