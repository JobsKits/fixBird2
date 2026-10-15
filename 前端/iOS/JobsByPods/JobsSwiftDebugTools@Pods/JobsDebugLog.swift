//
//  JobsDebugLog.swift
//  JobsSwiftDebugTools
//
//  Created by Jobs on 2026年5月13日，星期三.
//

#if DEBUG
@inline(__always)
private func _jobsAnimLog(_ items: Any..., file: String = #fileID, line: Int = #line) {
    let msg = items.map { String(describing: $0) }.joined(separator: " ")
    print("🧪[JobsAnimNum]", msg, "(\(file):\(line))")
}
#else
@inline(__always)
private func _jobsAnimLog(_ items: Any..., file: String = #fileID, line: Int = #line) {}
#endif
