//
//  DesktopSignature.swift
//  RepairDesktop
//
//  Created by Jobs on 2026年11月18日，星期三.
//

import AppKit
import SwiftUI

struct DesktopSignature: View {
    @Binding var strokes: [[CGPoint]]
    @State private var drawing = false
    var body: some View {
        Self.image(strokes).frame(width: 540, height: 180)
            .border(Color.gray)
            .gesture(
                DragGesture(minimumDistance: 0).onChanged {
                    value in
                    let point = CGPoint(
                        x: min(540, max(0, value.location.x)), y: min(180, max(0, value.location.y)))
                    if !drawing {
                        strokes.append([])
                        drawing = true
                    }

                    strokes[strokes.count - 1].append(point)
                }.onEnded {
                    _ in drawing = false
                }
            )
    }

    static func image(_ strokes: [[CGPoint]]) -> some View {
        Canvas {
            context, _ in
            for stroke in strokes {
                var path = Path()
                if let first = stroke.first {
                    path.move(to: first)
                }

                for point in stroke.dropFirst() {
                    path.addLine(to: point)
                }

                context.stroke(
                    path, with: .color(.black),
                    style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
            }
        }.background(Color.white)
    }

    @MainActor static func png(_ strokes: [[CGPoint]]) -> Data? {
        let renderer = ImageRenderer.desktopMake(content: image(strokes).frame(width: 540, height: 180))
        guard let data = renderer.nsImage?.tiffRepresentation else {
            return nil
        }

        return NSBitmapImageRep.desktopMake(data)?.representation(using: .png, properties: [:])
    }
}

extension NSBitmapImageRep {
    static func desktopMake(_ data: Data) -> NSBitmapImageRep? {
        NSBitmapImageRep(data: data)
    }
}

extension ImageRenderer {
    @MainActor static func desktopMake(content: Content) -> ImageRenderer<Content> {
        ImageRenderer(content: content)
    }
}
