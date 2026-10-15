//
//  MTLRenderPipelineDescriptor.swift
//  JobsSwiftMetalKit
//
//  Created by Jobs on 2026年5月13日，星期三.
//

import Metal
import MetalKit

public extension MTLRenderPipelineDescriptor {
    /// 通用 dsl 入口
    @discardableResult
    func dsl(_ make: (MTLRenderPipelineDescriptor) -> Void) -> Self {
        make(self); return self
    }
    // MARK: - 基础字段
    @discardableResult
    func byLabel(_ text: String?) -> Self { self.label = text; return self }

    @discardableResult
    func byVertexFunction(_ f: MTLFunction?) -> Self { self.vertexFunction = f; return self }

    @discardableResult
    func byFragmentFunction(_ f: MTLFunction?) -> Self { self.fragmentFunction = f; return self }

    @discardableResult
    func byVertexDescriptor(_ desc: MTLVertexDescriptor?) -> Self { self.vertexDescriptor = desc; return self }

    /// iOS 13+ 使用 `rasterSampleCount`
    @discardableResult
    func byRasterSampleCount(_ n: Int) -> Self { self.rasterSampleCount = n; return self }

    @discardableResult
    func byAlphaToCoverage(_ on: Bool) -> Self { self.isAlphaToCoverageEnabled = on; return self }

    @discardableResult
    func byAlphaToOne(_ on: Bool) -> Self { self.isAlphaToOneEnabled = on; return self }

    @discardableResult
    func byRasterizationEnabled(_ on: Bool) -> Self { self.isRasterizationEnabled = on; return self }

    @discardableResult
    func byDepthPixelFormat(_ fmt: MTLPixelFormat) -> Self { self.depthAttachmentPixelFormat = fmt; return self }

    @discardableResult
    func byStencilPixelFormat(_ fmt: MTLPixelFormat) -> Self { self.stencilAttachmentPixelFormat = fmt; return self }

    @available(iOS 12.0, *)
    @discardableResult
    func byInputTopology(_ topo: MTLPrimitiveTopologyClass) -> Self { self.inputPrimitiveTopology = topo; return self }
    // MARK: - Color Attachment
    /// 快速设置某个 colorAttachment 的像素格式
    @discardableResult
    func byColorAttachment(_ index: Int, pixelFormat: MTLPixelFormat) -> Self {
        self.colorAttachments[index].pixelFormat = pixelFormat
        return self
    }
    /// 自定义某个 colorAttachment（混合、写掩码等）
    @discardableResult
    func byColorAttachment(_ index: Int,
                           _ make: (MTLRenderPipelineColorAttachmentDescriptor) -> Void) -> Self {
        make(self.colorAttachments[index]); return self
    }
    // MARK: - 与 MTKView 对齐（像素格式/采样数）
    /// 根据 MTKView 自动匹配：color/depth/stencil 像素格式 + 采样数
    @discardableResult
    func byMatch(view: MTKView) -> Self {
        self.colorAttachments[0].pixelFormat = view.colorPixelFormat
        self.depthAttachmentPixelFormat = view.depthStencilPixelFormat
        self.rasterSampleCount = max(1, view.sampleCount)
        return self
    }
}
