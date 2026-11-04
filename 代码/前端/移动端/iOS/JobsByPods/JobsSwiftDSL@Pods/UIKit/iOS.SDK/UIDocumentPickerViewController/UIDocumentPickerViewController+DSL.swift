//
//  UIDocumentPickerViewController+DSL.swift
//  JobsByUIKit
//
//  Created by Jobs on 2026年5月13日，星期三.
//

#if os(OSX)
import AppKit
#elseif os(iOS) || os(tvOS)
import UIKit
#endif
#if canImport(UniformTypeIdentifiers)
import UniformTypeIdentifiers // iOS 14+
#endif

extension UIDocumentPickerViewController {
    // MARK: Factory (Open / Import)
    /// iOS14+：打开/导入文件（推荐）
    @available(iOS 14.0, *)
    public static func jobs_opening(
        _ contentTypes: [UTType],
        asCopy: Bool = true,
        allowsMultipleSelection: Bool = false,
        shouldShowFileExtensions: Bool = true
    ) -> UIDocumentPickerViewController {
        UIDocumentPickerViewController(forOpeningContentTypes: contentTypes, asCopy: asCopy)
            .byAllowsMultipleSelection(allowsMultipleSelection)
            .byShouldShowFileExtensions(shouldShowFileExtensions)
    }
    /// 只选 .xlsx（推荐，最精准）
    @available(iOS 14.0, *)
    public static func jobs_openXLSX(
        asCopy: Bool = true,
        allowsMultipleSelection: Bool = false,
        shouldShowFileExtensions: Bool = true
    ) -> UIDocumentPickerViewController {
        jobs_opening(
            [UTType(filenameExtension: "xlsx") ?? .data],
            asCopy: asCopy,
            allowsMultipleSelection: allowsMultipleSelection,
            shouldShowFileExtensions: shouldShowFileExtensions
        )
    }
    /// 常规“表格类”（Numbers/Excel 等更泛）
    @available(iOS 14.0, *)
    public static func jobs_openSpreadsheet(
        asCopy: Bool = true,
        allowsMultipleSelection: Bool = false,
        shouldShowFileExtensions: Bool = true
    ) -> UIDocumentPickerViewController {
        jobs_opening(
            [.spreadsheet],
            asCopy: asCopy,
            allowsMultipleSelection: allowsMultipleSelection,
            shouldShowFileExtensions: shouldShowFileExtensions
        )
    }
    // MARK: Factory (Export)
    /// iOS14+：导出/移动文件
    @available(iOS 14.0, *)
    public static func jobs_exporting(
        _ urls: [URL],
        asCopy: Bool = false,
        shouldShowFileExtensions: Bool = true
    ) -> UIDocumentPickerViewController {
        UIDocumentPickerViewController(forExporting: urls, asCopy: asCopy)
            .byShouldShowFileExtensions(shouldShowFileExtensions)
    }
}
// MARK: - 直接赋值@单参数
extension UIDocumentPickerViewController {
    @discardableResult
    public func byDelegate(_ v: UIDocumentPickerDelegate?) -> Self {
        self.delegate = v
        return self
    }

    @discardableResult
    public func byAllowsMultipleSelection(_ v: Bool) -> Self {
        self.allowsMultipleSelection = v
        return self
    }
    @available(iOS 13.0, *)
    @discardableResult
    public func byShouldShowFileExtensions(_ v: Bool) -> Self {
        self.shouldShowFileExtensions = v
        return self
    }
    @available(iOS 13.0, *)
    @discardableResult
    public func byDirectoryURL(_ url: URL?) -> Self {
        self.directoryURL = url
        return self
    }
}
// MARK: - 闭包重载@单参数
extension UIDocumentPickerViewController {
    @discardableResult
    public func byDelegate(_ builder: () -> UIDocumentPickerDelegate?) -> Self {
        self.delegate = builder()
        return self
    }

    @discardableResult
    public func byAllowsMultipleSelection(_ builder: () -> Bool) -> Self {
        self.allowsMultipleSelection = builder()
        return self
    }
    @available(iOS 13.0, *)
    @discardableResult
    public func byShouldShowFileExtensions(_ builder: () -> Bool) -> Self {
        self.shouldShowFileExtensions = builder()
        return self
    }
    @available(iOS 13.0, *)
    @discardableResult
    public func byDirectoryURL(_ builder: () -> URL?) -> Self {
        self.directoryURL = builder()
        return self
    }
}
