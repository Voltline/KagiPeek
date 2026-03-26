//
//  KagiPeekApp.swift
//  KagiPeek
//
//  Created by Voltline on 2026/3/26.
//

import SwiftUI

@main
struct KagiPeekApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup("KagiPeek", id: "main") {
            ContentView()
                .environmentObject(appDelegate.engine)
                .environmentObject(appDelegate.settings)
        }

        MenuBarExtra("KagiPeek", systemImage: "keyboard") {
            MenuBarContentView()
        }

        Settings {
            SettingsView()
                .environmentObject(appDelegate.settings)
        }
    }
}
