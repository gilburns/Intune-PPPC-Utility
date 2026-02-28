// AddServiceSheet.swift
// Intune PPPC Utility

import SwiftUI

struct AddServiceSheet: View {
    @Binding var profile: PPPCProfile
    @Binding var selectedServiceID: UUID?
    @Environment(\.dismiss) private var dismiss

    // Only offer service types not already in the profile
    var availableTypes: [PPPCServiceType] {
        let usedTypes = Set(profile.services.map { $0.serviceType })
        return PPPCServiceType.allCases.filter { !usedTypes.contains($0) }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(availableTypes) { serviceType in
                    Button(action: { addService(serviceType) }) {
                        Label(serviceType.displayName, systemImage: serviceType.systemImage)
                            .foregroundStyle(.primary)
                    }
                    .buttonStyle(.plain)
                    .help(serviceType.serviceDescription)
                }
            }
            .navigationTitle("Add Service")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .frame(minWidth: 300, minHeight: 420)
    }

    private func addService(_ serviceType: PPPCServiceType) {
        let entry = PPPCServiceEntry(serviceType: serviceType,
                                    apps: [PPPCAppEntry(for: serviceType)])
        profile.services.append(entry)
        profile.services.sortByServiceType()
        selectedServiceID = entry.id
        dismiss()
    }
}
