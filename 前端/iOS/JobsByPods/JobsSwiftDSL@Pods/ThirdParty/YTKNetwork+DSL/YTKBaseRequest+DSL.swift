//
//  YTKBaseRequest+DSL.swift
//  JobsBy3rdTools
//
//  Created by Jobs on 2026年5月13日，星期三.
//

import JobsSwiftBlock

#if canImport(YTKNetwork) && canImport(AFNetworking)
import YTKNetwork
import AFNetworking
public extension YTKBaseRequest {
    // MARK: - 基本配置
    @discardableResult
    func byTag(_ value: Int) -> Self {
        self.tag = value
        return self
    }

    @discardableResult
    func byUserInfo(_ info: [String: Any]?) -> Self {
        self.userInfo = info
        return self
    }

    @discardableResult
    func byDelegate(_ value: YTKRequestDelegate?) -> Self {
        self.delegate = value
        return self
    }

    @discardableResult
    func byPriority(_ value: YTKRequestPriority) -> Self {
        self.requestPriority = value
        return self
    }
    // MARK: - 下载 / 上传
    /// 断点续传路径
    @discardableResult
    func byResumableDownloadPath(_ path: String?) -> Self {
        self.resumableDownloadPath = path
        return self
    }
    /// 下载进度
    @discardableResult
    func byDownloadProgress(_ block: @escaping JobsYTKProgress) -> Self {
        self.resumableDownloadProgressBlock = { progress in
            block(progress)
        };return self
    }
    /// 上传进度
    @discardableResult
    func byUploadProgress(_ block: @escaping JobsYTKProgress) -> Self {
        self.uploadProgressBlock = { progress in
            block(progress)
        };return self
    }
    /// Multipart 构造
    @discardableResult
    func byConstructBody(_ block: @escaping (AFMultipartFormData) -> Void) -> Self {
        self.constructingBodyBlock = { formData in
            block(formData)
        };return self
    }
    // MARK: - 回调配置（不带类型）
    /// 成功回调（request 类型是 YTKBaseRequest）
    @discardableResult
    func bySuccess(_ block: @escaping JobsYTKJobsVoidBlock) -> Self {
        self.successCompletionBlock = { req in
            block(req)
        };return self
    }
    /// 失败回调（request 类型是 YTKBaseRequest）
    @discardableResult
    func byFailure(_ block: @escaping JobsYTKJobsVoidBlock) -> Self {
        self.failureCompletionBlock = { req in
            block(req)
        };return self
    }
    /// 一次性同时配成功 & 失败
    @discardableResult
    func byCompletion(success: JobsYTKJobsVoidBlock? = nil,
                      failure: JobsYTKJobsVoidBlock? = nil) -> Self {
        if let s = success {
            self.successCompletionBlock = { req in s(req) }
        }
        if let f = failure {
            self.failureCompletionBlock = { req in f(req) }
        };return self
    }
    // MARK: - 回调配置（带具体子类类型）
    /// 成功回调，自动 cast 成指定子类
    @discardableResult
    func bySuccess<T: YTKBaseRequest>(_ type: T.Type,
                                      _ block: @escaping jobsByTypeBlock<T>) -> Self {
        self.successCompletionBlock = { req in
            guard let casted = req as? T else { return }
            block(casted)
        };return self
    }
    /// 失败回调，自动 cast 成指定子类
    @discardableResult
    func byFailure<T: YTKBaseRequest>(_ type: T.Type,
                                      _ block: @escaping (T) -> Void) -> Self {
        self.failureCompletionBlock = { req in
            guard let casted = req as? T else { return }
            block(casted)
        };return self
    }
    // MARK: - 启动
    /// 启动请求，按需自动 clear 回调，避免循环引用
    @discardableResult
    func byStart(autoClearCompletion: Bool = true) -> Self {
        if autoClearCompletion {
            let success = self.successCompletionBlock
            let failure = self.failureCompletionBlock
            self.successCompletionBlock = { [weak self] req in
                success?(req)
                self?.clearCompletionBlock()
            }
            self.failureCompletionBlock = { [weak self] req in
                failure?(req)
                self?.clearCompletionBlock()
            }
        }
        self.start()
        return self
    }
}

#endif
