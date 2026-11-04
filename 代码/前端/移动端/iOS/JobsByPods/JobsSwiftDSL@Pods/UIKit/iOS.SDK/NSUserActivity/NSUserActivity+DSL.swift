//
//  NSUserActivity+DSL.swift
//  JobsSwiftDSL
//
//  Created by Jobs on 2026年8月7日，星期五.
//

#if os(iOS)
import Foundation

public extension NSUserActivity {

    @discardableResult
    func byTitle(_ value: String?) -> Self {
        title = value
        return self
    }

    @discardableResult
    func byUserInfo(_ value: [AnyHashable: Any]?) -> Self {
        userInfo = value
        return self
    }

    @discardableResult
    func byAddUserInfoEntriesFromDictionary(_ value: [AnyHashable: Any]) -> Self {
        addUserInfoEntries(from: value)
        return self
    }

    @discardableResult
    func byRequiredUserInfoKeys(_ value: Set<String>?) -> Self {
        requiredUserInfoKeys = value
        return self
    }

    @discardableResult
    func byNeedsSave(_ value: Bool) -> Self {
        needsSave = value
        return self
    }

    @discardableResult
    func byWebpageURL(_ value: URL?) -> Self {
        webpageURL = value
        return self
    }

    @discardableResult
    func byReferrerURL(_ value: URL?) -> Self {
        referrerURL = value
        return self
    }

    @discardableResult
    func byExpirationDate(_ value: Date?) -> Self {
        expirationDate = value
        return self
    }

    @discardableResult
    func byKeywords(_ value: Set<String>) -> Self {
        keywords = value
        return self
    }

    @discardableResult
    func bySupportsContinuationStreams(_ value: Bool) -> Self {
        supportsContinuationStreams = value
        return self
    }

    @discardableResult
    func byDelegate(_ value: NSUserActivityDelegate?) -> Self {
        delegate = value
        return self
    }

    @available(iOS 13.0, *)
    @discardableResult
    func byTargetContentIdentifier(_ value: String?) -> Self {
        targetContentIdentifier = value
        return self
    }

    @discardableResult
    func byEligibleForHandoff(_ value: Bool) -> Self {
        isEligibleForHandoff = value
        return self
    }

    @discardableResult
    func byEligibleForSearch(_ value: Bool) -> Self {
        isEligibleForSearch = value
        return self
    }

    @discardableResult
    func byEligibleForPublicIndexing(_ value: Bool) -> Self {
        isEligibleForPublicIndexing = value
        return self
    }

    @discardableResult
    func byEligibleForPrediction(_ value: Bool) -> Self {
        isEligibleForPrediction = value
        return self
    }

    @discardableResult
    func byPersistentIdentifier(_ value: NSUserActivityPersistentIdentifier?) -> Self {
        persistentIdentifier = value
        return self
    }

    @discardableResult
    func byBecomeCurrent() -> Self {
        becomeCurrent()
        return self
    }

    @discardableResult
    func byResignCurrent() -> Self {
        resignCurrent()
        return self
    }

    @discardableResult
    func byInvalidate() -> Self {
        invalidate()
        return self
    }
}
#endif
