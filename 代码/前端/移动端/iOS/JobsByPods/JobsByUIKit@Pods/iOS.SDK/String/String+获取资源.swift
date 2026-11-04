//
//  String+获取资源.swift
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
import JobsSwiftBlock

#if canImport(Kingfisher)
import Kingfisher
#endif
#if canImport(SDWebImage)
import SDWebImage
#endif

// MARK: 字符串转换成资源
extension String {
    // MARK: - 字符串@Bundle
    /// 在指定 Bundle 查找媒体资源 URL（支持 "name.ext" 或 "name"）。
    /// - Parameter bundle: 默认 .main
    /// - Returns: URL?（找不到返回 nil）
    public var bundleMediaURL: URL? {
        return bundleMediaURL(in: .main)
    }

    public func bundleMediaURL(in bundle: Bundle) -> URL? {
        let trimmed = self.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        // 既支持 "name.ext" 也支持 "name"
        let name = (trimmed as NSString).deletingPathExtension
        let ext  = (trimmed as NSString).pathExtension.isEmpty ? nil : (trimmed as NSString).pathExtension
        return bundle.url(forResource: name, withExtension: ext)
    }
    /// 必得版（开发期断言失败直接崩，等价你以前的 `!`）
    public var bundleMediaURLRequire: URL {
        if let u = self.bundleMediaURL { return u }
        assertionFailure("❌ Bundle media not found: \(self) (check Target Membership)")
        fatalError("Bundle media not found: \(self)")
    }
    // MARK: - 字符串@URL
    /// "https://..." → URL?  （仅放行 http/https；自动做轻度编码）
    public var url: URL? {
        let raw = self.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return nil }
        let s = raw.addingPercentEncoding(withAllowedCharacters: .urlFragmentAllowed) ?? raw
        guard let u = URL(string: s) else { return nil }
        if let scheme = u.scheme?.lowercased(),
           scheme == "http" || scheme == "https" {
            return u
        };return nil
    }
    /// "https://..." → URL  （开发期断言必得；等价你原来的 `!` 用法）
    public var urlRequire: URL {
        if let u = self.url { return u }
        assertionFailure("❌ Invalid URL string: \(self)")
        fatalError("Invalid URL: \(self)")
    }
    // MARK: - 字符串@图片
    /// 统一解析：字符串 → 图片来源
    public var imageSource: ImageSource? {
        // 优先判断 http/https
        if let url = URL(string: self),
           let scheme = url.scheme?.lowercased(),
           scheme == "http" || scheme == "https" {
            return .remote(url)
        };return .local(self)// 其余视为本地资源名（包括空 scheme、非 http(s)）
    }
    /// 本地同步图（仅当来源是 .local 时有意义）
    public var img: UIImage {
        guard let source = imageSource else { return UIImage.make { _ in } }
        switch source {
        /// 处理 .remote 分支
        case .remote:
            // 同步返回不支持网络加载，避免阻塞
            print("🚫 检测到网络 URL：\(self)，无法同步返回图片")
            return UIImage.make { _ in }
        /// 处理 .local 分支
        case .local(let name):
            return UIImage(named: name) ?? UIImage.make { _ in }
        }
    }

    public var sysImg: UIImage {
        if #available(iOS 13.0, *) {
            return UIImage(systemName: self) ?? jobsSolidBlue()
        } else {
            return UIImage(named: self) ?? jobsSolidBlue()
        }
    }

    @available(iOS 13.0, *)
    public func sysImg(_ config: UIImage.SymbolConfiguration) -> UIImage {
        UIImage(systemName: self, withConfiguration: config) ?? jobsSolidBlue()
    }
    /// 全版本可用：iOS13+ 走 SF Symbol + config；iOS12- 走本地同名资源
    public func sysImg(pointSize: CGFloat = 18, weight: JobsSymbolWeight = .regular) -> UIImage {
        if #available(iOS 13.0, *) {
            let config = UIImage.SymbolConfiguration(pointSize: pointSize, weight: weight.toSymbolWeight())
            return UIImage(systemName: self, withConfiguration: config) ?? jobsSolidBlue()
        } else {
            return UIImage(named: self) ?? jobsSolidBlue()
        }
    }
