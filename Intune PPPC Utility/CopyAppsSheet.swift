// CopyAppsSheet.swift
// Intune PPPC Utility

import SwiftUI

struct CopyAppsSheet: View {
    @Binding var profile: PPPCProfile
    let sourceServiceType: PPPCServiceType
    let sourceApps: [PPPCAppEntry]
    @Environment(\.dismiss) private var dismiss

    @State private var selectedTypes: Set<PPPCServiceType> = []

    // Services already in the profile (excluding the source)
    private var existingTypes: [PPPCServiceType] {
        let inProfile = Set(profile.services.map { $0.serviceType })
        return PPPCServiceType.allCases.filter {
            $0 != sourceServiceType && inProfile.contains($0)
        }
    }

    // Service types not yet in the profile
    private var newTypes: [PPPCServiceType] {
        let inProfile = Set(profile.services.map { $0.serviceType })
        return PPPCServiceType.allCases.filter {
            $0 != sourceServiceType && !inProfile.contains($0)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if !existingTypes.isEmpty {
                    Section("Append to Existing Service") {
                        ForEach(existingTypes) { serviceType in
                            serviceRow(serviceType)
                        }
                    }
                }
                if !newTypes.isEmpty {
                    Section("Create New Service") {
                        ForEach(newTypes) { serviceType in
                            serviceRow(serviceType)
                        }
                    }
                }
            }
            .navigationTitle("Copy \(sourceApps.count == 1 ? "1 App" : "\(sourceApps.count) Apps") to…")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Copy") { performCopy() }
                        .disabled(selectedTypes.isEmpty)
                }
            }
        }
        .frame(minWidth: 320, minHeight: 420)
    }

    @ViewBuilder
    private func serviceRow(_ serviceType: PPPCServiceType) -> some View {
        Button(action: { toggleSelection(serviceType) }) {
            HStack(spacing: 10) {
                Image(systemName: selectedTypes.contains(serviceType)
                      ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selectedTypes.contains(serviceType)
                                     ? Color.accentColor : .secondary)
                    .imageScale(.large)
                Label(serviceType.displayName, systemImage: serviceType.systemImage)
                    .foregroundStyle(.primary)
            }
        }
        .buttonStyle(.plain)
        .help(serviceType.serviceDescription)
    }

    private func toggleSelection(_ type: PPPCServiceType) {
        if selectedTypes.contains(type) {
            selectedTypes.remove(type)
        } else {
            selectedTypes.insert(type)
        }
    }

    private func performCopy() {
        // Iterate in enum declaration order for deterministic sidebar ordering
        for type in PPPCServiceType.allCases where selectedTypes.contains(type) {
            // Give each copied entry a fresh UUID so it's independent of the source
            let copies = sourceApps.map { app -> PPPCAppEntry in
                var copy = app
                copy.id = UUID()
                return copy
            }
            if let idx = profile.services.firstIndex(where: { $0.serviceType == type }) {
                // Service already exists — append
                profile.services[idx].apps.append(contentsOf: copies)
            } else {
                // Service doesn't exist yet — create it
                profile.services.append(PPPCServiceEntry(serviceType: type, apps: copies))
            }
        }
        profile.services.sortByServiceType()
        dismiss()
    }
}
