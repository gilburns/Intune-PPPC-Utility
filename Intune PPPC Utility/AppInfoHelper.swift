//  AppInfoHelper.swift
//  Intune PPPC Utility
//
//  Looks up the app icon and display name for a bundle identifier using
//  NSWorkspace, with a simple in-memory cache to avoid repeated lookups.
//
//  All methods are implicitly @MainActor (SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor),
//  so no manual thread-hopping is needed - NSWorkspace calls are fast enough for
//  the main thread and AppIconView's loadIcon() is already on the main actor.
//

import SwiftUI
import AppKit

// MARK: - AppInfoHelper

class AppInfoHelper {
    static let shared = AppInfoHelper()

    /// Cache of successful lookups: bundleID → (icon, display name without .app extension)
    private var cache: [String: (NSImage, String)] = [:]

    private init() {}

    /// Returns the icon and display name for `bundleID`, or `(nil, nil)` if not found.
    /// Results are cached in memory so repeated calls for the same ID are instant.
    func getIconAndName(for bundleID: String) -> (NSImage?, String?) {
        // Fast path: already cached
        if let cached = cache[bundleID] {
            return (cached.0, cached.1)
        }

        let workspace = NSWorkspace.shared

        // Primary lookup via NSWorkspace
        if let appURL = workspace.urlForApplication(withBundleIdentifier: bundleID) {
            let name = appURL.deletingPathExtension().lastPathComponent
            let icon = workspace.icon(forFile: appURL.path)
            cache[bundleID] = (icon, name)
            return (icon, name)
        }

        // Fallback: scan common app directories
        if let result = findByScanning(bundleID: bundleID) {
            cache[bundleID] = result
            return (result.0, result.1)
        }

        return (nil, nil)
    }

    // MARK: - Fallback Scanner

    private func findByScanning(bundleID: String) -> (NSImage, String)? {
        let searchPaths = [
            "/Applications",
            "/System/Applications",
            "/Applications/Utilities",
            "/System/Applications/Utilities",
        ]
        let workspace   = NSWorkspace.shared
        let fileManager = FileManager.default

        for base in searchPaths {
            guard let items = try? fileManager.contentsOfDirectory(atPath: base) else { continue }
            for item in items where item.hasSuffix(".app") {
                let fullPath = "\(base)/\(item)"
                if let bundle = Bundle(path: fullPath),
                   bundle.bundleIdentifier == bundleID {
                    let name = URL(fileURLWithPath: fullPath).deletingPathExtension().lastPathComponent
                    let icon = workspace.icon(forFile: fullPath)
                    return (icon, name)
                }
            }
        }
        return nil
    }
}

// MARK: - AppBadgeView

/// Displays the icon and resolved display name for an app identifier.
/// For bundle IDs, looks up the icon via AppInfoHelper.
/// For paths ending in `.app`, reads the bundle icon directly.
/// For other paths (CLI tools, scripts), shows a terminal symbol instead.
struct AppBadgeView: View {
    let identifier: String
    let identifierType: IdentifierType
    let size: CGFloat

    @State private var icon: NSImage?
    @State private var name: String?
    @State private var isCLI = false

    var body: some View {
        HStack(spacing: 4) {
            Group {
                if let icon {
                    Image(nsImage: icon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } else if isCLI {
                    Image(systemName: "terminal")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .foregroundStyle(.secondary)
                } else {
                    Image(systemName: "app.dashed")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: size, height: size)

            Text(name ?? identifier)
                .font(.title)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .onAppear { load() }
        .onChange(of: identifier) { _, _ in reset() }
        .onChange(of: identifierType) { _, _ in reset() }
    }

    private func reset() {
        icon = nil; name = nil; isCLI = false
        load()
    }

    private func load() {
        guard !identifier.isEmpty else { return }

        switch identifierType {
        case .bundleID:
            let info = AppInfoHelper.shared.getIconAndName(for: identifier)
            icon = info.0
            name = info.1

        case .path:
            let url = URL(fileURLWithPath: identifier)
            if identifier.hasSuffix(".app") {
                // App bundle at a path — use its real icon and display name
                icon = NSWorkspace.shared.icon(forFile: identifier)
                name = url.deletingPathExtension().lastPathComponent
            } else {
                // CLI tool, script, or other non-bundle binary
                isCLI = true
                name = url.lastPathComponent
            }
        }
    }
}

// MARK: - AppIconView

/// Displays the icon for a bundle identifier, loading it asynchronously on first use.
/// Falls back to a generic app icon when the bundle cannot be resolved.
struct AppIconView: View {
    let bundleID: String?
    let size: CGFloat

    @State private var appIcon: NSImage?

    var body: some View {
        Group {
            if let icon = appIcon {
                Image(nsImage: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                // Placeholder while loading or when not found
                Image(systemName: "app.dashed")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: size, height: size)
        .onAppear { loadIcon() }
        .onChange(of: bundleID) { _, _ in
            appIcon = nil
            loadIcon()
        }
    }

    private func loadIcon() {
        guard let id = bundleID, !id.isEmpty else { appIcon = nil; return }
        // AppInfoHelper is @MainActor; this view is @MainActor — no dispatch needed.
        appIcon = AppInfoHelper.shared.getIconAndName(for: id).0
    }
}
