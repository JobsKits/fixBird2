//
//  MTLDepthStencilDescriptor.swift
//  JobsSwiftMetalKit
//
//  Created by Jobs on 2026年5月13日，星期三.
//

import Metal

public extension MTLDepthStencilDescriptor {
    /// 通用 dsl 入口
    @discardableResult
    func dsl(_ make: (MTLDepthStencilDescriptor) -> Void) -> Self {
        make(self); return self
    }

    @discardableResult
    func byLabel(_ text: String?) -> Self { self.label = text; return self }

    @discardableResult
    func byDepthCompare(_ fn: MTLCompareFunction) -> Self { self.depthCompareFunction = fn; return self }

    @discardableResult
    func byDepthWriteEnabled(_ on: Bool) -> Self { self.isDepthWriteEnabled = on; return self }
    // 可选：前/后模板快速配置
    @discardableResult
    func byFrontStencil(_ make: (MTLStencilDescriptor) -> Void) -> Self {
        if self.frontFaceStencil == nil { self.frontFaceStencil = MTLStencilDescriptor() }
        make(self.frontFaceStencil); return self
    }

    @discardableResult
    func byBackStencil(_ make: (MTLStencilDescriptor) -> Void) -> Self {
        if self.backFaceStencil == nil { self.backFaceStencil = MTLStencilDescriptor() }
        make(self.backFaceStencil); return self
    }
}
