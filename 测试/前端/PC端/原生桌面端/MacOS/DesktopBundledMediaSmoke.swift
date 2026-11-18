//
//  DesktopBundledMediaSmoke.swift
//  RepairDesktopTests
//
//  Created by Jobs on 2026年11月18日，星期三.
//

import AVFoundation
import Foundation
import ImageIO

@main
@MainActor
struct DesktopBundledMediaSmoke {

    static func main() async throws {
        let admin = WBDemoState(username: "admin")
        precondition(admin.orders.count == 3)
        precondition(admin.orders.reduce(0) { $0 + $1.evidence.count } == 6)
        var seenResources = Set<String>()
        for order in admin.orders {
            precondition(order.evidence.count == 2)
            let kinds = Set(order.evidence.map { $0.string("kind") })
            precondition(kinds.contains("image"))
            if ["ios-demo-confirm", "ios-demo-repair"].contains(order.id) {
                precondition(kinds.contains("video"))
            }
            for evidence in order.evidence {
                precondition(evidence.bool("synthetic") && evidence.bool("public") && !evidence.bool("deleted"))
                precondition(evidence.string("uploaderId") == admin.actor.id)
                let reference = evidence.string("localFileReference")
                guard let url = DesktopDemoMediaRegistry.url(reference, actorID: admin.actor.id) else {
                    fatalError("Bundled media is absent or differs from its signed metadata: " + evidence.string("name"))
                }
                try DesktopDeviceMedia.verify(url: url, size: evidence.int("size"), sha256: evidence.string("sha256"))
                precondition(DesktopDemoMediaRegistry.url(reference, actorID: "ios-demo-customer-b") == nil)
                precondition(DesktopDemoMediaRegistry.url(reference) == nil)
                guard let thumbnail = DesktopDemoMediaRegistry.thumbnail(reference, actorID: admin.actor.id) else {
                    fatalError("An image thumbnail or the video's bundled poster is missing")
                }
                precondition(thumbnail.size.width > 0 && thumbnail.size.height > 0)
                if seenResources.insert(url.lastPathComponent).inserted {
                    if evidence.string("kind") == "image" {
                        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
                              CGImageSourceGetCount(source) > 0,
                              CGImageSourceCreateImageAtIndex(source, 0, nil) != nil else {
                            fatalError("Bundled image cannot decode")
                        }
                    } else {
                        let asset = AVURLAsset(url: url)
                        let playable = try await asset.load(.isPlayable)
                        let duration = try await asset.load(.duration)
                        let tracks = try await asset.loadTracks(withMediaType: .video)
                        precondition(playable && duration.seconds.isFinite && duration.seconds > 0 && !tracks.isEmpty)
                    }
                }
            }
        }
        precondition(seenResources == Set(["DeviceIntake.png", "DeviceBoard.png", "DeviceRepair.png", "DeviceInspection.mp4"]))
        let customers = [WBDemoState(username: "customer"), WBDemoState(username: "customer-b")]
        for customer in customers {
            precondition(customer.orders.count == 3)
            for order in customer.orders {
                precondition(order.customerId == customer.actor.id && order.companyId == customer.actor.companyId)
                for evidence in order.evidence {
                    precondition(evidence.string("uploaderId") == customer.actor.id)
                    precondition(DesktopDemoMediaRegistry.url(evidence.string("localFileReference"), actorID: customer.actor.id) != nil)
                    precondition(DesktopDemoMediaRegistry.url(evidence.string("localFileReference"), actorID: admin.actor.id) == nil)
                }
            }
        }
        let supplier = WBDemoState(username: "supplier")
        precondition(supplier.orders.isEmpty)
        let input = WBOrderInput().byDevice("无附件的新合成单").byDescription("不得自动植入预埋设备资料")
        let created = try admin.create(input)
        precondition(created.evidence.isEmpty && created.id.hasPrefix("ios-demo-"))
        var serverOrder = WBFixture.order().object!
        serverOrder["evidence"] = .array([])
        let real = try WBContract.order(.object(serverOrder))
        precondition(real.evidence.isEmpty)
        let imported = try DesktopDeviceMedia.importing(Bundle.main.resourceURL!.appendingPathComponent("DeviceIntake.png"))
        let original = DesktopDemoMediaRegistry.retain(imported)
        let importedReference = original["localFileReference"] as! String
        precondition(DesktopDemoMediaRegistry.url(importedReference) != nil)
        DesktopDemoMediaRegistry.clear()
        precondition(DesktopDemoMediaRegistry.url(importedReference) == nil)
        let seed = customers[0].orders[0].evidence[0]
        let bundledURL = DesktopDemoMediaRegistry.url(seed.string("localFileReference"), actorID: customers[0].actor.id)!
        precondition(FileManager.default.fileExists(atPath: bundledURL.path))
        let bytes = try Data(contentsOf: bundledURL)
        defer {
            try? bytes.write(to: bundledURL)
        }
        try (bytes + Data([0])).write(to: bundledURL)
        precondition(DesktopDemoMediaRegistry.url(seed.string("localFileReference"), actorID: customers[0].actor.id) == nil)
        print("PASS Mac bundled demo: 3 seeded orders, 3 decodable images and playable video, size/SHA integrity, actor isolation, supplier/new/live order exclusion, imported-file cleanup and corruption rejection")
    }
}
