//
//  WBDemoMediaSeed.swift
//  WBDemoMediaSeed
//
//  Created by Jobs on 2026年11月18日，星期三.
//

import Foundation

#if os(macOS)
enum WBDemoMediaSeed {

    struct Item: Decodable {

        let resource: String
        let name: String
        let mime: String
        let size: Int64
        let sha256: String
        let posterResource: String?
    }

    private struct Catalog: Decodable {

        let version: Int
        let orders: [String: [Item]]
    }

    private static let orderIDs = ["ios-demo-intake", "ios-demo-confirm", "ios-demo-repair"]
    private static let resources = ["DeviceIntake.png", "DeviceBoard.png", "DeviceRepair.png", "DeviceInspection.mp4"]
    private static let catalog: Catalog? = {
        guard let url = Bundle.main.url(forResource: "media-seed", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let value = try? JSONDecoder().decode(Catalog.self, from: data), value.version == 1 else {
            return nil
        }
        return value
    }()

    static func evidence(orderID: String,
                         actorID: String,
                         stage: String,
                         createdAt: String) -> [[String: Any]] {
        guard orderIDs.contains(orderID), !actorID.isEmpty else {
            return []
        }
        return (catalog?.orders[orderID] ?? []).filter(valid).map { item in
            let reference = reference(actorID: actorID, orderID: orderID, resource: item.resource)
            return [
                "id": "desktop-seed-file:" + actorID + ":" + orderID + ":" + item.resource,
                "name": item.name,
                "kind": item.mime.hasPrefix("video/") ? "video" : "image",
                "text": "合成演示设备资料",
                "mime": item.mime,
                "size": item.size,
                "sha256": item.sha256,
                "localFileReference": reference,
                "uploaderId": actorID,
                "createdAt": createdAt,
                "stage": stage,
                "public": true,
                "deleted": false,
                "synthetic": true,
            ]
        }
    }

    static func item(reference selected: String,
                     actorID: String) -> Item? {
        guard !actorID.isEmpty else {
            return nil
        }
        for orderID in orderIDs {
            for item in (catalog?.orders[orderID] ?? []).filter(valid) {
                if selected == reference(actorID: actorID, orderID: orderID, resource: item.resource) {
                    return item
                }
            }
        }
        return nil
    }

    static func poster(reference selected: String,
                       actorID: String) -> Item? {
        guard let item = item(reference: selected, actorID: actorID), item.mime == "video/mp4",
              let resource = item.posterResource, resources.contains(resource), resource.hasSuffix(".png") else {
            return nil
        }
        return orderIDs.flatMap { catalog?.orders[$0] ?? [] }.first { value in
            return value.resource == resource && valid(value)
        }
    }

    private static func valid(_ item: Item) -> Bool {
        return resources.contains(item.resource) && !item.name.isEmpty && item.size > 0
            && item.mime == (item.resource.hasSuffix(".mp4") ? "video/mp4" : "image/png")
            && item.sha256.count == 64 && item.sha256.allSatisfy({ $0.isHexDigit })
    }

    private static func reference(actorID: String,
                                  orderID: String,
                                  resource: String) -> String {
        return "desktop-seed:" + actorID + ":" + orderID + ":" + resource
    }
}
#endif
