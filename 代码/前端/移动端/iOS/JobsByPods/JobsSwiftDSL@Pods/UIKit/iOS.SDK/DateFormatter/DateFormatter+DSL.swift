//
//  DateFormatter+DSL.swift
//  JobsByUIKit
//
//  Created by Jobs on 2026年5月13日，星期三.
//

#if os(OSX)
import AppKit
#elseif os(iOS) || os(tvOS)
import UIKit
#endif

extension DateFormatter {
    // MARK: - Format / Template
    /// 直接指定 dateFormat（自定义格式优先于 dateStyle/timeStyle）
    @discardableResult
    public func byDateFormat(_ format: String) -> Self {
        self.dateFormat = format
        return self
    }
    /// iOS/macOS 会按本地化模板生成 format（适合“年/月/日/时区/星期”等可本地化展示）
    @available(iOS 8.0, tvOS 9.0, macOS 10.10, *)
    @discardableResult
    public func byLocalizedTemplate(_ template: String, locale: Locale? = nil) -> Self {
        if let locale { self.locale = locale }
        self.setLocalizedDateFormatFromTemplate(template)
        return self
    }
    // MARK: - Styles（拆分写，避免 byStyles 一把梭）
    /// 单独设置 dateStyle；当启用样式（!= .none）时会清掉自定义 dateFormat
    @discardableResult
    public func byDateStyle(_ style: DateFormatter.Style) -> Self {
        self.dateStyle = style
        if style != .none { self.dateFormat = nil };return self
    }
    /// 单独设置 timeStyle；当启用样式（!= .none）时会清掉自定义 dateFormat
    @discardableResult
    public func byTimeStyle(_ style: DateFormatter.Style) -> Self {
        self.timeStyle = style
        if style != .none { self.dateFormat = nil };return self
    }
    /// 仍保留一个组合便捷写法（内部逻辑与单独写一致）
    @discardableResult
    public func byStyles(date: DateFormatter.Style = .none,
                  time: DateFormatter.Style = .none) -> Self {
        self.dateStyle = date
        self.timeStyle = time
        // ⚠️ 只有启用样式时才清掉自定义 format
        if date != .none || time != .none { self.dateFormat = nil };return self
    }
    // MARK: - Locale / Calendar / TimeZone
    @discardableResult
    public func byLocale(_ locale: Locale?) -> Self {
        self.locale = locale
        return self
    }

    @discardableResult
    public func byTimeZone(_ tz: TimeZone?) -> Self {
        self.timeZone = tz
        return self
    }

    @discardableResult
    public func byCalendar(_ calendar: Calendar?) -> Self {
        self.calendar = calendar
        return self
    }

    @discardableResult
    public func byGeneratesCalendarDates(_ on: Bool = true) -> Self {
        self.generatesCalendarDates = on
        return self
    }

    @discardableResult
    public func byFormatterBehavior(_ behavior: DateFormatter.Behavior) -> Self {
        self.formatterBehavior = behavior
        return self
    }
    // MARK: - Parsing / Fallback
    /// 宽松解析：比如 "2025/1/2"、"2025-01-02" 都尽量解析
    @discardableResult
    public func byLenient(_ on: Bool = true) -> Self {
        self.isLenient = on
        return self
    }
    /// 相对日期（Today/Yesterday 等）——中文/本地化由 locale 决定
    @discardableResult
    public func byDoesRelativeDateFormatting(_ on: Bool = true) -> Self {
        self.doesRelativeDateFormatting = on
        return self
    }
    /// 兼容原来的命名
    @discardableResult
    public func byRelativeDateFormatting(_ on: Bool = true) -> Self {
        return byDoesRelativeDateFormatting(on)
    }
    /// 解析两位年份的起始基准（比如 69 -> 1969/2069 的边界）
    @discardableResult
    public func byTwoDigitStartDate(_ date: Date?) -> Self {
        self.twoDigitStartDate = date
        return self
    }
    /// 解析缺省 date（当字符串缺失年月日/时分秒时用于补齐）
    @discardableResult
    public func byDefaultDate(_ date: Date?) -> Self {
        self.defaultDate = date
        return self
    }
    // MARK: - Formatting Context
    /// 上下文（标题/独立文本），会影响大小写等本地化细节
    @available(iOS 8.0, tvOS 9.0, macOS 10.10, *)
    @discardableResult
    public func byFormattingContext(_ ctx: Formatter.Context) -> Self {
        self.formattingContext = ctx
        return self
    }
    // MARK: - Symbols（按属性逐个拆分）
    @discardableResult
    public func byAMSymbol(_ am: String) -> Self {
        self.amSymbol = am
        return self
    }

