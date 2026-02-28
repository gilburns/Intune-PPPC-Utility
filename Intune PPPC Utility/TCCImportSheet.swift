// TCCImportSheet.swift
// Intune PPPC Utility

import SwiftUI
import AppKit

struct TCCImportSheet: View {
    @Binding var profile: PPPCProfile
    @Environment(\.dismiss) private var dismiss

    // Phase tracking
    @State private var hasLoaded       = false
    @State private var isLoading       = false
    @State private var isImporting     = false
    @State private var importProgress  = 0.0

    // Source selection
    @State private var selectedSources: Set<TCCSource> = [.user]

    // Loaded items
    @State private var items: [TCCImportItem] = []

    // Missing-app tracking
    @State private var unresolvedItemIDs: Set<UUID> = []

    // Post-import summary
    @State private var importSummaryCount  = 0
    @State private var showImportSummary   = false

    // Error handling
    @State private var loadError: (any Error)?
    @State private var showLoadError           = false
    @State private var isPermissionDeniedError = false

    var body: some View {
        VStack(spacing: 0) {
            // ── Header ──────────────────────────────────────────────────────
            HStack {
                Text("Import from TCC Database")
                    .font(.headline)
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding()

            Divider()

            // ── Content ─────────────────────────────────────────────────────
            Group {
                if !hasLoaded {
                    setupView
                } else if items.isEmpty {
                    ContentUnavailableView(
                        "No Manageable Items",
                        systemImage: "tray",
                        description: Text("No TCC entries were found that can be managed with a PPPC configuration profile.")
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    itemsView
                }
            }

            Divider()

            // ── Footer ───────────────────────────────────────────────────────
            HStack {
                if hasLoaded {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(selectedCount) of \(items.count) items selected")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if selectedUnresolvedCount > 0 {
                            Label(
                                "\(selectedUnresolvedCount) selected app\(selectedUnresolvedCount == 1 ? "" : "s") not found — those code requirement will be empty",
                                systemImage: "exclamationmark.triangle.fill"
                            )
                            .font(.caption)
                            .foregroundStyle(.orange)
                        } else  {
                            Label(
                                "\(selectedUnresolvedCount) selected app\(selectedUnresolvedCount == 1 ? "" : "s") not found - no missing code requirements",
                                systemImage: "hand.thumbsup.fill"
                            )
                            .font(.caption)
                            .foregroundStyle(.gray)
                        }
                    }
                    Spacer()
                    Button("Back") {
                        hasLoaded = false
                        items = []
                    }
                    Button {
                        Task { await performImport() }
                    } label: {
                        // Hidden placeholder reserves space for the widest possible label
                        // (3-digit count + "Items"), preventing layout shifts as count changes.
                        ZStack {
                            Text("Import 999 Items").hidden()
                            Text("Import \(selectedCount) Item\(selectedCount == 1 ? "" : "s")")
                        }
                    }
                    .disabled(selectedCount == 0)
                    .buttonStyle(.borderedProminent)
                } else {
                    Spacer()
                    if isLoading {
                        ProgressView().controlSize(.small)
                    }
                    Button("Load") { loadItems() }
                        .disabled(selectedSources.isEmpty || isLoading)
                        .buttonStyle(.borderedProminent)
                }
            }
            .padding()
        }
        .frame(width: 640, height: 520)
        .overlay { if isImporting { importOverlay } }
        .alert("Import Failed", isPresented: $showLoadError, presenting: loadError) { _ in
            if isPermissionDeniedError {
                Button("Open Privacy Settings") { openPrivacySettings() }
            }
            Button("OK") { loadError = nil; isPermissionDeniedError = false }
        } message: { err in
            Text(err.localizedDescription)
        }
        .alert("Import Complete", isPresented: $showImportSummary) {
            Button("OK") { dismiss() }
        } message: {
            let n = importSummaryCount
            Text("\(n) imported \(n == 1 ? "item" : "items") could not have \(n == 1 ? "its" : "their") code requirement resolved because the \(n == 1 ? "application was" : "applications were") not found on this Mac. \(n == 1 ? "It has" : "They have") been added to the profile with an empty code requirement — you can fill \(n == 1 ? "it" : "them") in manually.")
        }
    }

