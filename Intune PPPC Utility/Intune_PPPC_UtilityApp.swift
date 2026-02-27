//
//  Intune_PPPC_UtilityApp.swift
//  Intune PPPC Utility
//
//  Created by Gil Burns on 2/22/26.
//

import SwiftUI
import AppKit

@main
struct Intune_PPPC_UtilityApp: App {
    var body: some Scene {
        DocumentGroup(newDocument: PPPCDocument()) { file in
            ContentView(document: file.$document)
        }
        .defaultSize(width: 980, height: 620)
        .commands {
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
    }
}
