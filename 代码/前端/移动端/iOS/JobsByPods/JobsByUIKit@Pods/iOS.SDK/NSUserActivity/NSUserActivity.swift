//
//  NSUserActivity.swift
//  JobsByUIKit
//
//  Created by Jobs on 2026年8月7日，星期五.
//

import UIKit

import JobsSwiftBlock

public extension NSUserActivity {

    static func make(
        activityType: String,
        configure: jobsByNSUserActivityBlock
    ) -> NSUserActivity {
        let activity = NSUserActivity(activityType: activityType)
        configure(activity)
        return activity
    }
}