    // MARK: - Setup View

    private var setupView: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Select one or both TCC databases to import from:")
                .font(.subheadline)

            VStack(alignment: .leading, spacing: 12) {
                ForEach(TCCSource.allCases) { source in
                    Toggle(isOn: Binding(
                        get: { selectedSources.contains(source) },
                        set: { on in
                            if on { selectedSources.insert(source) }
                            else  { selectedSources.remove(source) }
                        }
                    )) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(source.rawValue).fontWeight(.medium)
                            Text(source.dbPath)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Divider()

            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "lock.shield")
                    .foregroundStyle(.secondary)
                Text("Reading TCC databases requires **Full Disk Access**. If **Intune PPPC Utility** does not have it, a dialog will ask you to grant access. You can also add it manually in System Settings → Privacy & Security → Full Disk Access.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: - Items View

    private var itemsView: some View {
        List {
            ForEach(groupedItems, id: \.0) { serviceType, indices in
                Section {
                    ForEach(indices, id: \.self) { idx in
                        TCCItemRow(
                            item: items[idx],
                            isSelected: $items[idx].isSelected,
                            alreadyInProfile: isAlreadyInProfile(items[idx]),
                            appMissing: unresolvedItemIDs.contains(items[idx].id)
                        )
                    }
                } header: {
                    HStack(spacing: 6) {
                        Label(serviceType.displayName, systemImage: serviceType.systemImage)
                            .font(.caption.weight(.semibold))
                        Text("(\(indices.count))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                        Spacer()
                        Button("All") {
                            for idx in indices { items[idx].isSelected = true }
                        }
                        .font(.caption)
                        .buttonStyle(.borderless)
                        Text("/").font(.caption).foregroundStyle(.secondary)
                        Button("None") {
                            for idx in indices { items[idx].isSelected = false }
                        }
                        .font(.caption)
                        .buttonStyle(.borderless)
                    }
                }
            }
        }
        .listStyle(.inset)
    }

    // MARK: - Import Overlay

    private var importOverlay: some View {
        ZStack {
            Color.black.opacity(0.25)
            VStack(spacing: 12) {
                ProgressView(value: importProgress)
                    .progressViewStyle(.linear)
                    .frame(width: 220)
                Text("Resolving code requirements…")
                    .font(.subheadline)
            }
            .padding(24)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
        .ignoresSafeArea()
    }

    // MARK: - Computed Properties

    private var selectedCount: Int { items.filter(\.isSelected).count }

    private var selectedUnresolvedCount: Int {
        items.filter { $0.isSelected && unresolvedItemIDs.contains($0.id) }.count
    }

    private var groupedItems: [(PPPCServiceType, [Int])] {
        let order = PPPCServiceType.allCases
        var groups: [PPPCServiceType: [Int]] = [:]
        for (idx, item) in items.enumerated() {
            groups[item.serviceType, default: []].append(idx)
        }
        return order.compactMap { st in
            guard let indices = groups[st], !indices.isEmpty else { return nil }
            return (st, indices)
        }
    }

    private func isAlreadyInProfile(_ item: TCCImportItem) -> Bool {
        guard let service = profile.services.first(where: { $0.serviceType == item.serviceType })
        else { return false }
        if item.serviceType == .appleEvents {
            return service.apps.contains {
                $0.identifier == item.client &&
                $0.aeReceiverIdentifier == (item.aeReceiverIdentifier ?? "")
            }
        }
        return service.apps.contains { $0.identifier == item.client }
    }

    // MARK: - Load

    private func loadItems() {
        isLoading = true
        defer { isLoading = false }
        loadError = nil

        do {
            var allItems: [TCCImportItem] = []
            for source in TCCSource.allCases where selectedSources.contains(source) {
                let loaded = try TCCImporter.loadItems(from: source)
                allItems = allItems.isEmpty ? loaded : TCCImporter.merge(allItems, loaded)
            }
            let order = PPPCServiceType.allCases
            items = allItems.sorted {
                (order.firstIndex(of: $0.serviceType) ?? order.count) <
                (order.firstIndex(of: $1.serviceType) ?? order.count)
            }
            // Pre-compute which items have no resolvable app path
            unresolvedItemIDs = Set(items.compactMap { item in
                appPath(for: item.client, type: item.clientType) == nil ? item.id : nil
            })
            hasLoaded = true
        } catch {
            if case TCCImportError.permissionDenied = error {
                isPermissionDeniedError = true
            }
            loadError = error
            showLoadError = true
        }
    }

    private func openPrivacySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_AllFiles")!
        NSWorkspace.shared.open(url)
    }

    // MARK: - Import

    private func appPath(for identifier: String, type: IdentifierType) -> String? {
        switch type {
        case .bundleID:
            return NSWorkspace.shared.urlForApplication(withBundleIdentifier: identifier)?.path
        case .path:
            return FileManager.default.fileExists(atPath: identifier) ? identifier : nil
        }
    }

    private func performImport() async {
        let selected = items.filter(\.isSelected)
        guard !selected.isEmpty else { return }

        // Pre-resolve paths on MainActor (NSWorkspace calls)
        let paths: [(String?, String?)] = selected.map { item in
            (appPath(for: item.client, type: item.clientType),
             item.aeReceiverIdentifier.flatMap {
                 appPath(for: $0, type: item.aeReceiverIdentifierType ?? .bundleID)
             })
        }

        isImporting    = true
        importProgress = 0
        await Task.yield()   // allow overlay to appear before blocking calls start

        var resolved = selected
        for i in 0..<resolved.count {
            resolved[i].resolvedCodeRequirement   = paths[i].0.flatMap { TCCImporter.codeRequirement(for: $0) }
            resolved[i].resolvedAECodeRequirement = paths[i].1.flatMap { TCCImporter.codeRequirement(for: $0) }
            importProgress = Double(i + 1) / Double(resolved.count)
            await Task.yield()   // keep UI responsive between codesign calls
        }

        // Merge into profile
        for item in resolved {
            let entry = TCCImporter.makeAppEntry(from: item)
            if let idx = profile.services.firstIndex(where: { $0.serviceType == item.serviceType }) {
                profile.services[idx].apps.append(entry)
            } else {
                profile.services.append(PPPCServiceEntry(serviceType: item.serviceType, apps: [entry]))
            }
        }
        profile.services.sortByServiceType()

        let missingCount = resolved.filter { ($0.resolvedCodeRequirement ?? "").isEmpty }.count

        isImporting = false

        if missingCount > 0 {
            importSummaryCount = missingCount
            showImportSummary  = true
            // dismiss() is called from the summary alert's OK button
        } else {
            dismiss()
        }
    }
}

// MARK: - TCCItemRow

private struct TCCItemRow: View {
    let item:            TCCImportItem
    @Binding var isSelected: Bool
    let alreadyInProfile: Bool
    let appMissing:      Bool

    var body: some View {
        Toggle(isOn: $isSelected) {
            HStack(spacing: 8) {
                AppBadgeView(identifier: item.client,
                             identifierType: item.clientType,
                             size: 20)

                if item.serviceType == .appleEvents,
                   let receiver = item.aeReceiverIdentifier,
                   let receiverType = item.aeReceiverIdentifierType {
                    Image(systemName: "arrow.right")
                        .foregroundStyle(.secondary)
                        .imageScale(.small)
                    AppBadgeView(identifier: receiver,
                                 identifierType: receiverType,
                                 size: 20)
                }

                Spacer()

                if appMissing {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .imageScale(.small)
                        .help("Application not found on this Mac — code requirement will be empty if imported")
                }

                authBadge

                if alreadyInProfile {
                    Text("In Profile")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.secondary.opacity(0.12), in: Capsule())
                }
            }
        }
        .toggleStyle(.checkbox)
    }

    @ViewBuilder private var authBadge: some View {
        switch item.serviceType {
        case .inputMonitoring, .screenRecording:
            Text("Standard User")
                .font(.caption2)
                .foregroundStyle(.orange)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.orange.opacity(0.12), in: Capsule())
        default:
            if item.authValue == 2 {
                Text("Allow")
                    .font(.caption2)
                    .foregroundStyle(.green)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.green.opacity(0.12), in: Capsule())
            } else {
                Text("Deny")
                    .font(.caption2)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.red.opacity(0.12), in: Capsule())
            }
        }
    }
}
