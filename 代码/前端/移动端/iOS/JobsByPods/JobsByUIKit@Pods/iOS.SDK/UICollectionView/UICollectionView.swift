//
//  UICollectionView.swift
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

// MARK: - DSL
extension UICollectionView {
    @discardableResult
    public func byTarget(_ target: AnyObject) -> Self {
        let p = jobs_blocksProxy()!
        p.target = target
        dataSource = p
        // 关键：delegate 改用 mux，scroll delegate 交给 UIScrollViewBlocksProxy
        byScrollTarget(target)
        jobs_setDelegateMuxIfNeeded(primary: p)
        return self
    }
    // MARK: - UICollectionViewDataSource
    @discardableResult
    public func numberOfSections(_ block: @escaping (AnyObject, UICollectionView) -> Int) -> Self {
        jobs_blocksProxy()?.numberOfSections = block
        return self
    }

    @discardableResult
    public func numberOfItemsInSection(_ block: @escaping (AnyObject,
                                                           UICollectionView,
                                                           Int) -> Int) -> Self {
        jobs_blocksProxy()?.numberOfItemsInSection = block
        return self
    }

    @discardableResult
    public func cellForItemAt(_ block: @escaping (AnyObject,
                                                  UICollectionView,
                                                  IndexPath) -> UICollectionViewCell) -> Self {
        jobs_blocksProxy()?.cellForItemAt = block
        return self
    }

    @discardableResult
    public func viewForSupplementaryElementOfKind(_ block: @escaping (AnyObject,
                                                                      UICollectionView,
                                                                      String,
                                                                      IndexPath) -> UICollectionReusableView) -> Self {
        jobs_blocksProxy()?.viewForSupplementaryElementOfKind = block
        return self
    }
    // MARK: - UICollectionViewDelegate
    @discardableResult
    public func didSelectItemAt(_ block: @escaping (AnyObject,
                                                    UICollectionView,
                                                    IndexPath) -> Void) -> Self {
        jobs_blocksProxy()?.didSelectItemAt = block
        return self
    }

    @discardableResult
    public func didDeselectItemAt(_ block: @escaping (AnyObject,
                                                      UICollectionView,
                                                      IndexPath) -> Void) -> Self {
        jobs_blocksProxy()?.didDeselectItemAt = block
        return self
    }

    @discardableResult
    public func willDisplayCell(_ block: @escaping (AnyObject,
                                                    UICollectionView,
                                                    UICollectionViewCell,
                                                    IndexPath) -> Void) -> Self {
        jobs_blocksProxy()?.willDisplayCell = block
        return self
    }

    @discardableResult
    public func didEndDisplayingCell(_ block: @escaping (AnyObject,
                                                         UICollectionView,
                                                         UICollectionViewCell,
                                                         IndexPath) -> Void) -> Self {
        jobs_blocksProxy()?.didEndDisplayingCell = block
        if let p = jobs_blocksProxy(createIfNeeded: false) { jobs_setDelegateMuxIfNeeded(primary: p) };return self
    }
    // MARK: - UICollectionViewDelegateFlowLayout
    @discardableResult
    public func sizeForItemAt(_ block: @escaping (AnyObject,
                                                  UICollectionView,
                                                  UICollectionViewLayout,
                                                  IndexPath) -> CGSize) -> Self {
        jobs_blocksProxy()?.sizeForItemAt = block
        if let p = jobs_blocksProxy(createIfNeeded: false) { jobs_setDelegateMuxIfNeeded(primary: p) };return self
    }

    @discardableResult
    public func insetForSectionAt(_ block: @escaping (AnyObject,
                                                      UICollectionView,
                                                      UICollectionViewLayout,
                                                      Int) -> UIEdgeInsets) -> Self {
        jobs_blocksProxy()?.insetForSectionAt = block
        if let p = jobs_blocksProxy(createIfNeeded: false) { jobs_setDelegateMuxIfNeeded(primary: p) };return self
    }

    @discardableResult
    public func minimumLineSpacingForSectionAt(_ block: @escaping (AnyObject,
                                                                   UICollectionView,
                                                                   UICollectionViewLayout,
                                                                   Int) -> CGFloat) -> Self {
        jobs_blocksProxy()?.minimumLineSpacingForSectionAt = block
        if let p = jobs_blocksProxy(createIfNeeded: false) { jobs_setDelegateMuxIfNeeded(primary: p) };return self
    }

    @discardableResult
    public func minimumInteritemSpacingForSectionAt(_ block: @escaping (AnyObject,
                                                                        UICollectionView,
                                                                        UICollectionViewLayout,
                                                                        Int) -> CGFloat) -> Self {
        jobs_blocksProxy()?.minimumInteritemSpacingForSectionAt = block
        if let p = jobs_blocksProxy(createIfNeeded: false) { jobs_setDelegateMuxIfNeeded(primary: p) };return self
    }

