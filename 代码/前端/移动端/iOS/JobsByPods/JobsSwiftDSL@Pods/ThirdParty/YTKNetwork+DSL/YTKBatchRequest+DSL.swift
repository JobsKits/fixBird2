//
//  YTKBatchRequest+DSL.swift
//  JobsBy3rdTools
//
//  Created by Jobs on 2026年5月13日，星期三.
//

import JobsSwiftBlock

#if canImport(YTKNetwork) && canImport(AFNetworking)
import YTKNetwork
import AFNetworking
public extension YTKBatchRequest {
    // MARK: - 基本配置
    /// tag 标记
    @discardableResult
    func byTag(_ value: Int) -> Self {
        self.tag = value
        return self
    }
    /// delegate
    @discardableResult
    func byDelegate(_ value: YTKBatchRequestDelegate?) -> Self {
        self.delegate = value
        return self
    }
    /// 添加 accessory
    @discardableResult
    func byAddAccessory(_ accessory: YTKRequestAccessory) -> Self {
        self.add(accessory)
        return self
    }
    /// 一次性设置一批 accessory
    @discardableResult
    func byAccessories(_ accessories: [YTKRequestAccessory]) -> Self {
        accessories.forEach { self.add($0) };return self
    }
    // MARK: - 回调配置
    /// 成功回调
    @discardableResult
    func bySuccess(_ block: @escaping JobsYTKBatchJobsVoidBlock) -> Self {
        self.successCompletionBlock = { batch in
            block(batch)
        };return self
    }
    /// 失败回调
    @discardableResult
    func byFailure(_ block: @escaping JobsYTKBatchJobsVoidBlock) -> Self {
        self.failureCompletionBlock = { batch in
            block(batch)
        };return self
    }
    /// 同时设置成功 + 失败
    @discardableResult
    func byCompletion(success: JobsYTKBatchJobsVoidBlock? = nil,
                      failure: JobsYTKBatchJobsVoidBlock? = nil) -> Self {
        if let s = success {
            self.successCompletionBlock = { batch in s(batch) }
        }
        if let f = failure {
            self.failureCompletionBlock = { batch in f(batch) }
        };return self
    }
    // MARK: - 启动
    /// 启动批量请求，按需自动 clearJobsVoidBlockBlock，避免循环引用
    @discardableResult
    func byStart(autoClearCompletion: Bool = true) -> Self {
        if autoClearCompletion {
            let success = self.successCompletionBlock
            let failure = self.failureCompletionBlock
            self.successCompletionBlock = { [weak self] batch in
                success?(batch)
                self?.clearCompletionBlock()
            }
            self.failureCompletionBlock = { [weak self] batch in
                failure?(batch)
                self?.clearCompletionBlock()
            }
        }
        self.start()
        return self
    }
    // MARK: - 访问辅助（语法糖）
    /// 所有子请求（原来的 requestArray 只是 readonly，这里做个语义 alias）
    var jobs_requests: [YTKRequest] {
        return requestArray
    }
    /// 首个失败的子请求（原来的 failedRequest 的语义 alias）
    var jobs_failedRequest: YTKRequest? {
        return failedRequest
    }
    /// 是否所有数据都来自缓存
    var jobs_isFromCache: Bool {
        return isDataFromCache()
    }
}

#endif
