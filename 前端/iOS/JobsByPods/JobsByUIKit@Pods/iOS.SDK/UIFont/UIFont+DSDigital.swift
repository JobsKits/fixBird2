//
//  UIFont+DSDigital.swift
//  JobsByUIKit
//
//  Created by Jobs on 2026年5月13日，星期三.
//

#if os(OSX)
import AppKit
#elseif os(iOS) || os(tvOS)
import UIKit
#endif

extension UIFont {
    public enum DSDigital {
        public static func Regular(_ size: CGFloat) -> UIFont {
            switch Bundle.lang() {
            /// 合并处理 .vietnamese、.turkish 分支
            case .vietnamese, .turkish:
                return UIFont.Roboto.Regular(size)
            /// 处理 .thai 分支
            case .thai:
                return UIFont.Mitr.Regular(size)
            /// 处理 .arabic 分支
            case .arabic:
                return UIFont.SFArabic.Regular(size)
            /// 未匹配已知分支时执行兜底处理
            default:
                return make("DS-Digital", size, fallback: .regular)
            }
        }
        private static func make(_ name: String,
                                 _ size: CGFloat,
                                 fallback: UIFont.Weight) -> UIFont {
            UIFont(name: name, size: size) ?? .systemFont(ofSize: size, weight: fallback)
        }
    }
}