    @discardableResult
    public func referenceSizeForHeaderInSection(_ block: @escaping (AnyObject,
                                                                    UICollectionView,
                                                                    UICollectionViewLayout,
                                                                    Int) -> CGSize) -> Self {
        jobs_blocksProxy()?.referenceSizeForHeaderInSection = block
        if let p = jobs_blocksProxy(createIfNeeded: false) { jobs_setDelegateMuxIfNeeded(primary: p) };return self
    }

    @discardableResult
    public func referenceSizeForFooterInSection(_ block: @escaping (AnyObject,
                                                                    UICollectionView,
                                                                    UICollectionViewLayout,
                                                                    Int) -> CGSize) -> Self {
        jobs_blocksProxy()?.referenceSizeForFooterInSection = block
        if let p = jobs_blocksProxy(createIfNeeded: false) { jobs_setDelegateMuxIfNeeded(primary: p) };return self
    }
    // MARK: - UICollectionViewDataSourcePrefetching
    @discardableResult
    public func prefetchItemsAt(_ block: @escaping (AnyObject,
                                                    UICollectionView,
                                                    [IndexPath]) -> Void) -> Self {
        let p = jobs_blocksProxy()!
        p.prefetchItemsAt = block
        prefetchDataSource = p
        return self
    }

    @discardableResult
    public func cancelPrefetchingForItemsAt(_ block: @escaping (AnyObject,
                                                                UICollectionView,
                                                                [IndexPath]) -> Void) -> Self {
        let p = jobs_blocksProxy()!
        p.cancelPrefetchingForItemsAt = block
        prefetchDataSource = p
        return self
    }
}
// MARK: - Proxy
private final class JobsCollectionViewBlocksProxy: NSObject,
                                                   UICollectionViewDataSource,
                                                   UICollectionViewDelegate,
                                                   UICollectionViewDelegateFlowLayout,
                                                   UICollectionViewDataSourcePrefetching {
    weak var target: AnyObject?
    // MARK: - UICollectionViewDataSource
    var numberOfSections: ((AnyObject, UICollectionView) -> Int)?
    var numberOfItemsInSection: ((AnyObject,
                                  UICollectionView,
                                  Int) -> Int)?
    var cellForItemAt: ((AnyObject,
                         UICollectionView,
                         IndexPath) -> UICollectionViewCell)?
    var viewForSupplementaryElementOfKind: ((AnyObject,
                                             UICollectionView,
                                             String,
                                             IndexPath) -> UICollectionReusableView)?

    func numberOfSections(in collectionView: UICollectionView) -> Int {
        guard let t = target else { return 1 };return numberOfSections?(t, collectionView) ?? 1
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        guard let t = target else { return 0 };return numberOfItemsInSection?(t, collectionView, section) ?? 0
    }

    func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let t = target else { return UICollectionViewCell() };return cellForItemAt?(t, collectionView, indexPath) ?? UICollectionViewCell()
    }

    func collectionView(_ collectionView: UICollectionView,
                        viewForSupplementaryElementOfKind kind: String,
                        at indexPath: IndexPath) -> UICollectionReusableView {
        guard let t = target else { return UICollectionReusableView() };return viewForSupplementaryElementOfKind?(t,
                                                  collectionView,
                                                  kind,
                                                  indexPath) ?? UICollectionReusableView()
    }
    // MARK: - UICollectionViewDelegate
    var didSelectItemAt: ((AnyObject,
                           UICollectionView,
                           IndexPath) -> Void)?
    var didDeselectItemAt: ((AnyObject,
                             UICollectionView,
                             IndexPath) -> Void)?
    var willDisplayCell: ((AnyObject,
                           UICollectionView,
                           UICollectionViewCell,
                           IndexPath) -> Void)?
    var didEndDisplayingCell: ((AnyObject,
                                UICollectionView,
                                UICollectionViewCell,
                                IndexPath) -> Void)?

    func collectionView(_ collectionView: UICollectionView,
                        didSelectItemAt indexPath: IndexPath) {
        guard let t = target else { return }
        didSelectItemAt?(t, collectionView, indexPath)
    }

    func collectionView(_ collectionView: UICollectionView,
                        didDeselectItemAt indexPath: IndexPath) {
        guard let t = target else { return }
        didDeselectItemAt?(t, collectionView, indexPath)
    }

    func collectionView(_ collectionView: UICollectionView,
                        willDisplay cell: UICollectionViewCell,
                        forItemAt indexPath: IndexPath) {
        guard let t = target else { return }
        willDisplayCell?(t, collectionView, cell, indexPath)
    }

    func collectionView(_ collectionView: UICollectionView,
                        didEndDisplaying cell: UICollectionViewCell,
                        forItemAt indexPath: IndexPath) {
        guard let t = target else { return }
        didEndDisplayingCell?(t, collectionView, cell, indexPath)
    }
    // MARK: - UICollectionViewDelegateFlowLayout
    var sizeForItemAt: ((AnyObject,
                         UICollectionView,
                         UICollectionViewLayout,
                         IndexPath) -> CGSize)?
    var insetForSectionAt: ((AnyObject,
                             UICollectionView,
                             UICollectionViewLayout,
                             Int) -> UIEdgeInsets)?
    var minimumLineSpacingForSectionAt: ((AnyObject,
                                          UICollectionView,
                                          UICollectionViewLayout,
                                          Int) -> CGFloat)?
    var minimumInteritemSpacingForSectionAt: ((AnyObject,
                                               UICollectionView,
                                               UICollectionViewLayout,
                                               Int) -> CGFloat)?
    var referenceSizeForHeaderInSection: ((AnyObject,
                                           UICollectionView,
                                           UICollectionViewLayout,
                                           Int) -> CGSize)?
    var referenceSizeForFooterInSection: ((AnyObject,
                                           UICollectionView,
                                           UICollectionViewLayout,
                                           Int) -> CGSize)?

    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        guard let t = target else { return (collectionViewLayout as? UICollectionViewFlowLayout)?.itemSize ?? .zero };return sizeForItemAt?(t, collectionView, collectionViewLayout, indexPath)
        ?? (collectionViewLayout as? UICollectionViewFlowLayout)?.itemSize
        ?? .zero
    }

    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        insetForSectionAt section: Int) -> UIEdgeInsets {
        guard let t = target else { return (collectionViewLayout as? UICollectionViewFlowLayout)?.sectionInset ?? .zero };return insetForSectionAt?(t, collectionView, collectionViewLayout, section)
        ?? (collectionViewLayout as? UICollectionViewFlowLayout)?.sectionInset
        ?? .zero
    }

    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        guard let t = target else { return (collectionViewLayout as? UICollectionViewFlowLayout)?.minimumLineSpacing ?? 0 };return minimumLineSpacingForSectionAt?(t, collectionView, collectionViewLayout, section)
        ?? (collectionViewLayout as? UICollectionViewFlowLayout)?.minimumLineSpacing
        ?? 0
    }

    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        guard let t = target else { return (collectionViewLayout as? UICollectionViewFlowLayout)?.minimumInteritemSpacing ?? 0 };return minimumInteritemSpacingForSectionAt?(t, collectionView, collectionViewLayout, section)
        ?? (collectionViewLayout as? UICollectionViewFlowLayout)?.minimumInteritemSpacing
        ?? 0
    }

    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        referenceSizeForHeaderInSection section: Int) -> CGSize {
        guard let t = target else { return (collectionViewLayout as? UICollectionViewFlowLayout)?.headerReferenceSize ?? .zero };return referenceSizeForHeaderInSection?(t, collectionView, collectionViewLayout, section)
        ?? (collectionViewLayout as? UICollectionViewFlowLayout)?.headerReferenceSize
        ?? .zero
    }

    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        referenceSizeForFooterInSection section: Int) -> CGSize {
        guard let t = target else { return (collectionViewLayout as? UICollectionViewFlowLayout)?.footerReferenceSize ?? .zero };return referenceSizeForFooterInSection?(t, collectionView, collectionViewLayout, section)
        ?? (collectionViewLayout as? UICollectionViewFlowLayout)?.footerReferenceSize
        ?? .zero
    }

    // MARK: - UICollectionViewDataSourcePrefetching
    var prefetchItemsAt: ((AnyObject,
                           UICollectionView,
                           [IndexPath]) -> Void)?
    var cancelPrefetchingForItemsAt: ((AnyObject,
                                       UICollectionView,
                                       [IndexPath]) -> Void)?

    func collectionView(_ collectionView: UICollectionView, prefetchItemsAt indexPaths: [IndexPath]) {
        guard let t = target else { return }
        prefetchItemsAt?(t, collectionView, indexPaths)
    }

    func collectionView(_ collectionView: UICollectionView, cancelPrefetchingForItemsAt indexPaths: [IndexPath]) {
        guard let t = target else { return }
        cancelPrefetchingForItemsAt?(t, collectionView, indexPaths)
    }
}
// MARK: - Associated
private enum JobsCollectionViewBlocksAssociatedKeys {
    static var proxyKey = "jobs.collectionview.blocks.proxy.key"
}

