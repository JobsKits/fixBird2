//
//  MTKView.swift
//  JobsSwiftMetalKit
//
//  Created by Jobs on 2026年5月13日，星期三.
//

#if os(OSX)
import AppKit
#elseif os(iOS) || os(tvOS)
import UIKit
#endif

import MetalKit

public extension MTKView {
    // MARK: Factory
    /// 便捷工厂（默认使用系统 GPU）
    @MainActor
    static func jobsMake(frame: CGRect = .zero,
                         device: MTLDevice? = MTLCreateSystemDefaultDevice(),
                         configure: ((MTKView) -> Void)? = nil) -> MTKView {
        let v = MTKView(frame: frame, device: device)
        configure?(v)
        return v
    }

    // MARK: 基础属性
    @discardableResult @MainActor
    func byDevice(_ device: MTLDevice?) -> Self { self.device = device; return self }

    /// 如果没设置 device，就自动注入系统默认 GPU
    @discardableResult @MainActor
    func byDefaultDevice() -> Self {
        if self.device == nil { self.device = MTLCreateSystemDefaultDevice() };return self
    }

    @discardableResult @MainActor
    func byDelegate(_ delegate: MTKViewDelegate?) -> Self { self.delegate = delegate; return self }

    @discardableResult @MainActor
    func byFramebufferOnly(_ on: Bool) -> Self { self.framebufferOnly = on; return self }

    @discardableResult @MainActor
    func byPresentsWithTransaction(_ on: Bool) -> Self { self.presentsWithTransaction = on; return self }

    // MARK: 像素格式 / 采样
    @discardableResult @MainActor
    func byColorPixelFormat(_ fmt: MTLPixelFormat) -> Self { self.colorPixelFormat = fmt; return self }

    @discardableResult @MainActor
    func byDepthStencilPixelFormat(_ fmt: MTLPixelFormat) -> Self { self.depthStencilPixelFormat = fmt; return self }

    @available(iOS 16.0, *)
    @discardableResult @MainActor
    func byDepthStencilStorageMode(_ mode: MTLStorageMode) -> Self { self.depthStencilStorageMode = mode; return self }

    @discardableResult @MainActor
    func bySampleCount(_ n: Int) -> Self { self.sampleCount = n; return self }

    // MARK: RenderPass 清屏
    @discardableResult @MainActor
    func byClearColor(_ color: MTLClearColor) -> Self { self.clearColor = color; return self }

    @discardableResult @MainActor
    func byClearColor(_ r: Double, _ g: Double, _ b: Double, _ a: Double = 1.0) -> Self {
        self.clearColor = MTLClearColor(red: r, green: g, blue: b, alpha: a); return self
    }

    @discardableResult @MainActor
    func byClearDepth(_ d: Double) -> Self { self.clearDepth = d; return self }

    @discardableResult @MainActor
    func byClearStencil(_ s: UInt32) -> Self { self.clearStencil = s; return self }

    // MARK: 附件 usage（iOS 13+）
    @available(iOS 13.0, *)
    @discardableResult @MainActor
    func byDepthStencilAttachmentTextureUsage(_ usage: MTLTextureUsage) -> Self {
        self.depthStencilAttachmentTextureUsage = usage; return self
    }

    @available(iOS 13.0, *)
    @discardableResult @MainActor
    func byMultisampleColorAttachmentTextureUsage(_ usage: MTLTextureUsage) -> Self {
        self.multisampleColorAttachmentTextureUsage = usage; return self
    }

    // MARK: 刷新/循环控制
    @discardableResult @MainActor
    func byPreferredFramesPerSecond(_ fps: Int) -> Self { self.preferredFramesPerSecond = fps; return self }

    @discardableResult @MainActor
    func byEnableSetNeedsDisplay(_ on: Bool) -> Self { self.enableSetNeedsDisplay = on; return self }

    @discardableResult @MainActor
    func byAutoResizeDrawable(_ on: Bool) -> Self { self.autoResizeDrawable = on; return self }

    @discardableResult @MainActor
    func byDrawableSize(_ size: CGSize) -> Self { self.drawableSize = size; return self }

    @discardableResult @MainActor
    func byPaused(_ on: Bool) -> Self { self.isPaused = on; return self }

    // MARK: 资源管理
    @discardableResult @MainActor
    func byReleaseDrawables() -> Self { self.releaseDrawables(); return self }

    // MARK: 通用 apply
    @discardableResult @MainActor
    func byApply(_ block: (MTKView) -> Void) -> Self { block(self); return self }
}
