//
//  UIDatePicker+DSL.swift
//  JobsSwiftDSL
//
//  Created by Jobs on 2026年8月3日，星期一.
//

#if os(OSX)
import AppKit
#elseif os(iOS) || os(tvOS)
import UIKit
#endif

#if os(iOS) || os(tvOS)
extension UIDatePicker {
    @discardableResult
    public func byDatePickerMode(_ mode: UIDatePicker.Mode) -> Self {
        datePickerMode = mode
        return self
    }

    #if os(iOS)
    @available(iOS 13.4, *)
    @discardableResult
    public func byPreferredDatePickerStyle(_ style: UIDatePickerStyle) -> Self {
        preferredDatePickerStyle = style
        return self
    }

    /// 兼容旧部署版本地进入滚轮样式，同时保持 UIDatePicker 主链不断开。
    @discardableResult
    public func byWheelsStyleIfAvailable() -> Self {
        if #available(iOS 13.4, *) {
            preferredDatePickerStyle = .wheels
        };return self
    }
    #endif

    @discardableResult
    public func byLocale(_ locale: Locale?) -> Self {
        self.locale = locale
        return self
    }

    @discardableResult
    public func byCalendar(_ calendar: Calendar?) -> Self {
        self.calendar = calendar
        return self
    }

    @discardableResult
    public func byTimeZone(_ timeZone: TimeZone?) -> Self {
        self.timeZone = timeZone
        return self
    }

    @discardableResult
    public func byDate(_ date: Date, animated: Bool = false) -> Self {
        setDate(date, animated: animated)
        return self
    }

    @discardableResult
    public func byDateByAnimated(_ date: Date) -> Self {
        byDate(date, animated: true)
    }

    @discardableResult
    public func byDateBy(_ date: Date) -> Self {
        byDate(date)
    }

    @discardableResult
    public func byMinimumDate(_ date: Date?) -> Self {
        minimumDate = date
        return self
    }

    @discardableResult
    public func byMaximumDate(_ date: Date?) -> Self {
        maximumDate = date
        return self
    }

    @discardableResult
    public func byCountDownDuration(_ duration: TimeInterval) -> Self {
        countDownDuration = duration
        return self
    }

    @discardableResult
    public func byMinuteInterval(_ interval: Int) -> Self {
        minuteInterval = interval
        return self
    }

    @available(iOS 15.0, tvOS 15.0, *)
    @discardableResult
    public func byRoundsToMinuteInterval(_ enabled: Bool) -> Self {
        roundsToMinuteInterval = enabled
        return self
    }
}
#endif
