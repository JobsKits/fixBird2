//
//  JobsSimpleImageLoader.swift
//  JobsImageTools
//
//  Created by Jobs on 2026年5月13日，星期三.
//

#if os(OSX)
import AppKit
#elseif os(iOS) || os(tvOS)
import UIKit
#endif

import Foundation
import ImageIO

#if canImport(Kingfisher)
import Kingfisher
#endif
#if canImport(SDWebImage)
import SDWebImage
#endif

public enum JobsImageLoaderPreference {
    case automatic
    case sdwebimage
    case kingfisher
    case urlSession
}

public enum JobsImageSource {
    case remote(URL)
    case local(String)

    public init?(_ string: String?) {
        guard let raw = string?.trimmingCharacters(in: .whitespacesAndNewlines), raw.isEmpty == false else { return nil }
        if let url = URL(string: raw), let scheme = url.scheme?.lowercased(), ["http", "https", "file"].contains(scheme) {
            self = .remote(url)
        } else {
            self = .local(raw)
        }
    }
}

public enum JobsImageLoadError: Error {
    case cancelled
    case invalidSource
    case localImageMissing(String)
    case badData(URL)
    case failed(URL, Error)
}

public struct JobsImageLoadOptions {
    public var preferredLoader: JobsImageLoaderPreference
    public var targetSize: CGSize?
    public var scale: CGFloat
    public var forceRefresh: Bool

    public init(
        preferredLoader: JobsImageLoaderPreference = .automatic,
        targetSize: CGSize? = nil,
        scale: CGFloat = JobsImageLoader.defaultScale,
        forceRefresh: Bool = false
    ) {
        self.preferredLoader = preferredLoader
        self.targetSize = targetSize
        self.scale = scale
        self.forceRefresh = forceRefresh
    }
}

public struct JobsImageLoadResult {
    public let image: UIImage
    public let url: URL?
    public let loaderKind: JobsImageLoaderKind
    public let isCacheHit: Bool
}

public final class JobsImageLoadToken {
    private let onCancel: () -> Void
    private var isCancelled = false
    private let lock = NSLock()

    public init(_ onCancel: @escaping () -> Void = {}) {
        self.onCancel = onCancel
    }

    public func cancel() {
        lock.lock()
        guard !isCancelled else {
            lock.unlock()
            return
        }
        isCancelled = true
        lock.unlock()
        onCancel()
    }
}

public final class JobsImageLoader {
    public static let shared = JobsImageLoader()
    public static var defaultScale: CGFloat {
        #if os(iOS) || os(tvOS)
        return UIScreen.main.scale
        #elseif os(OSX)
        return NSScreen.main?.backingScaleFactor ?? 2
        #else
        return 2
        #endif
    }

    private let fallbackCache = NSCache<NSString, UIImage>()
    private let fallbackSession: URLSession

    public init(session: URLSession = .shared) {
        fallbackSession = session
        fallbackCache.countLimit = 240
        fallbackCache.totalCostLimit = 80 * 1024 * 1024
    }

    public func cachedImage(for url: URL) -> UIImage? {
        #if canImport(SDWebImage)
        let sdKey = SDWebImageManager.shared.cacheKey(for: url) ?? url.absoluteString
        if let image = SDImageCache.shared.imageFromMemoryCache(forKey: sdKey) {
            return image
        }
        #endif
        #if canImport(Kingfisher)
        if let image = KingfisherManager.shared.cache.retrieveImageInMemoryCache(forKey: url.absoluteString) {
            return image
        }
        #endif
        return fallbackCache.object(forKey: fallbackKey(url, options: .init()))
    }

    @discardableResult
    public func load(
        _ source: JobsImageSource?,
        options: JobsImageLoadOptions = .init(),
        completion: @escaping (Result<JobsImageLoadResult, JobsImageLoadError>) -> Void
    ) -> JobsImageLoadToken {
        var options = options
        options.scale = options.scale.isFinite && options.scale > 0 ? min(options.scale, 8) : 1
        if let size = options.targetSize {
            options.targetSize = size.width.isFinite && size.height.isFinite && size.width > 0 && size.height > 0
                ? CGSize(width: min(size.width, 4_096 / options.scale), height: min(size.height, 4_096 / options.scale)) : nil
        }
        let delivery = JobsImageLoadDelivery(completion)
        let token: JobsImageLoadToken
        switch source {
        case nil:
            delivery.finish(.failure(.invalidSource))
            token = JobsImageLoadToken()
        case .local(let name):
            token = loadLocalImage(name, completion: delivery.finish)
        case .remote(let url):
            token = loadRemoteImage(url, options: options, completion: delivery.finish)
        }
        return JobsImageLoadToken {
            delivery.finish(.failure(.cancelled))
            token.cancel()
        }
    }

