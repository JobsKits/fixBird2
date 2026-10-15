//
//  WBDataRunner.swift
//  RepairWorkbenchTests
//
//  Created by Jobs on 2026年10月15日，星期四.
//

import Foundation

@main
struct WBDataRunner {
    @MainActor
    static func main() {
        var failures = 0
        for (name, work) in WBDataScenarios.all {
            do {
                try work()
                print("PASS " + name)
            } catch {
                failures += 1
                print("FAIL " + name + ": " + error.localizedDescription)
            }
        }
        print("RESULT cases=\(WBDataScenarios.all.count) failures=\(failures) skips=0")
        if failures > 0 {
            exit(1)
        }
    }
}
