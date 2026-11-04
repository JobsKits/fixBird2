//
//  NSAttributedString.swift
//  JobsSwiftFoundation
//
//  Created by Jobs on 2026年5月13日，星期三.
//

#if os(OSX)
import AppKit
#elseif os(iOS) || os(tvOS)
import UIKit
#endif

extension NSAttributedString {
    public func boundingHeight(width: CGFloat, fontFallback: UIFont) -> CGFloat {
        guard width > 0 else { return 0 }
        let rect = boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        )
        let h = rect.height
        if h > 0 { return ceil(h) }
        let rect2 = (string as NSString).boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: fontFallback],
            context: nil
        );return ceil(rect2.height)
    }
}
