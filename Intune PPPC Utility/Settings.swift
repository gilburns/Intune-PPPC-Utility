//  Settings.swift
//  Intune PPPC Utility
//
//  Created by Gil Burns on 2/28/26.
//

import SwiftUI
import Sparkle

// This is the view for our updater settings
// It manages local state for checking for updates and automatically downloading updates
// Upon user changes to these, the updater's properties are set. These are backed by NSUserDefaults.
// Note the updater properties should *only* be set when the user changes the state.

struct UpdaterSettingsView: View {
    private let updater: SPUUpdater

    @State private var automaticallyChecksForUpdates: Bool
    @State private var automaticallyDownloadsUpdates: Bool
    @State private var scheduledCheckInterval: Int = 86_400

    init(updater: SPUUpdater) {
        self.updater = updater
        _automaticallyChecksForUpdates = State(initialValue: updater.automaticallyChecksForUpdates)
        _automaticallyDownloadsUpdates = State(initialValue: updater.automaticallyDownloadsUpdates)
        let stored = UserDefaults.standard.integer(forKey: "SUScheduledCheckInterval")
        _scheduledCheckInterval = State(initialValue: stored > 0 ? stored : 86_400)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Update Checks:", systemImage: "arrow.2.circlepath.circle")
                .font(.headline)
            Toggle("Automatically check for updates", isOn: $automaticallyChecksForUpdates)
                .onChange(of: automaticallyChecksForUpdates) {
                    updater.automaticallyChecksForUpdates = automaticallyChecksForUpdates
                }

            Toggle("Automatically download updates", isOn: $automaticallyDownloadsUpdates)
                .disabled(!automaticallyChecksForUpdates)
                .onChange(of: automaticallyDownloadsUpdates) {
                    updater.automaticallyDownloadsUpdates = automaticallyDownloadsUpdates
                }

            Picker("Check Interval", selection: $scheduledCheckInterval) {
                Text("Once a day").tag(86_400)
                Text("Once a week").tag(86_400 * 7)
                Text("Once a fortnight").tag(86_400 * 14)
                Text("Once a month").tag(86_400 * 30)
            }
            .disabled(!automaticallyChecksForUpdates)
            // Observe the value, not the binding, so it meets Equatable
            .onChange(of: scheduledCheckInterval) { oldInterval, newInterval in
                UserDefaults.standard.set(newInterval, forKey: "SUScheduledCheckInterval")
            }

            HStack {
                Spacer()
                Button("Check now…") {
                    checkForUpdates()
                }
            }
        }
        .padding()
        .frame(width: 400)
        .background(SettingsWindowCenterer())
    }

    private func checkForUpdates() {
        updater.checkForUpdates()
    }
}

// MARK: - Window centerer

/// Invisible background view that centers the Settings window on screen each
/// time it opens. Uses `NSWindow.didBecomeKeyNotification` so re-opening the
/// window after closing it also centers correctly.
private struct SettingsWindowCenterer: NSViewRepresentable {

    class Coordinator: NSObject {
        private var token: NSObjectProtocol?

        func attach(to window: NSWindow) {
            guard token == nil else { return }
            window.center()
            token = NotificationCenter.default.addObserver(
                forName: NSWindow.didBecomeKeyNotification,
                object: window,
                queue: .main
            ) { [weak window] _ in
                window?.center()
            }
        }

        deinit {
            if let t = token { NotificationCenter.default.removeObserver(t) }
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeNSView(context: Context) -> NSView { NSView() }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            if let window = nsView.window {
                context.coordinator.attach(to: window)
            }
        }
    }
}

