//
//  JobsTheme.swift
//  JobsSwiftBaseDefines
//
//  Created by Jobs on 2026年7月29日，星期三.
//

#if os(iOS) || os(tvOS)
import UIKit
import ObjectiveC

public struct JobsThemeStyle: RawRepresentable, Codable, Hashable, Sendable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public static let light = JobsThemeStyle(rawValue: "light")
    public static let dark = JobsThemeStyle(rawValue: "dark")
}

public struct JobsThemeColorKey: RawRepresentable, Codable, Hashable, Sendable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public static let backgroundPrimary = JobsThemeColorKey(rawValue: "background.primary")
    public static let backgroundSecondary = JobsThemeColorKey(rawValue: "background.secondary")
    public static let backgroundTertiary = JobsThemeColorKey(rawValue: "background.tertiary")
    public static let backgroundGrouped = JobsThemeColorKey(rawValue: "background.grouped")
    public static let backgroundGroupedSecondary = JobsThemeColorKey(rawValue: "background.grouped.secondary")
    public static let backgroundGroupedTertiary = JobsThemeColorKey(rawValue: "background.grouped.tertiary")
    public static let textPrimary = JobsThemeColorKey(rawValue: "text.primary")
    public static let textSecondary = JobsThemeColorKey(rawValue: "text.secondary")
    public static let textTertiary = JobsThemeColorKey(rawValue: "text.tertiary")
    public static let textQuaternary = JobsThemeColorKey(rawValue: "text.quaternary")
    public static let textPlaceholder = JobsThemeColorKey(rawValue: "text.placeholder")
}

public struct JobsThemeImageKey: RawRepresentable, Codable, Hashable, Sendable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public static let themeToggle = JobsThemeImageKey(rawValue: "theme.toggle")
}

public extension Notification.Name {
    static let JobsThemeDidChange = Notification.Name("JobsThemeDidChange")
}

public enum JobsThemeError: LocalizedError {
    case resourceNotFound(String)
    case invalidPacket
    case unknownStyle(String)

    public var errorDescription: String? {
        switch self {
        case .resourceNotFound(let name):
            return "未找到主题数据包：\(name)"
        case .invalidPacket:
            return "主题数据包格式无效"
        case .unknownStyle(let style):
            return "主题数据包未定义主题：\(style)"
        }
    }
}

private struct JobsThemePacket: Decodable {
    let defaultTheme: String
    let themes: [String: JobsThemePayload]
}

private struct JobsThemePayload: Decodable {
    let colors: [String: String]
    let images: [String: String]

    private enum CodingKeys: String, CodingKey {
        case colors
        case images
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        colors = try container.decodeIfPresent([String: String].self, forKey: .colors) ?? [:]
        images = try container.decodeIfPresent([String: String].self, forKey: .images) ?? [:]
    }
}

private final class JobsThemeBindingBox {
    let apply: (AnyObject, JobsThemeCenter) -> Void

    init(apply: @escaping (AnyObject, JobsThemeCenter) -> Void) {
        self.apply = apply
    }
}

private final class JobsThemeBindingStore {
    var boxes = [String: JobsThemeBindingBox]()
}

private var jobsThemeColorKeyAssociatedKey: UInt8 = 0
private var jobsThemeImageKeyAssociatedKey: UInt8 = 0

public extension UIColor {
    var jobsThemeColorKey: JobsThemeColorKey? {
        objc_getAssociatedObject(self, &jobsThemeColorKeyAssociatedKey) as? JobsThemeColorKey
    }
}

public extension UIImage {
    var jobsThemeImageKey: JobsThemeImageKey? {
        objc_getAssociatedObject(self, &jobsThemeImageKeyAssociatedKey) as? JobsThemeImageKey
    }
}

public final class JobsThemeCenter {
    public static let shared = JobsThemeCenter()

    private let stateLock = NSLock()
    private let defaultsKey = "JobsTheme.currentStyle"
    private let bindings = NSMapTable<AnyObject, JobsThemeBindingStore>(
        keyOptions: .weakMemory,
        valueOptions: .strongMemory
    )
    private var packet: JobsThemePacket?
    private var resourceBundle = Bundle.main
    private var style = JobsThemeStyle.light

    private init() {}

    public var currentStyle: JobsThemeStyle {
        stateLock.lock()
        defer {
            stateLock.unlock()
        }
        return style
    }

    public var isDarkMode: Bool {
        currentStyle == .dark
    }

