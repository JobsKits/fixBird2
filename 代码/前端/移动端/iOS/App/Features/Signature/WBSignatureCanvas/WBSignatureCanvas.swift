//
//  WBSignatureCanvas.swift
//  RepairWorkbench
//
//  Created by Jobs on 2026年10月15日，星期四.
//

import UIKit

import JobsByUIKit
import JobsSwiftBaseDefines

final class WBSignatureCanvas: UIView {
    private var strokes: [[CGPoint]] = []
    private var drawingStateChanged: ((Bool) -> Void)?

    init() {
        super.init(frame: .zero)
        byBackgroundColor(JobsCor.white)
            .byMultipleTouchEnabled(false)
            .byHeight(210)
    }

    required init?(coder: NSCoder) {
        return nil
    }

    @discardableResult
    func byDrawingStateChanged(_ callback: @escaping (Bool) -> Void) -> Self {
        drawingStateChanged = callback
        return self
    }

    var hasSignature: Bool {
        let distance = strokes.reduce(CGFloat.zero) { total, points in
            return total + zip(points, points.dropFirst()).reduce(CGFloat.zero) { distance, pair in
                return distance + hypot(pair.1.x - pair.0.x, pair.1.y - pair.0.y)
            }
        }
        return strokes.reduce(0) { $0 + $1.count } >= 5 && distance >= 35
    }

    @discardableResult
    func clearSignature() -> Self {
        strokes.removeAll()
        setNeedsDisplay()
        return self
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let point = touches.first?.location(in: self), bounds.contains(point) else {
            return
        }
        drawingStateChanged?(true)
        strokes.append([point])
        setNeedsDisplay()
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let point = touches.first?.location(in: self), bounds.contains(point),
              !strokes.isEmpty, strokes.last!.count < 8_000 else {
            return
        }
        strokes[strokes.count - 1].append(point)
        setNeedsDisplay()
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        drawingStateChanged?(false)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        drawingStateChanged?(false)
    }

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else {
            return
        }
        paint(in: context, size: bounds.size)
    }

    func signatureDataURL() -> String? {
        guard hasSignature, bounds.width > 0, bounds.height > 0 else {
            return nil
        }
        let size = CGSize(width: 640, height: 240)
        // 绘制终端集中在画布内部，导出仅使用用户实际留下的笔迹。
        let bytes = UIGraphicsImageRenderer.make(size: size).pngData { renderer in
            renderer.cgContext.scaleBy(x: size.width / bounds.width, y: size.height / bounds.height)
            paint(in: renderer.cgContext, size: bounds.size)
        }
        return "data:image/png;base64," + bytes.base64EncodedString()
    }

    private func paint(in context: CGContext, size: CGSize) {
        context.setFillColor(JobsCor.white.cgColor)
        context.fill(CGRect(origin: .zero, size: size))
        context.setStrokeColor(JobsCor.black.cgColor)
        context.setLineWidth(2.5)
        context.setLineCap(.round)
        context.setLineJoin(.round)
        for stroke in strokes {
            guard let first = stroke.first else {
                continue
            }
            context.beginPath()
            context.move(to: first)
            for point in stroke.dropFirst() {
                context.addLine(to: point)
            }
            context.strokePath()
        }
    }
}
