//
//  UIDocumentPickerViewController+Workbench.swift
//  RepairWorkbench
//
//  Created by Jobs on 2026年10月15日，星期四.
//

import UIKit
import UniformTypeIdentifiers

import JobsByUIKit

extension UIDocumentPickerViewController {
    // 带参系统构造集中在真实类型的工厂内；使用安全作用域读取，不复制原件到应用文件夹。
    static func make(delegate: UIDocumentPickerDelegate) -> UIDocumentPickerViewController {
        return UIDocumentPickerViewController(forOpeningContentTypes: [.png, .jpeg, .pdf, .mpeg4Movie, .mp3, .wav], asCopy: false)
            .byDelegate(delegate)
            .byAllowsMultipleSelection(false)
    }
}