    public func clearMemoryCache() {
        fallbackCache.removeAllObjects()
        #if canImport(SDWebImage)
        SDImageCache.shared.clearMemory()
        #endif
        #if canImport(Kingfisher)
        KingfisherManager.shared.cache.clearMemoryCache()
        #endif
    }
}

private extension JobsImageLoader {
    func loadLocalImage(
        _ name: String,
        completion: @escaping (Result<JobsImageLoadResult, JobsImageLoadError>) -> Void
    ) -> JobsImageLoadToken {
        if let image = UIImage(named: name) {
            let result = JobsImageLoadResult(image: image, url: nil, loaderKind: .unknown, isCacheHit: true)
            DispatchQueue.main.async { completion(.success(result)) }
        } else {
            DispatchQueue.main.async { completion(.failure(.localImageMissing(name))) }
        };return JobsImageLoadToken()
    }

    func loadRemoteImage(
        _ url: URL,
        options: JobsImageLoadOptions,
        completion: @escaping (Result<JobsImageLoadResult, JobsImageLoadError>) -> Void
    ) -> JobsImageLoadToken {
        switch resolvedLoader(for: options.preferredLoader) {
        /// 处理 .sdwebimage 分支
        case .sdwebimage:
            return loadWithSDWebImage(url, options: options, completion: completion)
        /// 处理 .kingfisher 分支
        case .kingfisher:
            return loadWithKingfisher(url, options: options, completion: completion)
        /// 合并处理 .urlSession、.unknown 分支
        case .urlSession, .unknown:
            return loadWithURLSession(url, options: options, completion: completion)
        }
    }

    func resolvedLoader(for preference: JobsImageLoaderPreference) -> JobsImageLoaderKind {
        switch preference {
        /// 处理 .sdwebimage 分支
        case .sdwebimage:
            #if canImport(SDWebImage)
            return .sdwebimage
            #else
            return resolvedLoader(for: .automatic)
            #endif
        /// 处理 .kingfisher 分支
        case .kingfisher:
            #if canImport(Kingfisher)
            return .kingfisher
            #else
            return resolvedLoader(for: .automatic)
            #endif
        /// 处理 .urlSession 分支
        case .urlSession:
            return .urlSession
        /// 处理 .automatic 分支
        case .automatic:
            #if canImport(SDWebImage)
            return .sdwebimage
            #elseif canImport(Kingfisher)
            return .kingfisher
            #else
            return .urlSession
            #endif
        }
    }

    #if canImport(Kingfisher)
    func loadWithKingfisher(
        _ url: URL,
        options: JobsImageLoadOptions,
        completion: @escaping (Result<JobsImageLoadResult, JobsImageLoadError>) -> Void
    ) -> JobsImageLoadToken {
        var kfOptions: KingfisherOptionsInfo = []
        if options.forceRefresh { kfOptions.append(.forceRefresh) }
        if let targetSize = options.targetSize, targetSize.width > 1, targetSize.height > 1 {
            kfOptions.append(.processor(DownsamplingImageProcessor(size: targetSize)))
            kfOptions.append(.scaleFactor(options.scale))
            kfOptions.append(.cacheOriginalImage)
        }
        let task = KingfisherManager.shared.retrieveImage(with: url, options: kfOptions) { result in
            DispatchQueue.main.async {
                switch result {
                /// 处理 .success 分支
                case .success(let value):
                    completion(.success(.init(
                        image: value.image,
                        url: url,
                        loaderKind: .kingfisher,
                        isCacheHit: value.cacheType.cached
                    )))
                /// 处理 .failure 分支
                case .failure(let error):
                    completion(.failure(.failed(url, error)))
                }
            }
        };return JobsImageLoadToken { task?.cancel() }
    }
    #else
    func loadWithKingfisher(
        _ url: URL,
        options: JobsImageLoadOptions,
        completion: @escaping (Result<JobsImageLoadResult, JobsImageLoadError>) -> Void
    ) -> JobsImageLoadToken {
        loadWithURLSession(url, options: options, completion: completion)
    }
    #endif

    #if canImport(SDWebImage)
    func loadWithSDWebImage(
        _ url: URL,
        options: JobsImageLoadOptions,
        completion: @escaping (Result<JobsImageLoadResult, JobsImageLoadError>) -> Void
    ) -> JobsImageLoadToken {
        var sdOptions: SDWebImageOptions = [.retryFailed, .highPriority, .scaleDownLargeImages]
        if options.forceRefresh { sdOptions.insert(.refreshCached) }
        var context: [SDWebImageContextOption: Any] = [:]
        if let targetSize = options.targetSize, targetSize.width > 1, targetSize.height > 1 {
            context[.imageThumbnailPixelSize] = CGSize(width: targetSize.width * options.scale,
                                                       height: targetSize.height * options.scale)
        }
        let operation = SDWebImageManager.shared.loadImage(
            with: url,
            options: sdOptions,
            context: context,
            progress: nil
        ) { image, _, error, cacheType, _, imageURL in
            DispatchQueue.main.async {
                if let image, error == nil {
                    completion(.success(.init(
                        image: image,
                        url: imageURL ?? url,
                        loaderKind: .sdwebimage,
                        isCacheHit: cacheType != .none
                    )))
                } else if let error {
                    completion(.failure(.failed(url, error)))
                } else {
                    completion(.failure(.badData(url)))
                }
            }
        };return JobsImageLoadToken { operation?.cancel() }
    }
    #else
    func loadWithSDWebImage(
        _ url: URL,
        options: JobsImageLoadOptions,
        completion: @escaping (Result<JobsImageLoadResult, JobsImageLoadError>) -> Void
    ) -> JobsImageLoadToken {
        loadWithURLSession(url, options: options, completion: completion)
    }
    #endif

