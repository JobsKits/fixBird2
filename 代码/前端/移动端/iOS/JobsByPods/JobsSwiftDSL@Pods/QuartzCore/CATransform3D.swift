//
//  CATransform3D.swift
//  JobsByQuartzCore
//
//  Created by Jobs on 2026年5月13日，星期三.
//

#if os(OSX)
import AppKit
#elseif os(iOS) || os(tvOS)
import UIKit
#endif

import QuartzCore
import CoreGraphics

// MARK: - DSL Entry
extension CATransform3D {
    /// 入口：返回 Identity 作为链式起点
    public static func jobs() -> CATransform3D { CATransform3DIdentity }
}
// MARK: - 基础矩阵元素设置（16 项 & 批量）
extension CATransform3D {
    @discardableResult public func byM11(_ v: CGFloat) -> Self { var t = self; t.m11 = v; return t }
    @discardableResult public func byM12(_ v: CGFloat) -> Self { var t = self; t.m12 = v; return t }
    @discardableResult public func byM13(_ v: CGFloat) -> Self { var t = self; t.m13 = v; return t }
    @discardableResult public func byM14(_ v: CGFloat) -> Self { var t = self; t.m14 = v; return t }

    @discardableResult public func byM21(_ v: CGFloat) -> Self { var t = self; t.m21 = v; return t }
    @discardableResult public func byM22(_ v: CGFloat) -> Self { var t = self; t.m22 = v; return t }
    @discardableResult public func byM23(_ v: CGFloat) -> Self { var t = self; t.m23 = v; return t }
    @discardableResult public func byM24(_ v: CGFloat) -> Self { var t = self; t.m24 = v; return t }

    @discardableResult public func byM31(_ v: CGFloat) -> Self { var t = self; t.m31 = v; return t }
    @discardableResult public func byM32(_ v: CGFloat) -> Self { var t = self; t.m32 = v; return t }
    @discardableResult public func byM33(_ v: CGFloat) -> Self { var t = self; t.m33 = v; return t }
    @discardableResult public func byM34(_ v: CGFloat) -> Self { var t = self; t.m34 = v; return t }

