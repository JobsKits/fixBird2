//
//  WBTransport.swift
//  RepairWorkbench
//
//  Created by Jobs on 2026年10月15日，星期四.
//

import Foundation

@MainActor
protocol WBTransport {
    /// 生产适配器及测试替身均在主线程交付结果。
    func send(_ request: WBRequest, completion: @escaping (Result<WBJSON, WBError>) -> Void)
}
