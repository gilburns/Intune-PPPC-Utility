// SidebarView.swift
// Intune PPPC Utility

import SwiftUI
import UniformTypeIdentifiers

struct SidebarView: View {
    @Binding var document: PPPCDocument
    @Binding var selectedServiceID: UUID?
    @State private var showAddService        = false
    @State private var showImportMobileconfig = false
    @State private var showImportTCC         = false
    @State private var importError: (any Error)? = nil
    @State private var showImportError       = false

    var body: some View {
        VStack(spacing: 0) {
            // Profile metadata (name + description) above the list
            VStack(alignment: .leading, spacing: 6) {
                Label("Profile Name:", systemImage: "tag")
                    .font(.system(.body))
                    .labelStyle(.titleOnly)
                TextField("Profile Name", text: $document.profile.name)
                    .textFieldStyle(.roundedBorder)
                    .font(.headline)
                Label("Description:", systemImage: "tag")
                    .font(.system(.body))
                    .labelStyle(.titleOnly)
                TextField("Description", text: $document.profile.description, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            Divider()

            // Service type list
            List(selection: $selectedServiceID) {
                ForEach(document.profile.services) { service in
                    ServiceRowView(service: service) {
                        deleteService(id: service.id)
                    }
                    .tag(service.id)
                }
                .onDelete(perform: deleteServices)
            }
            .listStyle(.sidebar)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { showImportTCC = true }) {
                    Label("Import from TCC\u{2026}", systemImage: "laptopcomputer.and.arrow.down")
                }
                .padding(.top, 1)
                .help("Import app entries from a macOS TCC database")
            }
            ToolbarItem(placement: .primaryAction) {
                Button(action: { showImportMobileconfig = true }) {
                    Label("Import Mobileconfig\u{2026}", systemImage: "square.and.arrow.down")
                }
                .padding(.bottom, 2)
                .help("Import PPPC settings from a .mobileconfig file")
            }
            ToolbarItem(placement: .primaryAction) {
                Button(action: { showAddService = true }) {
                    Label("Add Service", systemImage: "plus")
                }
                .help("Add a PPPC service type to this profile")
            }
        }
        .pickerStyle(MenuPickerStyle())

        .sheet(isPresented: $showImportTCC) {
            TCCImportSheet(profile: $document.profile)
        }
        .sheet(isPresented: $showAddService) {
            AddServiceSheet(
                profile: $document.profile,
                selectedServiceID: $selectedServiceID
            )
        }
        .fileImporter(
            isPresented: $showImportMobileconfig,
            allowedContentTypes: [.mobileconfig],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .failure(let error):
                importError = error
                showImportError = true
            case .success(let urls):
                guard let url = urls.first else { return }
                importMobileconfig(from: url)
            }
        }
        .alert("Import Failed", isPresented: $showImportError, presenting: importError) { _ in
            Button("OK") { importError = nil }
        } message: { error in
            Text(error.localizedDescription)
        }
    }

    private func importMobileconfig(from url: URL) {
        do {
            let data         = try Data(contentsOf: url)
            let suggestedName = url.deletingPathExtension().lastPathComponent
            let profile      = try MobileconfigParser.parse(data, suggestedName: suggestedName)
            document.profile = profile
            selectedServiceID = nil
        } catch {
            importError = error
            showImportError = true
        }
    }

    private func deleteServices(at offsets: IndexSet) {
        // Clear selection if the selected service is being deleted
        let removedIDs = offsets.map { document.profile.services[$0].id }
        if let current = selectedServiceID, removedIDs.contains(current) {
            selectedServiceID = nil
        }
        document.profile.services.remove(atOffsets: offsets)
    }

    private func deleteService(id: UUID) {
        if selectedServiceID == id { selectedServiceID = nil }
        document.profile.services.removeAll { $0.id == id }
    }
}

// MARK: - Row View

private struct ServiceRowView: View {
    let service: PPPCServiceEntry
    let onDelete: () -> Void
    @State private var isHovered = false

    var body: some View {
        HStack {
            Label(service.serviceType.displayName,
                  systemImage: service.serviceType.systemImage)
                .help(service.serviceType.serviceDescription)
            Spacer()
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .foregroundStyle(.red)
            }
            .buttonStyle(.borderless)
            .opacity(isHovered ? 1 : 0)
            .help("Remove \(service.serviceType.displayName)")
        }
        .onHover { isHovered = $0 }
    }
}
