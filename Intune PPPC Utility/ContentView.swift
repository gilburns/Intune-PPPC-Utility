//
//  ContentView.swift
//  Intune PPPC Utility
//
//  Created by Gil Burns on 2/22/26.
//

import SwiftUI
import AppKit

struct ContentView: View {
    @Binding var document: PPPCDocument
    @State private var selectedServiceID: UUID?

    var body: some View {
        NavigationSplitView {
            SidebarView(document: $document, selectedServiceID: $selectedServiceID)
                .navigationSplitViewColumnWidth(min: 280, ideal: 320, max: 350)
        } detail: {
            if let id = selectedServiceID,
               let idx = document.profile.services.firstIndex(where: { $0.id == id }) {
                ServiceDetailView(service: $document.profile.services[idx],
                                  profile: $document.profile)
            } else {
                ContentUnavailableView(
                    "No Service Selected",
                    systemImage: "lock.shield",
                    description: Text("Select a PPPC service from the sidebar, or click + to add one.")
                )
            }
        }
        .frame(minWidth: 780, minHeight: 500)
        .background(ToolbarIconOnlyEnforcer())
        .onAppear {
            suggestFilename(document.profile.name)
        }
        .onChange(of: document.profile.name) { _, newName in
            suggestFilename(newName)
        }
    }

    /// Keeps the save-panel's suggested filename in sync with the Profile Name field.
    /// Only applies to new, unsaved documents (fileURL == nil); opened documents
    /// already have a filename derived from their URL and are left unchanged.
    private func suggestFilename(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let window = NSApp.keyWindow,
              let doc    = NSDocumentController.shared.document(for: window),
              doc.fileURL == nil          // skip already-saved documents
        else { return }

        // macOS filenames may not contain / or :
        let sanitized = trimmed
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")

        // NSDocument.displayName is read-only in Swift's bridging even though
        // ObjC exposes setDisplayName:. KVC reaches the setter directly.
        doc.setValue(sanitized, forKey: "displayName")
        // Push the same name to the title bar immediately.
        window.title = sanitized
    }
}

// MARK: - Toolbar display-mode enforcer

/// Invisible background view that locks the window toolbar to icon-only mode.
/// Uses KVO so the setting is re-applied immediately if the user changes it via
/// the toolbar right-click context menu.
private struct ToolbarIconOnlyEnforcer: NSViewRepresentable {

    class Coordinator: NSObject {
        private var observation: NSKeyValueObservation?

        /// Begin observing `toolbar.displayMode`; called at most once per window.
        func attach(to toolbar: NSToolbar) {
            guard observation == nil else { return }
            toolbar.displayMode = .iconOnly
            observation = toolbar.observe(\.displayMode) { toolbar, _ in
                if toolbar.displayMode != .iconOnly {
                    toolbar.displayMode = .iconOnly
                }
            }
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeNSView(context: Context) -> NSView { NSView() }

    func updateNSView(_ nsView: NSView, context: Context) {
        // Defer until the view is in a window (may not be on first call).
        DispatchQueue.main.async {
            if let toolbar = nsView.window?.toolbar {
                context.coordinator.attach(to: toolbar)
            }
        }
    }
}

