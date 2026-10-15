//
//  UITableView.swift
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
import JobsSwiftBaseDefines

enum JobsTableViewBlocksAssociatedKeys {
    static var proxyKey: UInt8 = 0
    static var muxKey: UInt8 = 0
    static var didSwizzleKey: UInt8 = 0
    static var targetKey: UInt8 = 0
}
// MARK: - DSL
extension UITableView {
    /// 如果现有实现依赖“取回 target”
    public var jobs_target: AnyObject? {
        (objc_getAssociatedObject(self, &JobsTableViewBlocksAssociatedKeys.targetKey) as? AnyWeakBox)?.value
    }

    @discardableResult
    public func byTarget(_ target: AnyObject) -> Self {
        // 1) 保存 weak target（给其它地方取用，例如 scroll / mux 兜底）
        objc_setAssociatedObject(self,
                                 &JobsTableViewBlocksAssociatedKeys.targetKey,
                                 AnyWeakBox(target),
                                 .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        // 2) 安装 table blocks proxy（table 的 proxy.target 已经是 weak）
        let p = jobs_blocksProxy()!
        p.target = target
        dataSource = p
        // 3) 关键：scroll 相关 target 也要弱化，否则这里最容易形成环
        //    ✅ 如果你有 byScrollTargetWeak，就用它
        //    ❌ 如果没有，就必须去把 UIScrollView 的 blocksProxy.target 改成 weak
        byScrollTargetWeak(target)
        // 4) delegate 走 mux，避免外部覆盖 delegate 丢回调
        jobs_installDelegateMuxIfNeeded(primary: p)
        return self
    }
    // MARK: - UITableViewDataSource
    @discardableResult
    public func numberOfSections(_ block: @escaping (AnyObject, UITableView) -> Int) -> Self {
        jobs_blocksProxy()?.numberOfSections = block
        return self
    }

    @discardableResult
    public func numberOfRowsInSection(_ block: @escaping (AnyObject,
                                                          UITableView,
                                                          Int) -> Int) -> Self {
        jobs_blocksProxy()?.numberOfRowsInSection = block
        return self
    }

    @discardableResult
    public func cellForRowAt(_ block: @escaping (AnyObject,
                                                 UITableView,
                                                 IndexPath) -> UITableViewCell) -> Self {
        jobs_blocksProxy()?.cellForRowAt = block
        return self
    }

    @discardableResult
    public func titleForHeaderInSection(_ block: @escaping (AnyObject,
                                                            UITableView,
                                                            Int) -> String?) -> Self {
        jobs_blocksProxy()?.titleForHeaderInSection = block
        return self
    }

    @discardableResult
    public func titleForFooterInSection(_ block: @escaping (AnyObject,
                                                            UITableView,
                                                            Int) -> String?) -> Self {
        jobs_blocksProxy()?.titleForFooterInSection = block
        return self
    }

    @discardableResult
    public func canEditRowAt(_ block: @escaping (AnyObject,
                                                 UITableView,
                                                 IndexPath) -> Bool) -> Self {
        jobs_blocksProxy()?.canEditRowAt = block
        return self
    }

    @discardableResult
    public func canMoveRowAt(_ block: @escaping (AnyObject,
                                                 UITableView,
                                                 IndexPath) -> Bool) -> Self {
        jobs_blocksProxy()?.canMoveRowAt = block
        return self
    }

    @discardableResult
    public func sectionIndexTitles(_ block: @escaping (AnyObject, UITableView) -> [String]?) -> Self {
        jobs_blocksProxy()?.sectionIndexTitles = block
        return self
    }

    @discardableResult
    public func sectionForSectionIndexTitle(_ block: @escaping (AnyObject,
                                                                UITableView,
                                                                String, Int) -> Int) -> Self {
        jobs_blocksProxy()?.sectionForSectionIndexTitle = block
        return self
    }

    @discardableResult
    public func commitEditingStyle(_ block: @escaping (AnyObject,
                                                       UITableView,
                                                       UITableViewCell.EditingStyle,
                                                       IndexPath) -> Void) -> Self {
        jobs_blocksProxy()?.commitEditingStyle = block
        return self
    }

    @discardableResult
    public func moveRowAt(_ block: @escaping (AnyObject,
                                              UITableView,
                                              IndexPath,
                                              IndexPath) -> Void) -> Self {
        jobs_blocksProxy()?.moveRowAt = block
        return self
    }
    // MARK: - UITableViewDelegate
    @discardableResult
    public func willDisplay(_ block: @escaping (AnyObject,
                                                UITableView,
                                                UITableViewCell,
                                                IndexPath) -> Void) -> Self {
        jobs_blocksProxy()?.willDisplay = block
        if let p = jobs_blocksProxy(createIfNeeded: false) { jobs_installDelegateMuxIfNeeded(primary: p) };return self
    }

    @discardableResult
    public func didSelectRowAt(_ block: @escaping (AnyObject,
                                                   UITableView,
                                                   IndexPath) -> Void) -> Self {
        jobs_blocksProxy()?.didSelectRowAt = block
        if let p = jobs_blocksProxy(createIfNeeded: false) { jobs_installDelegateMuxIfNeeded(primary: p) };return self
    }

    @discardableResult
    public func didDeselectRowAt(_ block: @escaping (AnyObject,
                                                     UITableView,
                                                     IndexPath) -> Void) -> Self {
        jobs_blocksProxy()?.didDeselectRowAt = block
        if let p = jobs_blocksProxy(createIfNeeded: false) { jobs_installDelegateMuxIfNeeded(primary: p) };return self
    }

    @discardableResult
    public func heightForRowAt(_ block: @escaping (AnyObject,
                                                   UITableView,
                                                   IndexPath) -> CGFloat) -> Self {
        jobs_blocksProxy()?.heightForRowAt = block
        if let p = jobs_blocksProxy(createIfNeeded: false) { jobs_installDelegateMuxIfNeeded(primary: p) };return self
    }

    @discardableResult
    public func heightForHeaderInSection(_ block: @escaping (AnyObject,
                                                             UITableView,
                                                             Int) -> CGFloat) -> Self {
        jobs_blocksProxy()?.heightForHeaderInSection = block
        if let p = jobs_blocksProxy(createIfNeeded: false) { jobs_installDelegateMuxIfNeeded(primary: p) };return self
    }

    @discardableResult
    public func heightForFooterInSection(_ block: @escaping (AnyObject,
                                                             UITableView,
                                                             Int) -> CGFloat) -> Self {
        jobs_blocksProxy()?.heightForFooterInSection = block
        if let p = jobs_blocksProxy(createIfNeeded: false) { jobs_installDelegateMuxIfNeeded(primary: p) };return self
    }

    @discardableResult
    public func viewForHeaderInSection(_ block: @escaping (AnyObject,
                                                           UITableView,
                                                           Int) -> UIView?) -> Self {
        jobs_blocksProxy()?.viewForHeaderInSection = block
        if let p = jobs_blocksProxy(createIfNeeded: false) { jobs_installDelegateMuxIfNeeded(primary: p) };return self
    }

    @discardableResult
    public func viewForFooterInSection(_ block: @escaping (AnyObject,
                                                           UITableView,
                                                           Int) -> UIView?) -> Self {
        jobs_blocksProxy()?.viewForFooterInSection = block
        if let p = jobs_blocksProxy(createIfNeeded: false) { jobs_installDelegateMuxIfNeeded(primary: p) };return self
    }

    @discardableResult
    public func accessoryButtonTappedForRowWith(_ block: @escaping (AnyObject,
                                                                    UITableView,
                                                                    IndexPath) -> Void) -> Self {
        jobs_blocksProxy()?.accessoryButtonTappedForRowWith = block
        if let p = jobs_blocksProxy(createIfNeeded: false) { jobs_installDelegateMuxIfNeeded(primary: p) };return self
    }
    // MARK: - Private
    private func jobs_blocksProxy(createIfNeeded: Bool = true) -> JobsTableViewBlocksProxy? {
        if let p = objc_getAssociatedObject(self, &JobsTableViewBlocksAssociatedKeys.proxyKey) as? JobsTableViewBlocksProxy {
            return p
        }
        guard createIfNeeded else { return nil }
        let p = JobsTableViewBlocksProxy()
        objc_setAssociatedObject(
            self,
            &JobsTableViewBlocksAssociatedKeys.proxyKey,
            p,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        );return p
    }
    // MARK: - Delegate mux
    func jobs_installDelegateMuxIfNeeded(primary: JobsTableViewBlocksProxy) {
        jobs_swizzleSetDelegateIfNeeded()
        // 已经是 mux：只更新 primary，并尽量保持 secondary
        if let mux = objc_getAssociatedObject(self, &JobsTableViewBlocksAssociatedKeys.muxKey) as? JobsTableViewDelegateMux {
            mux.primary = primary
            // 如果外部又覆盖了 delegate（不是 mux），把它塞回 secondary 再抢回来
            if let current = self.delegate as AnyObject?, current !== mux {
                mux.secondary = current as? NSObjectProtocol
                self.delegate = mux
            };return
        }
        let mux = JobsTableViewDelegateMux()
        mux.primary = primary
        // 把当前 delegate 作为 secondary（可能是 byScrollTarget / refresher / 其他库）
        if let current = self.delegate as AnyObject?, current !== mux {
            mux.secondary = current as? NSObjectProtocol
        }
        objc_setAssociatedObject(self,
                                 &JobsTableViewBlocksAssociatedKeys.muxKey,
                                 mux,
                                 .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        self.delegate = mux
    }
    // MARK: - Hard protect delegate (swizzle setDelegate:)
    private func jobs_swizzleSetDelegateIfNeeded() {
        // Swizzle is class-wide; attach a flag to UITableView class object
        if objc_getAssociatedObject(UITableView.self, &JobsTableViewBlocksAssociatedKeys.didSwizzleKey) != nil {
            return
        }
        objc_setAssociatedObject(UITableView.self,
                                 &JobsTableViewBlocksAssociatedKeys.didSwizzleKey,
                                 true,
                                 .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        let cls: AnyClass = UITableView.self
        let original = #selector(setter: UITableView.delegate)
        let swizzled = #selector(UITableView.jobs_setDelegate(_:))
        guard
            let m1 = class_getInstanceMethod(cls, original),
            let m2 = class_getInstanceMethod(cls, swizzled)
        else { return }
        method_exchangeImplementations(m1, m2)
    }

    @objc private func jobs_setDelegate(_ delegate: UITableViewDelegate?) {
        // After swizzle: this method name points to original implementation.
        if let mux = objc_getAssociatedObject(self, &JobsTableViewBlocksAssociatedKeys.muxKey) as? JobsTableViewDelegateMux {
            if let d = delegate as AnyObject?, d !== mux {
                mux.secondary = d as? NSObjectProtocol
            } else if delegate == nil {
                mux.secondary = nil
            }
            // Always keep mux as the real delegate once installed
            self.jobs_setDelegate(mux)
            return
        }
        self.jobs_setDelegate(delegate)
    }
}
// MARK: - Blocks Proxy
class JobsTableViewBlocksProxy: NSObject, UITableViewDelegate, UITableViewDataSource {
    weak var target: AnyObject?
    // MARK: DataSource
    var numberOfSections: ((AnyObject, UITableView) -> Int)?
    var numberOfRowsInSection: ((AnyObject, UITableView, Int) -> Int)?
    var cellForRowAt: ((AnyObject, UITableView, IndexPath) -> UITableViewCell)?
    var titleForHeaderInSection: ((AnyObject, UITableView, Int) -> String?)?
    var titleForFooterInSection: ((AnyObject, UITableView, Int) -> String?)?
    var canEditRowAt: ((AnyObject, UITableView, IndexPath) -> Bool)?
    var canMoveRowAt: ((AnyObject, UITableView, IndexPath) -> Bool)?
    var sectionIndexTitles: ((AnyObject, UITableView) -> [String]?)?
    var sectionForSectionIndexTitle: ((AnyObject, UITableView, String, Int) -> Int)?
    var commitEditingStyle: ((AnyObject, UITableView, UITableViewCell.EditingStyle, IndexPath) -> Void)?
    var moveRowAt: ((AnyObject, UITableView, IndexPath, IndexPath) -> Void)?
    // MARK: Delegate
    var willDisplay: ((AnyObject, UITableView, UITableViewCell, IndexPath) -> Void)?
    var didSelectRowAt: ((AnyObject, UITableView, IndexPath) -> Void)?
    var didDeselectRowAt: ((AnyObject, UITableView, IndexPath) -> Void)?
    var heightForRowAt: ((AnyObject, UITableView, IndexPath) -> CGFloat)?
    var heightForHeaderInSection: ((AnyObject, UITableView, Int) -> CGFloat)?
    var heightForFooterInSection: ((AnyObject, UITableView, Int) -> CGFloat)?
    var viewForHeaderInSection: ((AnyObject, UITableView, Int) -> UIView?)?
    var viewForFooterInSection: ((AnyObject, UITableView, Int) -> UIView?)?
    var accessoryButtonTappedForRowWith: ((AnyObject, UITableView, IndexPath) -> Void)?
    // MARK: UITableViewDataSource
    func numberOfSections(in tableView: UITableView) -> Int {
        numberOfSections?(target ?? self, tableView) ?? 1
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        numberOfRowsInSection?(target ?? self, tableView, section) ?? 0
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        cellForRowAt?(target ?? self, tableView, indexPath) ?? UITableViewCell()
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        titleForHeaderInSection?(target ?? self, tableView, section)
    }

    func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        titleForFooterInSection?(target ?? self, tableView, section)
    }

    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        canEditRowAt?(target ?? self, tableView, indexPath) ?? false
    }

    func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        canMoveRowAt?(target ?? self, tableView, indexPath) ?? false
    }