#if canImport(Kingfisher)
    /// 远程：通过 KF 异步下载后返回；本地：直接返回
    // ================================== Async 版本（仅在能用并发时编译） ==================================
    #if swift(>=5.5) && canImport(_Concurrency)
    @available(iOS 13.0, *)
    public func kfLoadImage() async throws -> UIImage {
        guard let source = imageSource else { throw KFError.badURL }
        switch source {
        /// 处理 .remote 分支
        case .remote(let url):
            // 关键：这里不要直接写 try await retrieveImage(...)，
            // 因为你当前 KF 版本可能没有 async overload。
            // 用 continuation 把 completion 版桥接成 async，兼容所有 KF 版本。
            return try await withCheckedThrowingContinuation { cont in
                KingfisherManager.shared.retrieveImage(with: url) { result in
                    switch result {
                    /// 处理 .success 分支
                    case .success(let value):
                        cont.resume(returning: value.image)   // value 是 RetrieveImageResult
                    /// 处理 .failure 分支
                    case .failure(let err):
                        cont.resume(throwing: err)            // err 是 KingfisherError
                    }
                }
            }
        /// 处理 .local 分支
        case .local(let name):
            if let img = UIImage(named: name) { return img }
            throw KFError.notFound
        }
    }
    #endif
    // ================================== Completion 版本（全版本可用） ==================================
    public func kfLoadImage(completion: @escaping (Result<UIImage, Error>) -> Void) {
        guard let source = imageSource else {
            completion(.failure(KFError.badURL))
            return
        }
        switch source {
        /// 处理 .remote 分支
        case .remote(let url):
            KingfisherManager.shared.retrieveImage(with: url) { result in
                switch result {
                /// 处理 .success 分支
                case .success(let value):
                    completion(.success(value.image))
                /// 处理 .failure 分支
                case .failure(let err):
                    completion(.failure(err))
                }
            }
        /// 处理 .local 分支
        case .local(let name):
            if let img = UIImage(named: name) {
                completion(.success(img))
            } else {
                completion(.failure(KFError.notFound))
            }
        }
    }
    /// A) 允许传 nil：nil -> 蓝色兜底
    @available(iOS 13.0, *)
    public func kfLoadImage(fallbackImage: @autoclosure JobsRetUIImageBlock) async -> UIImage {
        do { return try await self.kfLoadImage() }         // 你已有的 throws 版本
        catch { return fallbackImage() ?? jobsSolidBlue() }
    }
    /// B) 非可选便捷版
    @available(iOS 13.0, *)
    public func kfLoadImage(fallback: UIImage) async -> UIImage {
        await kfLoadImage(fallbackImage: fallback)
    }
#endif

#if canImport(SDWebImage)
    /// 远程：通过 SDWebImage 异步下载后返回；本地：直接返回
    // ================================== Async throws 版本（仅在能用并发时编译） ==================================
    #if swift(>=5.5) && canImport(_Concurrency)
    @available(iOS 13.0, *)
    public func sdLoadImage() async throws -> UIImage {
        guard let source = imageSource else {
            throw NSError(domain: "SDWebImage",
                          code: -1000,
                          userInfo: [NSLocalizedDescriptionKey: "Bad URL string"])
        }
        switch source {
        /// 处理 .remote 分支
        case .remote(let url):
            return try await withCheckedThrowingContinuation { cont in
                var didResume = false
                SDWebImageManager.shared.loadImage(
                    with: url,
                    options: [],
                    progress: nil
                ) { image, _, error, _, finished, _ in
                    // 避免渐进式/重复回调：只在最终 finished 时续体一次
                    guard finished, !didResume else { return }
                    didResume = true
                    if let error = error {
                        cont.resume(throwing: error)
                    } else if let image = image {
                        cont.resume(returning: image)
                    } else {
                        cont.resume(throwing: NSError(
                            domain: "SDWebImage",
                            code: -1001,
                            userInfo: [NSLocalizedDescriptionKey: "Image not found"]
                        ))
                    }
                }
            }
        /// 处理 .local 分支
        case .local(let name):
            if let img = UIImage(named: name) {
                return img
            }
            throw NSError(domain: "SDWebImage",
                          code: -1002,
                          userInfo: [NSLocalizedDescriptionKey: "Local image not found: \(name)"])
        }
    }
    /// 不抛错：加载失败则返回 fallbackImage()；若其为 nil，则返回蓝色占位图
    @available(iOS 13.0, *)
    public func sdLoadImage(fallbackImage: @autoclosure JobsRetUIImageBlock) async -> UIImage {
        do {
            return try await self.sdLoadImage()   // 你已有的 throws 版本
        } catch {
            return fallbackImage() ?? jobsSolidBlue()
        }
    }
    #endif
    // ================================== Completion 版本（全版本可用） ==================================
    /// 不抛错：加载失败则返回 fallbackImage()；若其为 nil，则返回蓝色占位图
    public func sdLoadImage(fallbackImage: @autoclosure JobsRetUIImageBlock,
                     completion: @escaping jobsByImgBlock) {
        let placeholder = fallbackImage() ?? jobsSolidBlue()
        guard let source = imageSource else {
            completion(placeholder)
            return
        }
        switch source {
        /// 处理 .remote 分支
        case .remote(let url):
            var didFinish = false
            SDWebImageManager.shared.loadImage(
                with: url,
                options: [],
                progress: nil
            ) { image, _, _, _, finished, _ in
                guard finished, !didFinish else { return }
                didFinish = true
                completion(image ?? placeholder)
            }
        /// 处理 .local 分支
        case .local(let name):
            completion(UIImage(named: name) ?? placeholder)
        }
    }
#endif
}
