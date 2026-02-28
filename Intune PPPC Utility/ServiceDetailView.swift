// ServiceDetailView.swift
// Intune PPPC Utility

import SwiftUI

struct ServiceDetailView: View {
    @Binding var service: PPPCServiceEntry
    @Binding var profile: PPPCProfile
    @State private var showCopyApps = false

    var body: some View {
        Group {
            if service.apps.isEmpty {
                // Empty state with Add App prompt
                ContentUnavailableView(
                    "No Apps Configured",
                    systemImage: "plus.app",
                    description: Text("Click Add App in the toolbar to configure an application for \(service.serviceType.displayName).")
                )
            } else {
                Form {
                    ForEach($service.apps) { $app in
                        Section {
                            AppEntryView(app: $app, serviceType: service.serviceType)
                        } header: {
                            HStack(spacing: 6) {
                                // Sender app badge (or "New App Entry" placeholder)
                                if $app.wrappedValue.identifier.isEmpty {
                                    Image(systemName: "app.dashed")
                                        .frame(width: 36, height: 36)
                                        .foregroundStyle(.secondary)
                                    Text("New App Entry")
                                        .font(.title)
                                        .foregroundStyle(.secondary)
                                } else {
                                    AppBadgeView(identifier: $app.wrappedValue.identifier,
                                                 identifierType: $app.wrappedValue.identifierType,
                                                 size: 36)
                                }

                                // For Apple Events: arrow + receiver badge
                                if service.serviceType.isAppleEvents,
                                   !$app.wrappedValue.aeReceiverIdentifier.isEmpty {
                                    Image(systemName: "arrow.right")
                                        .foregroundStyle(.secondary)
                                        .imageScale(.medium)
                                    AppBadgeView(identifier: $app.wrappedValue.aeReceiverIdentifier,
                                                 identifierType: $app.wrappedValue.aeReceiverIdentifierType,
                                                 size: 36)
                                }

                                Spacer()

                                if service.serviceType.isAppleEvents {
                                    Button {
                                        duplicateApp($app.wrappedValue)
                                    } label: {
                                        Image(systemName: "square.on.square")
                                    }
                                    .buttonStyle(.borderless)
                                    .help("Duplicate this entry with a new receiver")
                                }
                                Button(role: .destructive) {
                                    withAnimation {
                                        service.apps.removeAll { $0.id == $app.wrappedValue.id }
                                    }
                                } label: {
                                    Image(systemName: "trash")
                                }
                                .buttonStyle(.borderless)
                                .foregroundStyle(.red)
                                .help("Remove this app entry")
                            }
                        }

                    }
                }
                .formStyle(.grouped)
            }
        }
        .navigationTitle(service.serviceType.displayName)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { showCopyApps = true }) {
                    Label("Copy Apps to\u{2026}", systemImage: "doc.on.doc")
                }
                .disabled(service.apps.isEmpty)
                .help("Copy app entries from \(service.serviceType.displayName) to other service types")
            }
            ToolbarItem(placement: .primaryAction) {
                Button(action: addApp) {
                    Label("Add App", systemImage: "plus")
                }
                .help("Add an application entry for \(service.serviceType.displayName)")
            }
        }
        .sheet(isPresented: $showCopyApps) {
            CopyAppsSheet(
                profile: $profile,
                sourceServiceType: service.serviceType,
                sourceApps: service.apps
            )
        }
    }

    private func addApp() {
        withAnimation {
            service.apps.append(PPPCAppEntry(for: service.serviceType))
        }
    }

    // MARK: - App addition

    /// Duplicates an Apple Events entry, copying all sender fields and clearing
    /// the receiver fields so the user can fill in a different receiver.
    /// The copy is inserted immediately after the source entry.
    private func duplicateApp(_ source: PPPCAppEntry) {
        var copy = source
        copy.id = UUID()
        copy.aeReceiverIdentifier     = ""
        copy.aeReceiverIdentifierType = .bundleID
        copy.aeReceiverCodeRequirement = ""

        if let idx = service.apps.firstIndex(where: { $0.id == source.id }) {
            withAnimation {
                service.apps.insert(copy, at: idx + 1)
            }
        }
    }
}
