//
//  RepairDesktopApp.swift
//  RepairDesktop
//
//  Created by Jobs on 2026年11月18日，星期三.
//

import SwiftUI

@main
struct RepairDesktopApp: App {
    @StateObject private var model = DesktopModel()
    var body: some Scene {
        WindowGroup("啄木鸟维修平台") {
            DesktopView().environmentObject(model)
                .environment(\.locale, Locale(identifier: model.language))
                .preferredColorScheme(
                    model.theme == "system" ? nil : model.theme == "dark" ? .dark : .light
                )
                .frame(minWidth: 920, minHeight: 680)
        }.defaultSize(width: 1180, height: 820)
    }
}
