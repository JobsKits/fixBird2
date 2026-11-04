//
//  URL.swift
//  JobsByUIKit
//
//  Created by Jobs on 2026年5月13日，星期三.
//

#if os(OSX)
import AppKit
#elseif os(iOS) || os(tvOS)
import UIKit
#endif

extension URL {
    /// 是否 http/https 远程资源
    public var isHTTPRemote: Bool {
        guard let s = scheme?.lowercased() else { return false };return s == "http" || s == "https"
    }
    /// 同步获取图片：仅本地/文件可用；远程 URL 不支持同步返回，直接给空图并打印提示
    public var img: UIImage {
        if isHTTPRemote {
            print("🚫 检测到网络 URL：\(self.absoluteString)，无法同步返回图片")
            return UIImage.make { _ in }
        }
        if isFileURL {
            return UIImage(contentsOfFile: path) ?? UIImage.make { _ in }
        }
        // 兜底：当作 Bundle 资源名（取最后路径段去扩展名）
        let name = self.deletingPathExtension().lastPathComponent
        return UIImage(named: name) ?? UIImage.make { _ in }
    }
}
