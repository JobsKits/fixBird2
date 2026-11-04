//
//  YTKChainRequest+DSL.swift
//  JobsBy3rdTools
//
//  Created by Jobs on 2026年5月13日，星期三.
//

import ObjectiveC
import JobsSwiftBlock

#if canImport(YTKNetwork) && canImport(AFNetworking)
import YTKNetwork
import AFNetworking
/// 内部代理：把 delegate 回调转成闭包
private final class JobsChainDelegateProxy: NSObject, YTKChainRequestDelegate {
    weak var realDelegate: YTKChainRequestDelegate?
    var successBlock: JobsYTKChainSuccess?
    var failureBlock: JobsYTKChainFailure?

    func chainRequestFinished(_ chainRequest: YTKChainRequest) {
        // 先走闭包，再转发给外部 delegate（如果实现了）
        successBlock?(chainRequest)
        realDelegate?.chainRequestFinished?(chainRequest)
    }

    func chainRequestFailed(_ chainRequest: YTKChainRequest,
                            failedBaseRequest request: YTKBaseRequest) {
        failureBlock?(chainRequest, request)
        realDelegate?.chainRequestFailed?(chainRequest, failedBaseRequest: request)
    }
}
/// 关联对象 key
private var kJobsChainProxyKey: UInt8 = 0
private extension YTKChainRequest {
    /// 取 / 创建 代理
    var jobs_proxy: JobsChainDelegateProxy {
        if let proxy = objc_getAssociatedObject(self, &kJobsChainProxyKey) as? JobsChainDelegateProxy {
            return proxy
        }
        let proxy = JobsChainDelegateProxy()
        objc_setAssociatedObject(self,
                                 &kJobsChainProxyKey,
                                 proxy,
                                 .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        // 让真正的 delegate 指向 proxy
        self.delegate = proxy
        return proxy
    }
}

public extension YTKChainRequest {
    // MARK: - 基本配置
    /// 配置业务 delegate（闭包仍然生效，proxy 会转发）
    @discardableResult
    func byDelegate(_ value: YTKChainRequestDelegate?) -> Self {
        let proxy = jobs_proxy
        proxy.realDelegate = value
        self.delegate = proxy
        return self
    }
    /// 添加 accessory
    @discardableResult
    func byAddAccessory(_ accessory: YTKRequestAccessory) -> Self {
        self.add(accessory)
        return self
    }
    /// 一次性加一批 accessory
    @discardableResult
    func byAccessories(_ accessories: [YTKRequestAccessory]) -> Self {
        accessories.forEach { self.add($0) };return self
    }
    // MARK: - 链步骤
    /// 添加一步请求 + 可选回调
    @discardableResult
    func byAdd(_ request: YTKBaseRequest,
               callback: JobsYTKChainStepCallback? = nil) -> Self {
        if let cb = callback {
            self.add(request) { chain, baseReq in
                cb(chain, baseReq)          // 这里两个参数都不是 Optional，直接用
            }
        } else {
            self.add(request, callback: nil)
        };return self
    }
    /// 批量添加步骤（全部不需要 step 回调）
    @discardableResult
    func byAdd(_ requests: [YTKBaseRequest]) -> Self {
        requests.forEach { self.add($0, callback: nil) };return self
    }
    // MARK: - 全局成功 / 失败回调
    /// 整条链成功
    @discardableResult
    func bySuccess(_ block: @escaping JobsYTKChainSuccess) -> Self {
        let proxy = jobs_proxy
        proxy.successBlock = block
        self.delegate = proxy
        return self
    }
    /// 任意一步失败
    @discardableResult
    func byFailure(_ block: @escaping JobsYTKChainFailure) -> Self {
        let proxy = jobs_proxy
        proxy.failureBlock = block
        self.delegate = proxy
        return self
    }
    /// 同时设置成功 / 失败
    @discardableResult
    func byJobsVoidBlock(success: JobsYTKChainSuccess? = nil,
                      failure: JobsYTKChainFailure? = nil) -> Self {
        let proxy = jobs_proxy
        proxy.successBlock = success
        proxy.failureBlock = failure
        self.delegate = proxy
        return self
    }
    // MARK: - 启动
    /// 启动链式请求
    @discardableResult
    func byStart() -> Self {
        self.start()
        return self
    }
    // MARK: - 访问辅助
    /// 所有子请求
    var jobs_requests: [YTKBaseRequest] {
        return requestArray()
    }
}
#endif