extension UICollectionView {
     private func jobs_blocksProxy(createIfNeeded: Bool = true) -> JobsCollectionViewBlocksProxy? {
        if let p = objc_getAssociatedObject(self, &JobsCollectionViewBlocksAssociatedKeys.proxyKey) as? JobsCollectionViewBlocksProxy {
            return p
        }
        guard createIfNeeded else { return nil }
        let p = JobsCollectionViewBlocksProxy()
        objc_setAssociatedObject(self, &JobsCollectionViewBlocksAssociatedKeys.proxyKey, p, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        return p
    }
}
// MARK: - Delegate Mux (Hard Defense)
private struct JobsCollectionViewDelegateMuxAssociatedKeys {
    static var muxKey: UInt8 = 0
}
/// 代理合并器：primary 负责 blocks 回调；secondary 保留外部 delegate（例如 refresh/埋点/scroll 监听）
final class JobsCollectionViewDelegateMux: NSObject,
                                           UICollectionViewDelegate,
                                           UICollectionViewDelegateFlowLayout {
    weak var primary: NSObjectProtocol?
    weak var secondary: NSObjectProtocol?

    override func responds(to aSelector: Selector!) -> Bool {
        if super.responds(to: aSelector) { return true }
        if let p = primary, (p as AnyObject).responds(to: aSelector) { return true }
        if let s = secondary, (s as AnyObject).responds(to: aSelector) { return true };return false
    }

    override func forwardingTarget(for aSelector: Selector!) -> Any? {
        if let p = primary, (p as AnyObject).responds(to: aSelector) { return p }
        if let s = secondary, (s as AnyObject).responds(to: aSelector) { return s };return super.forwardingTarget(for: aSelector)
    }

    override func conforms(to aProtocol: Protocol) -> Bool {
        if super.conforms(to: aProtocol) { return true }
        if let p = primary, (p as AnyObject).conforms(to: aProtocol) { return true }
        if let s = secondary, (s as AnyObject).conforms(to: aProtocol) { return true };return false
    }
}

extension UICollectionView {
    // MARK: Swizzle setDelegate: for hard defense
    private static let jobs_swizzleDelegateOnce: Void = {
        let cls: AnyClass = UICollectionView.self
        let originalSelector = #selector(setter: UICollectionView.delegate)
        let swizzledSelector = #selector(UICollectionView.jobs_setDelegate_swizzled(_:))
        guard
            let originalMethod = class_getInstanceMethod(cls, originalSelector),
            let swizzledMethod = class_getInstanceMethod(cls, swizzledSelector)
        else { return }
        method_exchangeImplementations(originalMethod, swizzledMethod)
    }()
    /// 开启“硬防覆盖”：任何外部 set delegate 都会被捕获并塞回 mux.secondary，然后把 mux 抢回 delegate
    private func jobs_enableDelegateHardDefense() {
        _ = UICollectionView.jobs_swizzleDelegateOnce
    }

