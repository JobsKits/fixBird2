//
//  UIKit+Kingfisher.swift
//  JobsByUIKit
//
//  Created by Jobs on 2026年5月13日，星期三.
//

#if os(OSX)
import AppKit
#elseif os(iOS) || os(tvOS)
import UIKit
#endif

import JobsSwiftBaseDefines

#if canImport(Kingfisher)
import Kingfisher
extension URL {
    // ================================== iOS 13+ async/await 入口 ==================================
    #if swift(>=5.5) && canImport(_Concurrency)
    @available(iOS 13.0, tvOS 13.0, *)
    public func kfLoadImage() async throws -> UIImage {
        // 远程：用 KF completion 桥接成 async（兼容所有 KF 版本）
        if isHTTPRemote {
            return try await withCheckedThrowingContinuation { cont in
                KingfisherManager.shared.retrieveImage(with: self) { result in
                    switch result {
                    /// 处理 .success 分支
                    case .success(let value):
                        cont.resume(returning: value.image)
                    /// 处理 .failure 分支
                    case .failure(let err):
                        cont.resume(throwing: err)
                    }
                }
            }
        }
        // 本地文件
        if isFileURL {
            if let img = UIImage(contentsOfFile: path) { return img }
            throw KFError.notFound
        }
        // Bundle 资源兜底：取最后路径名（无扩展）
        let name = deletingPathExtension().lastPathComponent
        if let img = UIImage(named: name) { return img }
        throw KFError.notFound
    }
    #endif
    // ================================== iOS 12- completion 入口 ==================================
    public func kfLoadImage(completion: @escaping (Result<UIImage, Error>) -> Void) {
        if isHTTPRemote {
            KingfisherManager.shared.retrieveImage(with: self) { result in
                switch result {
                /// 处理 .success 分支
                case .success(let value):
                    completion(.success(value.image))
                /// 处理 .failure 分支
                case .failure(let err):
                    completion(.failure(err))
                }
            };return
        }
        if isFileURL {
            if let img = UIImage(contentsOfFile: path) { completion(.success(img)) }
            else { completion(.failure(KFError.notFound)) };return
        }
        let name = deletingPathExtension().lastPathComponent
        if let img = UIImage(named: name) { completion(.success(img)) }
        else { completion(.failure(KFError.notFound)) }
    }
}
#endif