    @discardableResult
    public func configure(resource name: String,
                          fileExtension: String = "json",
                          bundle: Bundle = .main) throws -> JobsThemeStyle {
        guard let url = bundle.url(forResource: name, withExtension: fileExtension) else {
            throw JobsThemeError.resourceNotFound("\(name).\(fileExtension)")
        }
        let data = try Data(contentsOf: url)
        let decoded = try JSONDecoder().decode(JobsThemePacket.self, from: data)
        guard !decoded.themes.isEmpty,
              decoded.themes[decoded.defaultTheme] != nil else {
            throw JobsThemeError.invalidPacket
        }
        let savedStyle = UserDefaults.standard.string(forKey: defaultsKey)
        let initialStyle = savedStyle.flatMap { decoded.themes[$0] == nil ? nil : $0 }
            ?? decoded.defaultTheme
        let configuredStyle = JobsThemeStyle(rawValue: initialStyle)
        stateLock.lock()
        let previous = (packet, resourceBundle)
        packet = decoded
        resourceBundle = bundle
        style = configuredStyle
        stateLock.unlock()
        // 注入 Bundle 的关联捕获或子类析构可能重入主题读取。
        withExtendedLifetime(previous) {}
        applyBindings()
        return configuredStyle
    }

    @discardableResult
    public func setStyle(_ newStyle: JobsThemeStyle) -> JobsThemeStyle {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.setStyle(newStyle)
            }
            return currentStyle
        }
        stateLock.lock()
        guard packet?.themes[newStyle.rawValue] != nil, style != newStyle else {
            let current = style
            stateLock.unlock()
            return current
        }
        style = newStyle
        UserDefaults.standard.set(newStyle.rawValue, forKey: defaultsKey)
        stateLock.unlock()
        applyBindings()
        NotificationCenter.default.post(
            name: .JobsThemeDidChange,
            object: self,
            userInfo: ["style": newStyle.rawValue]
        )
        return newStyle
    }

    @discardableResult
    public func toggle() -> JobsThemeStyle {
        setStyle(isDarkMode ? .light : .dark)
    }

    public func color(_ key: JobsThemeColorKey) -> UIColor {
        let color = resolvedColor(key)
        objc_setAssociatedObject(
            color,
            &jobsThemeColorKeyAssociatedKey,
            key,
            .OBJC_ASSOCIATION_RETAIN
        )
        return color
    }

    public func resolvedColor(_ key: JobsThemeColorKey) -> UIColor {
        stateLock.lock()
        let current = style
        let value = packet?.themes[current.rawValue]?.colors[key.rawValue]
        stateLock.unlock()
        if let value,
           let color = Self.color(from: value) {
            return color
        }
        return Self.fallbackColor(for: key, style: current)
    }

    public func image(_ key: JobsThemeImageKey) -> UIImage? {
        guard let image = resolvedImage(key) else { return nil }
        objc_setAssociatedObject(
            image,
            &jobsThemeImageKeyAssociatedKey,
            key,
            .OBJC_ASSOCIATION_RETAIN
        )
        return image
    }

    public func resolvedImage(_ key: JobsThemeImageKey) -> UIImage? {
        stateLock.lock()
        let current = style
        let value = packet?.themes[style.rawValue]?.images[key.rawValue]
            ?? Self.fallbackImageName(for: key, style: current)
        let bundle = resourceBundle
        stateLock.unlock()
        guard let value else { return nil }
        if value.hasPrefix("sf:") {
            if #available(iOS 13.0, tvOS 13.0, *) {
                return UIImage(systemName: String(value.dropFirst(3)))
            };return nil
        }
        let assetName = value.hasPrefix("asset:")
            ? String(value.dropFirst(6))
            : value
        return UIImage(named: assetName, in: bundle, compatibleWith: nil)
    }

    public func bind(_ object: AnyObject,
                     slot: String,
                     apply: @escaping (AnyObject, JobsThemeCenter) -> Void) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self, weak object] in
                guard let self, let object else { return }
                self.bind(object, slot: slot, apply: apply)
            }
            return
        }
        let store = bindings.object(forKey: object) ?? JobsThemeBindingStore()
        store.boxes[slot] = JobsThemeBindingBox(apply: apply)
        bindings.setObject(store, forKey: object)
        apply(object, self)
    }

    public func unbind(_ object: AnyObject, slot: String) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self, weak object] in
                guard let self, let object else { return }
                self.unbind(object, slot: slot)
            }
            return
        }
        guard let store = bindings.object(forKey: object) else { return }
        store.boxes.removeValue(forKey: slot)
        if store.boxes.isEmpty {
            bindings.removeObject(forKey: object)
        }
    }

    private func applyBindings() {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.applyBindings()
            }
            return
        }
        let objects = bindings.keyEnumerator().allObjects
        let snapshot = objects.map { object -> (AnyObject, [(String, JobsThemeBindingBox)]) in
            let target = object as AnyObject
            let boxes = bindings.object(forKey: target)?.boxes.map { ($0.key, $0.value) } ?? []
            return (target, boxes)
        }
        for (object, boxes) in snapshot {
            for (slot, box) in boxes {
                guard bindings.object(forKey: object)?.boxes[slot] === box else {
                    continue
                }
                box.apply(object, self)
            }
        }
    }

    private static func color(from value: String) -> UIColor? {
        let hex = value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")
        guard hex.count == 6 || hex.count == 8,
              let number = UInt64(hex, radix: 16) else { return nil }
        let hasAlpha = hex.count == 8
        let red = CGFloat((number >> (hasAlpha ? 24 : 16)) & 0xFF) / 255
        let green = CGFloat((number >> (hasAlpha ? 16 : 8)) & 0xFF) / 255
        let blue = CGFloat((number >> (hasAlpha ? 8 : 0)) & 0xFF) / 255
        let alpha = hasAlpha ? CGFloat(number & 0xFF) / 255 : 1
        return UIColor(red: red, green: green, blue: blue, alpha: alpha)
    }

    private static func fallbackColor(for key: JobsThemeColorKey,
                                      style: JobsThemeStyle) -> UIColor {
        let darkModeEnabled = style == .dark
        switch key {
        case .backgroundPrimary:
            return darkModeEnabled ? .black : .white
        case .backgroundSecondary:
            return darkModeEnabled
                ? UIColor(red: 0x1C / 255, green: 0x1C / 255, blue: 0x1E / 255, alpha: 1)
                : UIColor(red: 0xF2 / 255, green: 0xF2 / 255, blue: 0xF7 / 255, alpha: 1)
        case .backgroundTertiary:
            return darkModeEnabled
                ? UIColor(red: 0x2C / 255, green: 0x2C / 255, blue: 0x2E / 255, alpha: 1)
                : .white
        case .backgroundGrouped:
            return darkModeEnabled ? .black : UIColor(white: 0xF2 / 255, alpha: 1)
        case .backgroundGroupedSecondary:
            return darkModeEnabled
                ? UIColor(red: 0x1C / 255, green: 0x1C / 255, blue: 0x1E / 255, alpha: 1)
                : .white
        case .backgroundGroupedTertiary:
            return darkModeEnabled
                ? UIColor(red: 0x2C / 255, green: 0x2C / 255, blue: 0x2E / 255, alpha: 1)
                : UIColor(red: 0xF2 / 255, green: 0xF2 / 255, blue: 0xF7 / 255, alpha: 1)
        case .textPrimary:
            return darkModeEnabled ? .white : .black
        case .textSecondary:
            return darkModeEnabled
                ? UIColor(red: 0xEB / 255, green: 0xEB / 255, blue: 0xF5 / 255, alpha: 0.6)
                : UIColor(red: 0x3C / 255, green: 0x3C / 255, blue: 0x43 / 255, alpha: 0.6)
        case .textTertiary:
            return darkModeEnabled
                ? UIColor(red: 0xEB / 255, green: 0xEB / 255, blue: 0xF5 / 255, alpha: 0.3)
                : UIColor(red: 0x3C / 255, green: 0x3C / 255, blue: 0x43 / 255, alpha: 0.3)
        case .textQuaternary:
            return darkModeEnabled
                ? UIColor(red: 0xEB / 255, green: 0xEB / 255, blue: 0xF5 / 255, alpha: 0.18)
                : UIColor(red: 0x3C / 255, green: 0x3C / 255, blue: 0x43 / 255, alpha: 0.18)
        case .textPlaceholder:
            return darkModeEnabled
                ? UIColor(red: 0xEB / 255, green: 0xEB / 255, blue: 0xF5 / 255, alpha: 0.3)
                : UIColor(red: 0x3C / 255, green: 0x3C / 255, blue: 0x43 / 255, alpha: 0.3)
        default:
            return .clear
        }
    }

    private static func fallbackImageName(for key: JobsThemeImageKey,
                                          style: JobsThemeStyle) -> String? {
        guard key == .themeToggle else { return nil }
        return style == .dark ? "sf:sun.max.circle.fill" : "sf:moon.circle.fill"
    }
}
#endif