    @discardableResult public func byM41(_ v: CGFloat) -> Self { var t = self; t.m41 = v; return t }
    @discardableResult public func byM42(_ v: CGFloat) -> Self { var t = self; t.m42 = v; return t }
    @discardableResult public func byM43(_ v: CGFloat) -> Self { var t = self; t.m43 = v; return t }
    @discardableResult public func byM44(_ v: CGFloat) -> Self { var t = self; t.m44 = v; return t }
    /// 一次性设置 16 项
    @discardableResult
    public func byMatrix(
        m11: CGFloat, m12: CGFloat, m13: CGFloat, m14: CGFloat,
        m21: CGFloat, m22: CGFloat, m23: CGFloat, m24: CGFloat,
        m31: CGFloat, m32: CGFloat, m33: CGFloat, m34: CGFloat,
        m41: CGFloat, m42: CGFloat, m43: CGFloat, m44: CGFloat
    ) -> Self {
        var t = self
        t.m11 = m11; t.m12 = m12; t.m13 = m13; t.m14 = m14
        t.m21 = m21; t.m22 = m22; t.m23 = m23; t.m24 = m24
        t.m31 = m31; t.m32 = m32; t.m33 = m33; t.m34 = m34
        t.m41 = m41; t.m42 = m42; t.m43 = m43; t.m44 = m44
        return t
    }
}
// MARK: - 常用 3D 变换（平移/缩放/旋转/拼接/求逆）
extension CATransform3D {
    /// 平移
    @discardableResult
    public func byTranslate(x: CGFloat = 0, y: CGFloat = 0, z: CGFloat = 0) -> Self {
        CATransform3DTranslate(self, x, y, z)
    }
    /// 缩放
    @discardableResult
    public func byScale(x: CGFloat = 1, y: CGFloat = 1, z: CGFloat = 1) -> Self {
        CATransform3DScale(self, x, y, z)
    }
    /// 绕任意轴旋转（弧度）
    @discardableResult
    public func byRotate(angle radians: CGFloat, axisX x: CGFloat, axisY y: CGFloat, axisZ z: CGFloat) -> Self {
        CATransform3DRotate(self, radians, x, y, z)
    }
    /// 绕 X / Y / Z 轴旋转（弧度）
    @discardableResult public func byRotateX(_ radians: CGFloat) -> Self { CATransform3DRotate(self, radians, 1, 0, 0) }
    @discardableResult public func byRotateY(_ radians: CGFloat) -> Self { CATransform3DRotate(self, radians, 0, 1, 0) }
    @discardableResult public func byRotateZ(_ radians: CGFloat) -> Self { CATransform3DRotate(self, radians, 0, 0, 1) }
    /// 矩阵拼接（右乘）
    @discardableResult
    public func byConcat(_ other: CATransform3D) -> Self {
        CATransform3DConcat(self, other)
    }
    /// 求逆
    @discardableResult
    public func invertedOrSelf() -> Self {
        CATransform3DInvert(self)
    }
}
// MARK: - 透视（m34）
extension CATransform3D {
    /// 设置透视：m34 = -1 / d（d 取焦距，建议 400 ~ 800）
    @discardableResult
    public func byPerspective(d: CGFloat) -> Self {
        guard d != 0 else { return self }
        var t = self
        t.m34 = -1.0 / d
        return t
    }
    /// 直接设置 m34（进阶自定义）
    @discardableResult
    public func byPerspectiveValue(_ m34: CGFloat) -> Self {
        var t = self
        t.m34 = m34
        return t
    }
}
// MARK: - 工具 & 状态
extension CATransform3D {
    /// 是否近似为 Identity（考虑浮点容差）
    public var jobs_isIdentity: Bool { CATransform3DIsIdentity(self) }
    /// 与单位矩阵的“近似相等”判断（容差可调）
    public func jobs_isAlmostEqual(to other: CATransform3D, epsilon: CGFloat = 1e-6) -> Bool {
        func eq(_ a: CGFloat, _ b: CGFloat) -> Bool { abs(a - b) <= epsilon };return eq(m11, other.m11) && eq(m12, other.m12) && eq(m13, other.m13) && eq(m14, other.m14) &&
               eq(m21, other.m21) && eq(m22, other.m22) && eq(m23, other.m23) && eq(m24, other.m24) &&
               eq(m31, other.m31) && eq(m32, other.m32) && eq(m33, other.m33) && eq(m34, other.m34) &&
               eq(m41, other.m41) && eq(m42, other.m42) && eq(m43, other.m43) && eq(m44, other.m44)
    }
}
// MARK: - 便捷预设
public extension CATransform3D {
    /// 轻量 3D 卡片左右翻转效果预设（带透视 & 沿 Y 轴旋转）
    public static func jobs_cardFlipY(angle: CGFloat = .pi / 6, perspectiveD: CGFloat = 600) -> CATransform3D {
        CATransform3D.jobs()
            .byPerspective(d: perspectiveD)
            .byRotateY(angle)
    }
    /// 进入动画：Z 轴向内推进 + 轻微缩放 + 透视
    public static func jobs_pushIn(z: CGFloat = -200, scale: CGFloat = 0.92, perspectiveD: CGFloat = 700) -> CATransform3D {
        CATransform3D.jobs()
            .byPerspective(d: perspectiveD)
            .byTranslate(z: z)
            .byScale(x: scale, y: scale, z: 1)
    }
}
// MARK: - 示例（用法参考）
/*
let t = CATransform3D.jobs()
    .byPerspective(d: 500)
    .byRotateY(.pi / 8)
    .byTranslate(x: 0, y: 0, z: -150)
    .byScale(x: 0.95, y: 0.95, z: 1)

// 应用到 CALayer：
view.layer.sublayerTransform = t

// 或者直接设置给某个 layer：
someLayer.transform = CATransform3D.jobs()
    .byRotateX(.pi / 10)
    .byPerspective(d: 600)
*/
