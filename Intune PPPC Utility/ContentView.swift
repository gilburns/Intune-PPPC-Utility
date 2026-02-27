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
                .navigationSplitViewColumnWidth(min: 260, ideal: 280, max: 320)
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
