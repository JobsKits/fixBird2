//
//  JobsSwift3rdPodsBlock.swift
//  JobsSwiftBlock
//
//  Created by Jobs on 2026年5月13日，星期三.
//

#if os(OSX)
import AppKit
#elseif os(iOS) || os(tvOS)
import UIKit
#endif

// MARK: —— Cocoapods
/// Cocoapods@Kingfisher
#if canImport(Kingfisher)
import Kingfisher
public typealias KFCompleted = (Result<RetrieveImageResult, KingfisherError>) -> Void
#else
// 没有集成 Kingfisher 时给一个退化版本，避免整个工程编不过
public typealias KFCompleted = (Result<UIImage, Error>) -> Void
#endif
/// Cocoapods@SnapKit
#if canImport(SnapKit)
import SnapKit
/// SnapKit 语法糖🍬
// 存的就是这个类型
public typealias jobsByConstraintMakerBlock = (_ make: ConstraintMaker) -> Void
public typealias JobsEmptyButtonLayout = (UIButton, ConstraintMaker, UIScrollView) -> Void
public typealias JobsEmptyViewLayout = (UIView, ConstraintMaker, UIScrollView) -> Void
#endif
/// Cocoapods@YTKNetwork
#if canImport(YTKNetwork)
import YTKNetwork
public typealias JobsYTKBatchJobsVoidBlock = (_ batch: YTKBatchRequest) -> Void
public typealias JobsYTKJobsVoidBlock = (_ request: YTKBaseRequest) -> Void
public typealias JobsYTKChainSuccess = (_ chain: YTKChainRequest) -> Void
public typealias JobsYTKChainFailure = (_ chain: YTKChainRequest,
                                        _ failedRequest: YTKBaseRequest) -> Void
public typealias JobsYTKChainStepCallback = (_ chain: YTKChainRequest,
                                             _ finishedRequest: YTKBaseRequest) -> Void
#endif
/// Cocoapods@Moya
#if canImport(Moya)
import Moya
public typealias jobsByMoyaResultBlock = (Result<Response, MoyaError>) -> Void
#endif
