//
//  SceneDelegate.swift
//  Runner
//
//  Created by Sangam Shrestha on 05/09/2026.
//

import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
    override func scene(
        _ scene: UIScene,
        openURLContexts URLContexts: Set<UIOpenURLContext>
    ) {
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else {
            super.scene(scene, openURLContexts: URLContexts)
            return
        }

        let unhandledContexts = URLContexts.filter { !appDelegate.handleSharedURL($0.url) }
        if !unhandledContexts.isEmpty {
            super.scene(scene, openURLContexts: Set(unhandledContexts))
        }
    }
}