    func loadWithURLSession(
        _ url: URL,
        options: JobsImageLoadOptions,
        completion: @escaping (Result<JobsImageLoadResult, JobsImageLoadError>) -> Void
    ) -> JobsImageLoadToken {
        let key = fallbackKey(url, options: options)
        if !options.forceRefresh, let image = fallbackCache.object(forKey: key) {
            DispatchQueue.main.async {
                completion(.success(.init(image: image, url: url, loaderKind: .urlSession, isCacheHit: true)))
            };return JobsImageLoadToken()
        }
        let request = URLRequest(url: url,
                                 cachePolicy: options.forceRefresh ? .reloadIgnoringLocalCacheData : .useProtocolCachePolicy,
                                 timeoutInterval: 15)
        let task = fallbackSession.dataTask(with: request) { [weak self] data, response, error in
            guard let self else { return }
            if let error {
                DispatchQueue.main.async { completion(.failure(.failed(url, error))) };return
            }
            if let response = response as? HTTPURLResponse, !(200...299).contains(response.statusCode) {
                DispatchQueue.main.async { completion(.failure(.badData(url))) }
                return
            }
            guard let data, data.count <= 32 * 1024 * 1024 else {
                DispatchQueue.main.async { completion(.failure(.badData(url))) }
                return
            }
            guard let image = self.image(from: data, targetSize: options.targetSize, scale: options.scale) else {
                DispatchQueue.main.async { completion(.failure(.badData(url))) };return
            }
            let cost: Int
            if let cgImage = image.cgImage {
                let bytes = cgImage.bytesPerRow.multipliedReportingOverflow(by: cgImage.height)
                cost = bytes.overflow ? Int.max : bytes.partialValue
            } else {
                cost = data.count
            }
            self.fallbackCache.setObject(image, forKey: key, cost: cost)
            DispatchQueue.main.async {
                completion(.success(.init(image: image, url: url, loaderKind: .urlSession, isCacheHit: false)))
            }
        }
        task.resume()
        return JobsImageLoadToken { task.cancel() }
    }

    func fallbackKey(_ url: URL, options: JobsImageLoadOptions) -> NSString {
        let scale = options.scale.isFinite && options.scale > 0 ? options.scale : 1
        let size = options.targetSize
        let width = size?.width.isFinite == true ? max(0, size?.width ?? 0) : 0
        let height = size?.height.isFinite == true ? max(0, size?.height ?? 0) : 0
        return "\(url.absoluteString)|thumbnail:\(width)x\(height)|scale:\(scale)" as NSString
    }

    func image(from data: Data, targetSize: CGSize?, scale: CGFloat) -> UIImage? {
        let options = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, options) else { return nil }
        let safeScale = scale.isFinite && scale > 0 ? min(scale, 8) : 1
        let rawPixel = targetSize.map { max($0.width, $0.height) * safeScale } ?? 4_096
        guard rawPixel.isFinite, rawPixel > 0 else { return nil }
        let downsampleOptions = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: max(1, Int(min(4_096, rawPixel)))
        ] as CFDictionary
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, downsampleOptions) else { return nil }
        let cost = cgImage.bytesPerRow.multipliedReportingOverflow(by: cgImage.height)
        guard !cost.overflow, cost.partialValue <= 64 * 1024 * 1024 else { return nil }
        return UIImage(cgImage: cgImage, scale: safeScale, orientation: .up)
    }
}

private final class JobsImageLoadDelivery: @unchecked Sendable {
    private let lock = NSLock()
    private var completion: ((Result<JobsImageLoadResult, JobsImageLoadError>) -> Void)?

    init(_ completion: @escaping (Result<JobsImageLoadResult, JobsImageLoadError>) -> Void) {
        self.completion = completion
    }

    func finish(_ result: Result<JobsImageLoadResult, JobsImageLoadError>) {
        lock.lock()
        let completion = self.completion
        self.completion = nil
        lock.unlock()
        guard let completion else { return }
        DispatchQueue.main.async { completion(result) }
    }
}
