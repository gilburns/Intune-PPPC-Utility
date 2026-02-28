//
//  Intune_PPPC_UtilityApp.swift
//  Intune PPPC Utility
//
//  Created by Gil Burns on 2/22/26.
//

import SwiftUI
import AppKit
import Sparkle

@main
struct Intune_PPPC_UtilityApp: App {

    /// Single Sparkle controller for the lifetime of the app.
    /// `startingUpdater: true` launches the background update check on startup.
    private let updaterController = SPUStandardUpdaterController(
        startingUpdater: true,
        updaterDelegate: nil,
        userDriverDelegate: nil
    )

    var body: some Scene {
        DocumentGroup(newDocument: PPPCDocument()) { file in
            ContentView(document: file.$document)
        }
        .defaultSize(width: 980, height: 620)
        .commands {
            // "Check for Updates…" appears directly after "About Intune PPPC Utility"
            CommandGroup(after: .appInfo) {
                Divider()
                Button("Check for Updates\u{2026}") {
                    updaterController.updater.checkForUpdates()
                }
            }

            CommandGroup(replacing: .help) {
                Divider()
                Button("Intune PPPC Utility Wiki") {
                    NSWorkspace.shared.open(
                        URL(string: "https://github.com/gilburns/IntunePPPCUtility/wiki")!
                    )
                }
                Button("Apple Privacy Settings Documentation") {
                    NSWorkspace.shared.open(
                        URL(string: "https://developer.apple.com/documentation/devicemanagement/privacypreferencespolicycontrol")!
                    )
                }
                Button("Apple Platform Deployment - Privacy Preferences Policy Control") {
                    NSWorkspace.shared.open(
                        URL(string: "https://support.apple.com/en-us/guide/deployment/dep38df53c2a/web")!
                    )
                }
            }
        }

        // Adds "Settings…" (⌘,) to the app menu automatically.
        Settings {
            UpdaterSettingsView(updater: updaterController.updater)
        }

    }
}
