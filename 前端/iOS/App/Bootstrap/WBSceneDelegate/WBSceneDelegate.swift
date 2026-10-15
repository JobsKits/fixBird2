//
//  WBSceneDelegate.swift
//  RepairWorkbench
//
//  Created by Jobs on 2026年10月15日，星期四.
//

import UIKit

import JobsByUIKit

final class WBSceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    private var coordinator: WBAppCoordinator?

    func scene(_ scene: UIScene,
               willConnectTo session: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else {
            return
        }
        let coordinator = WBAppCoordinator()
        self.coordinator = coordinator
        window = UIWindow.jobsMake(scene: windowScene,
                                   root: coordinator.rootViewController,
                                   makeKeyVisible: true)
        if let window {
            coordinator.attach(to: window)
            WBTheme.apply(to: window)
        }
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        if let window {
            WBTheme.apply(to: window)
        }
        if WBStore.shared.actor != nil {
            WBStore.shared.refresh()
        }
    }
}