    @discardableResult
    public func byPMSymbol(_ pm: String) -> Self {
        self.pmSymbol = pm
        return self
    }

    @discardableResult
    public func byEraSymbols(_ symbols: [String]) -> Self {
        self.eraSymbols = symbols
        return self
    }

    @discardableResult
    public func byLongEraSymbols(_ symbols: [String]) -> Self {
        self.longEraSymbols = symbols
        return self
    }

    @discardableResult
    public func byMonthSymbols(_ symbols: [String]) -> Self {
        self.monthSymbols = symbols
        return self
    }

    @discardableResult
    public func byShortMonthSymbols(_ symbols: [String]) -> Self {
        self.shortMonthSymbols = symbols
        return self
    }

    @discardableResult
    public func byVeryShortMonthSymbols(_ symbols: [String]) -> Self {
        self.veryShortMonthSymbols = symbols
        return self
    }

    @discardableResult
    public func byStandaloneMonthSymbols(_ symbols: [String]) -> Self {
        self.standaloneMonthSymbols = symbols
        return self
    }

    @discardableResult
    public func byShortStandaloneMonthSymbols(_ symbols: [String]) -> Self {
        self.shortStandaloneMonthSymbols = symbols
        return self
    }

    @discardableResult
    public func byVeryShortStandaloneMonthSymbols(_ symbols: [String]) -> Self {
        self.veryShortStandaloneMonthSymbols = symbols
        return self
    }

    @discardableResult
    public func byWeekdaySymbols(_ symbols: [String]) -> Self {
        self.weekdaySymbols = symbols
        return self
    }

    @discardableResult
    public func byShortWeekdaySymbols(_ symbols: [String]) -> Self {
        self.shortWeekdaySymbols = symbols
        return self
    }

    @discardableResult
    public func byVeryShortWeekdaySymbols(_ symbols: [String]) -> Self {
        self.veryShortWeekdaySymbols = symbols
        return self
    }

    @discardableResult
    public func byStandaloneWeekdaySymbols(_ symbols: [String]) -> Self {
        self.standaloneWeekdaySymbols = symbols
        return self
    }

    @discardableResult
    public func byShortStandaloneWeekdaySymbols(_ symbols: [String]) -> Self {
        self.shortStandaloneWeekdaySymbols = symbols
        return self
    }

    @discardableResult
    public func byVeryShortStandaloneWeekdaySymbols(_ symbols: [String]) -> Self {
        self.veryShortStandaloneWeekdaySymbols = symbols
        return self
    }

    @discardableResult
    public func byQuarterSymbols(_ symbols: [String]) -> Self {
        self.quarterSymbols = symbols
        return self
    }

    @discardableResult
    public func byShortQuarterSymbols(_ symbols: [String]) -> Self {
        self.shortQuarterSymbols = symbols
        return self
    }

    @discardableResult
    public func byStandaloneQuarterSymbols(_ symbols: [String]) -> Self {
        self.standaloneQuarterSymbols = symbols
        return self
    }

    @discardableResult
    public func byShortStandaloneQuarterSymbols(_ symbols: [String]) -> Self {
        self.shortStandaloneQuarterSymbols = symbols
        return self
    }
    // MARK: - Calendar Start
    @discardableResult
    public func byGregorianStartDate(_ date: Date?) -> Self {
        self.gregorianStartDate = date
        return self
    }
    // MARK: - Convenience
    /// 格式化
    public func format(_ date: Date) -> String {
        string(from: date)
    }
    /// 解析
    public func parse(_ text: String) -> Date? {
        date(from: text)
    }
}
