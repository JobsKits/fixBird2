//
//  URL+SDWebImage.swift
//  JobsByUIKit
//
//  Created by Jobs on 2026年5月13日，星期三.
//

#if os(OSX)
import AppKit
#elseif os(iOS) || os(tvOS)
import UIKit
#endif

// MARK: - SDWebImage 版本
#if canImport(SDWebImage)
import SDWebImage
extension URL {
    // ================================== iOS 13+ async/await 入口 ==================================
    #if swift(>=5.5) && canImport(_Concurrency)
    @available(iOS 13.0, tvOS 13.0, *)
    public func sdLoadImage() async throws -> UIImage {
        if isHTTPRemote {
            return try await withCheckedThrowingContinuation { continuation in
                var didResume = false
                SDWebImageManager.shared.loadImage(
                    with: self,
                    options: [],
                    progress: nil
                ) { image, _, error, _, finished, _ in
                    // 避免渐进式/重复回调：只在最终 finished 且未 resume 时处理一次
                    guard finished, !didResume else { return }
                    didResume = true
                    if let image {
                        continuation.resume(returning: image)
                    } else if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(throwing: SDWebImageError.badImageData as! Error)
                    }
                }
            }
        }
        if isFileURL {
            if let img = UIImage(contentsOfFile: path) { return img }
            throw SDWebImageError(.badImageData)
        }
        // 兜底：当作 Bundle 资源名（取最后路径段去扩展名）
        let name = deletingPathExtension().lastPathComponent
        if let img = UIImage(named: name) { return img }
        throw SDWebImageError(.badImageData)
    }
    #endif
    // ================================== iOS 12- completion 入口 ==================================
    public func sdLoadImage(completion: @escaping (Result<UIImage, Error>) -> Void) {
        if isHTTPRemote {
            var didFinish = false
            SDWebImageManager.shared.loadImage(
                with: self,
                options: [],
                progress: nil
            ) { image, _, error, _, finished, _ in
                guard finished, !didFinish else { return }
                didFinish = true
                if let image {
                    completion(.success(image))
                } else if let error {
                    completion(.failure(error))
                } else {
                    completion(.failure(SDWebImageError(.badImageData)))
                }
            };return
        }
        if isFileURL {
            if let img = UIImage(contentsOfFile: path) { completion(.success(img)) }
            else { completion(.failure(SDWebImageError(.badImageData))) };return
        }
        let name = deletingPathExtension().lastPathComponent
        if let img = UIImage(named: name) { completion(.success(img)) }
        else { completion(.failure(SDWebImageError(.badImageData))) }
    }
}
#endif