    @objc private func jobs_setDelegate_swizzled(_ delegate: UICollectionViewDelegate?) {
        // 这里调用的是“原始 setDelegate:”（因为已经交换过实现）
        self.jobs_setDelegate_swizzled(delegate)
        // 如果当前 collectionView 安装了 mux，并且外部试图覆盖 delegate，则把外部 delegate 塞回 secondary，再把 mux 抢回
        if let mux = objc_getAssociatedObject(self, &JobsCollectionViewDelegateMuxAssociatedKeys.muxKey) as? JobsCollectionViewDelegateMux {
            if let d = delegate as AnyObject?, d !== mux {
                mux.secondary = delegate as? NSObjectProtocol
                self.jobs_setDelegate_swizzled(mux) // 再次调用原始 setter，把 mux 设置回去
            }
        }
    }
    /// 安装/更新 delegate mux：把 primary（blocks proxy）和当前 delegate 合并起来，并开启硬防覆盖
    fileprivate func jobs_setDelegateMuxIfNeeded(primary: NSObjectProtocol) {
        jobs_enableDelegateHardDefense()
        // 已经是 mux：只更新 primary，并尽量保持 secondary
        if let mux = objc_getAssociatedObject(self, &JobsCollectionViewDelegateMuxAssociatedKeys.muxKey) as? JobsCollectionViewDelegateMux {
            mux.primary = primary
            // 如果外部又覆盖了 delegate（不是 mux），把它塞回 secondary 再抢回来
            if let current = self.delegate as AnyObject?, current !== mux {
                mux.secondary = current as? NSObjectProtocol
                self.delegate = mux
            };return
        }
        let mux = JobsCollectionViewDelegateMux()
        mux.primary = primary
        // 把当前 delegate 作为 secondary（可能是 byScrollTarget / refresher / 其他库）
        if let current = self.delegate as AnyObject?, current !== mux {
            mux.secondary = current as? NSObjectProtocol
        }
        objc_setAssociatedObject(
            self,
            &JobsCollectionViewDelegateMuxAssociatedKeys.muxKey,
            mux,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        );self.delegate = mux
    }
}
