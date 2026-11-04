//
//  UIScrollView.swift
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

// MARK: - DSL
extension UIScrollView {
    @discardableResult
    public func byScrollTargetWeak(_ target: AnyObject) -> Self {
        let p = jobs_scrollBlocksProxy()!   // 你现有的 scroll proxy getter
        p.target = target                  // 这里 target 必须是 weak
        delegate = p                       // 或者走你自己的 mux
        return self
    }
    /// 给 scroll blocks 设置 target（table/collection 的 byTarget 会自动调用这个，不用你手动调）
    @discardableResult
    public func byScrollTarget(_ target: AnyObject) -> Self {
        let p = jobs_scrollBlocksProxy()!
        p.target = target
        if delegate == nil {
            jobs_setDelegateMuxIfNeeded(primary: nil)
        };return self
    }

    @discardableResult
    public func willBeginDragging(_ block: @escaping (AnyObject, UIScrollView) -> Void) -> Self {
        jobs_scrollBlocksProxy()?.willBeginDragging = block
        return self
    }

    @discardableResult
    public func didScroll(_ block: @escaping (AnyObject, UIScrollView) -> Void) -> Self {
        jobs_scrollBlocksProxy()?.didScroll = block
        return self
    }

    @discardableResult
    public func didEndDragging(_ block: @escaping (AnyObject, UIScrollView, Bool) -> Void) -> Self {
        jobs_scrollBlocksProxy()?.didEndDragging = block
        return self
    }

    @discardableResult
    public func willBeginDecelerating(_ block: @escaping (AnyObject, UIScrollView) -> Void) -> Self {
        jobs_scrollBlocksProxy()?.willBeginDecelerating = block
        return self
    }

    @discardableResult
    public func didEndDecelerating(_ block: @escaping (AnyObject, UIScrollView) -> Void) -> Self {
        jobs_scrollBlocksProxy()?.didEndDecelerating = block
        return self
    }

    @discardableResult
    public func scrollViewShouldScrollToTop(_ block: @escaping (AnyObject, UIScrollView) -> Bool) -> Self {
        jobs_scrollBlocksProxy()?.scrollViewShouldScrollToTop = block
        return self
    }

    @discardableResult
    public func didScrollToTop(_ block: @escaping (AnyObject, UIScrollView) -> Void) -> Self {
        jobs_scrollBlocksProxy()?.didScrollToTop = block
        return self
    }
}
// MARK: - Proxy (UIScrollViewDelegate Block化)
private final class JobsScrollViewBlocksProxy: NSObject, UIScrollViewDelegate {
    weak var target: AnyObject?

    var willBeginDragging: ((AnyObject, UIScrollView) -> Void)?
    var didScroll: ((AnyObject, UIScrollView) -> Void)?
    var didEndDragging: ((AnyObject, UIScrollView, Bool) -> Void)?
    var willBeginDecelerating: ((AnyObject, UIScrollView) -> Void)?
    var didEndDecelerating: ((AnyObject, UIScrollView) -> Void)?
    var scrollViewShouldScrollToTop: ((AnyObject, UIScrollView) -> Bool)?
    var didScrollToTop: ((AnyObject, UIScrollView) -> Void)?

    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        guard let t = target else { return }
        willBeginDragging?(t, scrollView)
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard let t = target else { return }
        didScroll?(t, scrollView)
    }

    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        guard let t = target else { return }
        didEndDragging?(t, scrollView, decelerate)
    }

    func scrollViewWillBeginDecelerating(_ scrollView: UIScrollView) {
        guard let t = target else { return }
        willBeginDecelerating?(t, scrollView)
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        guard let t = target else { return }
        didEndDecelerating?(t, scrollView)
    }

    func scrollViewShouldScrollToTop(_ scrollView: UIScrollView) -> Bool {
        guard let t = target else { return true };return scrollViewShouldScrollToTop?(t, scrollView) ?? true
    }

    func scrollViewDidScrollToTop(_ scrollView: UIScrollView) {
        guard let t = target else { return }
        didScrollToTop?(t, scrollView)
    }
}
// MARK: - Delegate Multiplexer（把 scroll 回调分发出去）
private final class JobsScrollDelegateMux: NSObject {
    private weak var primary: NSObject?
    private weak var scroll: JobsScrollViewBlocksProxy?

    init(primary: NSObject?, scroll: JobsScrollViewBlocksProxy?) {
        self.primary = primary
        self.scroll = scroll
        super.init()
    }

    override func responds(to aSelector: Selector!) -> Bool {
        if let s = scroll, s.responds(to: aSelector) { return true }
        if let p = primary, p.responds(to: aSelector) { return true };return super.responds(to: aSelector)
    }

    override func forwardingTarget(for aSelector: Selector!) -> Any? {
        if let s = scroll, s.responds(to: aSelector) { return s }
        if let p = primary, p.responds(to: aSelector) { return p };return super.forwardingTarget(for: aSelector)
    }
}
// MARK: - Associated
private enum JobsScrollViewBlocksAssociatedKeys {
    static var scrollProxyKey = "jobs.scrollview.blocks.proxy.key"
    static var delegateMuxKey = "jobs.scrollview.blocks.delegate.mux.key"
}

extension UIScrollView {
    private func jobs_scrollBlocksProxy(createIfNeeded: Bool = true) -> JobsScrollViewBlocksProxy? {
        if let p = objc_getAssociatedObject(self, &JobsScrollViewBlocksAssociatedKeys.scrollProxyKey) as? JobsScrollViewBlocksProxy {
            return p
        }
        guard createIfNeeded else { return nil }
        let p = JobsScrollViewBlocksProxy()
        objc_setAssociatedObject(
            self,
            &JobsScrollViewBlocksAssociatedKeys.scrollProxyKey,
            p,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        );return p
    }

    public func jobs_setDelegateMuxIfNeeded(primary: NSObject?) {
        let mux = JobsScrollDelegateMux(primary: primary, scroll: jobs_scrollBlocksProxy()!)
        objc_setAssociatedObject(
            self,
            &JobsScrollViewBlocksAssociatedKeys.delegateMuxKey,
            mux,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        );delegate = mux as? UIScrollViewDelegate
    }
}
