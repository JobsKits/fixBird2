//
//  DateFormatter+预置.swift
//  JobsByUIKit
//
//  Created by Jobs on 2026年5月13日，星期三.
//

#if os(OSX)
import AppKit
#elseif os(iOS) || os(tvOS)
import UIKit
#endif

import JobsSwiftBlock
import JobsSwiftDSL

// MARK: - 工厂 & 预置
/**
 
     // 1) 最全日志
     let f = DateFormatter.jobs_fullPrinter()
     print(f.format(Date()))

     // 2) ISO8601 毫秒
     let iso = DateFormatter.jobs_iso8601Millis()
     let s = iso.format(Date())
     let d = iso.parse(s)

     // 3) UI 本地化
     let uiFmt = DateFormatter.jobs_localizedYMD()
     label.text = uiFmt.format(Date())
 */
extension DateFormatter {
    /// 统一入口：创建后在同一个 closure 内完成链式配置。
    public static func make(_ configure: jobsByDateFormatterBlock) -> DateFormatter {
        let formatter = DateFormatter()
        configure(formatter)
        return formatter
    }

    /// “尽可能最全”的打印器：yyyy-MM-dd HH:mm:ss.SSS Z（完整时区）(区域名) 星期 纪元
    // MARK: - 用于日志，不建议把字符串入库
    public static func jobs_fullPrinter(
        locale: Locale = Locale(identifier: "zh_CN"),
        timeZone: TimeZone = .current,
        calendar: Calendar = Calendar(identifier: .gregorian)
    ) -> DateFormatter {
        DateFormatter.make { formatter in
            formatter
                .byCalendar(calendar)
                .byLocale(locale)
                .byTimeZone(timeZone)
                .byDateFormat("yyyy-MM-dd HH:mm:ss.SSS ZZZZZ (VV) EEEE G")
        }
    }
    // MARK: - ISO8601（带毫秒，时区 Z/±hh:mm）
    public static func jobs_iso8601Millis() -> DateFormatter {
        DateFormatter.make { formatter in
            formatter
                .byLocale(Locale(identifier: "en_US_POSIX"))
                .byTimeZone(TimeZone(secondsFromGMT: 0)!)
                .byDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSSXXXXX")
        }
    }
    // MARK: - RFC3339（常见后端日志/接口）
    public static func jobs_rfc3339() -> DateFormatter {
        DateFormatter.make { formatter in
            formatter
                .byLocale(Locale(identifier: "en_US_POSIX"))
                .byTimeZone(TimeZone(secondsFromGMT: 0)!)
                .byDateFormat("yyyy-MM-dd'T'HH:mm:ssXXXXX")
        }
    }
    // MARK: - 本地化模板：按地区自动排布年月日（适合 UI 展示）
    public static func jobs_localizedYMD(
        locale: Locale = .current
    ) -> DateFormatter {
        DateFormatter.make { formatter in
            formatter
                .byLocale(locale)
                .byLocalizedTemplate("yMd") // 例如 en_US -> 1/2/2025, zh_CN -> 2025/1/2
        }
    }
}
