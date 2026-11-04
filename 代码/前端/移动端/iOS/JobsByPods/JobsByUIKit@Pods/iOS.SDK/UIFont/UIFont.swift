//
//  UIFont.swift
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
    public convenience init?(medium: CGFloat) {
        self.init(name: "PingFangSC-Medium", size: medium)
    }

    public convenience init?(regular: CGFloat) {
        self.init(name: "PingFangSC-Regular", size: regular)
    }

    public convenience init?(semibold: CGFloat) {
        self.init(name: "PingFangSC-Semibold", size: semibold)
    }

    public convenience init?(light: CGFloat) {
        self.init(name: "PingFangSC-Light", size: light)
    }

    public convenience init?(dinalternate: CGFloat) {
        self.init(name: "DIN Alternate", size: dinalternate)
    }

    public convenience init?(digitial: CGFloat) {
        self.init(name: "DS-Digital-Bold", size: digitial)
    }

    public convenience init?(_ dinalternatebold: CGFloat) {
        self.init(name: "DINAlternate-Bold", size: dinalternatebold)
    }

    public convenience init?(fonteditor:CGFloat) {
        self.init(name: "fonteditor", size: fonteditor)
    }

    public convenience init?(fonteditorBold:CGFloat) {
        self.init(name: "DIN Black", size: fonteditorBold)
    }

    public convenience init?(DINCondBold:CGFloat) {
        self.init(name: "DINCond-Bold", size: DINCondBold)
    }

    public convenience init?(dinC: CGFloat) {
        self.init(name: "DIN Condensed", size: dinC)
    }
}
/**
 
     不关心语言：统一写
     label.font = .App.Regular(14)
     label.font = .App.Semibold(14)
     
     想强制某语言字体（极少用）：直接写
     label.font = .Mitr.Regular(14)
 */
extension UIFont {
    public enum App {
        public static func Regular(_ size: CGFloat) -> UIFont { pick(.regular, size) }
        public static func Medium(_ size: CGFloat) -> UIFont  { pick(.medium,  size) }
        public static func Semibold(_ size: CGFloat) -> UIFont{ pick(.semibold,size) }
        private enum W { case regular, medium, semibold }
        private static func pick(_ w: W, _ size: CGFloat) -> UIFont {
            switch Bundle.lang() {
            /// 合并处理 .vietnamese、.turkish 分支
            case .vietnamese, .turkish:
                return roboto(w, size)
            /// 处理 .thai 分支
            case .thai:
                return mitr(w, size)
            /// 处理 .arabic 分支
            case .arabic:
                return sfArabic(w, size)
            /// 未匹配已知分支时执行兜底处理
            default:
                return pingFang(w, size)
            }
        }
        private static func roboto(_ w: W, _ size: CGFloat) -> UIFont {
            switch w {
            /// 处理 .regular 分支
            case .regular:  return UIFont.Roboto.Regular(size)
            /// 处理 .medium 分支
            case .medium:   return UIFont.Roboto.Medium(size)
            /// 处理 .semibold 分支
            case .semibold: return UIFont.Roboto.Semibold(size)
            }
        }
        private static func mitr(_ w: W, _ size: CGFloat) -> UIFont {
            switch w {
            /// 处理 .regular 分支
            case .regular:  return UIFont.Mitr.Regular(size)
            /// 处理 .medium 分支
            case .medium:   return UIFont.Mitr.Medium(size)
            /// 处理 .semibold 分支
            case .semibold: return UIFont.Mitr.Semibold(size)
            }
        }
        private static func sfArabic(_ w: W, _ size: CGFloat) -> UIFont {
            switch w {
            /// 处理 .regular 分支
            case .regular:  return UIFont.SFArabic.Regular(size)
            /// 处理 .medium 分支
            case .medium:   return UIFont.SFArabic.Medium(size)
            /// 处理 .semibold 分支
            case .semibold: return UIFont.SFArabic.Semibold(size)
            }
        }
        private static func pingFang(_ w: W, _ size: CGFloat) -> UIFont {
            switch w {
            /// 处理 .regular 分支
            case .regular:  return UIFont.PingFangSC.Regular(size)
            /// 处理 .medium 分支
            case .medium:   return UIFont.PingFangSC.Medium(size)
            /// 处理 .semibold 分支
            case .semibold: return UIFont.PingFangSC.Semibold(size)
            }
        }
    }
}