    func sectionIndexTitles(for tableView: UITableView) -> [String]? {
        sectionIndexTitles?(target ?? self, tableView)
    }

    func tableView(_ tableView: UITableView,
                   sectionForSectionIndexTitle title: String,
                   at index: Int) -> Int {
        sectionForSectionIndexTitle?(target ?? self, tableView, title, index) ?? 0
    }

    func tableView(_ tableView: UITableView,
                   commit editingStyle: UITableViewCell.EditingStyle,
                   forRowAt indexPath: IndexPath) {
        commitEditingStyle?(target ?? self, tableView, editingStyle, indexPath)
    }

    func tableView(_ tableView: UITableView,
                   moveRowAt sourceIndexPath: IndexPath,
                   to destinationIndexPath: IndexPath) {
        moveRowAt?(target ?? self, tableView, sourceIndexPath, destinationIndexPath)
    }

    // MARK: UITableViewDelegate
    func tableView(_ tableView: UITableView,
                   willDisplay cell: UITableViewCell,
                   forRowAt indexPath: IndexPath) {
        willDisplay?(target ?? self, tableView, cell, indexPath)
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        didSelectRowAt?(target ?? self, tableView, indexPath)
    }

    func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        didDeselectRowAt?(target ?? self, tableView, indexPath)
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        heightForRowAt?(target ?? self, tableView, indexPath) ?? UITableView.automaticDimension
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        heightForHeaderInSection?(target ?? self, tableView, section) ?? UITableView.automaticDimension
    }

    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        heightForFooterInSection?(target ?? self, tableView, section) ?? UITableView.automaticDimension
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        viewForHeaderInSection?(target ?? self, tableView, section)
    }

    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        viewForFooterInSection?(target ?? self, tableView, section)
    }

    func tableView(_ tableView: UITableView, accessoryButtonTappedForRowWith indexPath: IndexPath) {
        accessoryButtonTappedForRowWith?(target ?? self, tableView, indexPath)
    }
}
// MARK: - Delegate Mux
class JobsTableViewDelegateMux: NSObject,
                                UITableViewDelegate,
                                UIScrollViewDelegate {
    weak var primary: NSObjectProtocol?   // 优先：JobsTableViewBlocksProxy
    weak var secondary: NSObjectProtocol? // 其次：外部 delegate（如果有）
    override func responds(to aSelector: Selector!) -> Bool {
        // 必须让 UIKit 认为我们“能响应”被转发对象的 selector
        if (primary as AnyObject?)?.responds(to: aSelector) == true { return true }
        if (secondary as AnyObject?)?.responds(to: aSelector) == true { return true };return super.responds(to: aSelector)
    }

    override func forwardingTarget(for aSelector: Selector!) -> Any? {
        // 选择性转发：优先 primary（确保 didSelect 走你的闭包）
        if (primary as AnyObject?)?.responds(to: aSelector) == true { return primary }
        if (secondary as AnyObject?)?.responds(to: aSelector) == true { return secondary };return super.forwardingTarget(for: aSelector)
    }
}
