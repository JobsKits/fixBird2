//
//  PHPickerConfiguration.swift
//  JobsByPhotosUI
//
//  Created by Jobs on 2026年5月13日，星期三.
//

import Photos
import PhotosUI

@available(iOS 14.0, macOS 13.0, *)
@available(watchOS, unavailable)
@available(tvOS, unavailable)
public extension PHPickerConfiguration {
    /// 链式设置 filter
    @discardableResult
    func byFilter(_ filter: PHPickerFilter?) -> Self {
        var result = self
        result.filter = filter
        return result
    }
    /// 链式设置 selectionLimit
    ///
    /// - 参数 limit:
    ///   - 0 表示不限制
    ///   - 小于 0 时会被矫正为 0
    @discardableResult
    func bySelectionLimit(_ limit: Int) -> Self {
        var result = self
        result.selectionLimit = max(0, limit)
        return result
    }
    /// 链式设置 preferredAssetRepresentationMode
    @discardableResult
    func byPreferredAssetRepresentationMode(_ mode: AssetRepresentationMode) -> Self {
        var result = self
        result.preferredAssetRepresentationMode = mode
        return result
    }
}

@available(iOS 15.0, macOS 13.0, *)
@available(watchOS, unavailable)
@available(tvOS, unavailable)
public extension PHPickerConfiguration {
    /// 链式设置 selection
    @discardableResult
    func bySelection(_ selection: Selection) -> Self {
        var result = self
        result.selection = selection
        return result
    }
    /// 链式设置 preselectedAssetIdentifiers
    ///
    /// 注意：
    /// - 只有通过 `PHPickerConfiguration(photoLibrary:)` 初始化时，预选资源才有效
    /// - 否则系统会报错
    @discardableResult
    func byPreselectedAssetIdentifiers(_ identifiers: [String]) -> Self {
        var result = self
        result.preselectedAssetIdentifiers = identifiers
        return result
    }
    /// 链式清空 preselectedAssetIdentifiers
    @discardableResult
    func byClearPreselectedAssetIdentifiers() -> Self {
        var result = self
        result.preselectedAssetIdentifiers = []
        return result
    }
}

@available(iOS 17.0, macOS 14.0, *)
@available(watchOS, unavailable)
public extension PHPickerConfiguration.Update {
    /// 链式设置 selectionLimit
    @discardableResult
    func bySelectionLimit(_ limit: Int) -> Self {
        var result = self
        result.selectionLimit = max(0, limit)
        return result
    }
    /// 链式设置 edgesWithoutContentMargins
    @discardableResult
    func byEdgesWithoutContentMargins(_ edges: NSDirectionalRectEdge) -> Self {
        var result = self
        result.edgesWithoutContentMargins = edges
        return result
    }
    /// 链式设置为所有边都不保留内容边距
    @discardableResult
    func byAllEdgesWithoutContentMargins() -> Self {
        var result = self
        result.edgesWithoutContentMargins = .all
        return result
    }
    /// 链式清空 edgesWithoutContentMargins
    @discardableResult
    func byNoEdgesWithoutContentMargins() -> Self {
        var result = self
        result.edgesWithoutContentMargins = []
        return result
    }
}

@available(iOS 14.0, macOS 13.0, *)
@available(watchOS, unavailable)
@available(tvOS, unavailable)
public extension PHPickerConfiguration.AssetRepresentationMode {
    /// 是否为 automatic
    var isAutomatic: Bool { self == .automatic }

    /// 是否为 current
    var isCurrent: Bool { self == .current }

    /// 是否为 compatible
    var isCompatible: Bool { self == .compatible }
}

@available(iOS 15.0, macOS 13.0, *)
@available(watchOS, unavailable)
@available(tvOS, unavailable)
public extension PHPickerConfiguration.Selection {
    /// 是否为 default
    var isDefault: Bool { self == .default }

    /// 是否为 ordered
    var isOrdered: Bool { self == .ordered }
}

@available(iOS 17.0, macOS 14.0, *)
@available(watchOS, unavailable)
public extension PHPickerConfiguration.Selection {
    /// 是否为 continuous
    var isContinuous: Bool { self == .continuous }
    /// 是否为 continuousAndOrdered
    var isContinuousAndOrdered: Bool { self == .continuousAndOrdered }
}
