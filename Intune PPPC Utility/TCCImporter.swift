// TCCImporter.swift
// Intune PPPC Utility
//
// Reads macOS TCC.db files and converts their entries into PPPCAppEntry objects.
// All methods that touch the filesystem or run processes are marked nonisolated
// so they can safely be called from background contexts.

import Foundation
import AppKit

// MARK: - TCCSource

enum TCCSource: String, CaseIterable, Identifiable {
    case user   = "User Database"
    case system = "System Database"

    var id: Self { self }

    var dbPath: String {
        switch self {
        case .user:
            return (NSHomeDirectory() as NSString)
                .appendingPathComponent("Library/Application Support/com.apple.TCC/TCC.db")
        case .system:
            return "/Library/Application Support/com.apple.TCC/TCC.db"
        }
    }
}

// MARK: - TCCImportError

enum TCCImportError: LocalizedError {
    case fileNotFound(String)
    case permissionDenied
    case copyFailed(Error)
    case queryFailed(String)

    var errorDescription: String? {
        switch self {
        case .fileNotFound(let p):
            return "TCC database not found at \(p)."
        case .permissionDenied:
            return "Permission denied. Grant Full Disk Access to Intune PPPC Utility in System Settings → Privacy & Security → Full Disk Access, then try again."
        case .copyFailed(let e):
            return "Could not copy TCC database: \(e.localizedDescription)"
        case .queryFailed(let m):
            return "sqlite3 query failed: \(m)"
        }
    }
}

// MARK: - TCCImportItem

struct TCCImportItem: Identifiable {
    let id                       = UUID()
    let serviceType:               PPPCServiceType
    let client:                    String
    let clientType:                IdentifierType
    let authValue:                 Int          // 0 = deny, 2 = allow (from TCC)
    let aeReceiverIdentifier:      String?
    let aeReceiverIdentifierType:  IdentifierType?
    var isSelected:                Bool = false

    // Populated during import, before building PPPCAppEntry
    var resolvedCodeRequirement:   String?
    var resolvedAECodeRequirement: String?
}

// MARK: - TCC Service → PPPC Type Map
// Camera and Microphone are intentionally omitted: PPPC can only deny those,
// and user consent dialogs are the correct mechanism for them.

private let tccServiceMap: [String: PPPCServiceType] = [
    "kTCCServiceAccessibility":                .accessibility,
    "kTCCServiceAddressBook":                  .addressbook,
    "kTCCServiceAppleEvents":                  .appleEvents,
    "kTCCServiceBluetoothAlways":              .bluetoothAlways,
    "kTCCServiceCalendar":                     .calendar,
    "kTCCServiceFileProviderPresence":         .fileProviderPresence,
    "kTCCServiceListenEvent":                  .inputMonitoring,
    "kTCCServiceMediaLibrary":                 .mediaLibrary,
    "kTCCServicePhotos":                       .photos,
    "kTCCServicePostEvent":                    .postEvent,
    "kTCCServiceReminders":                    .reminders,
    "kTCCServiceScreenCapture":                .screenRecording,
    "kTCCServiceSpeechRecognition":            .speechRecognition,
    "kTCCServiceSystemPolicyAllFiles":         .systemPolicyAllFiles,
    "kTCCServiceSystemPolicyAppBundles":       .systemPolicyAppBundles,
    "kTCCServiceSystemPolicyAppData":          .systemPolicyAppData,
    "kTCCServiceSystemPolicyDesktopFolder":    .systemPolicyDesktopFolder,
    "kTCCServiceSystemPolicyDocumentsFolder":  .systemPolicyDocumentsFolder,
    "kTCCServiceSystemPolicyDownloadsFolder":  .systemPolicyDownloadsFolder,
    "kTCCServiceSystemPolicyNetworkVolumes":   .systemPolicyNetworkVolumes,
    "kTCCServiceSystemPolicyRemovableVolumes": .systemPolicyRemovableVolumes,
    "kTCCServiceSystemPolicySysAdminFiles":    .systemPolicySysAdminFiles,
]

// MARK: - TCCImporter

enum TCCImporter {

    // MARK: Database Query

    /// Copies the TCC.db for `source` to a temp file and queries it via sqlite3.
    /// Marked `nonisolated` — does not use AppKit; safe to call from any thread.
    static func loadItems(from source: TCCSource) throws -> [TCCImportItem] {
        let dbPath = source.dbPath
        guard FileManager.default.fileExists(atPath: dbPath) else {
            throw TCCImportError.fileNotFound(dbPath)
        }

        let tempPath = (NSTemporaryDirectory() as NSString)
            .appendingPathComponent("tcc_import_\(UUID().uuidString).db")
        defer { try? FileManager.default.removeItem(atPath: tempPath) }

        do {
            try FileManager.default.copyItem(atPath: dbPath, toPath: tempPath)
        } catch {
            throw isPermissionError(error) ? TCCImportError.permissionDenied : TCCImportError.copyFailed(error)
        }

        return try queryItems(at: tempPath)
    }

    /// Returns true if `error` looks like a permission / FDA error.
    /// Checks Cocoa codes, POSIX codes, and falls back to string matching so
    /// it catches however macOS TCC decides to report the denial.
    private static func isPermissionError(_ error: Error) -> Bool {
        let nsErr = error as NSError
        if nsErr.domain == NSCocoaErrorDomain {
            switch nsErr.code {
            case NSFileReadNoPermissionError,   // 257
                 NSFileWriteNoPermissionError,  // 513
                 NSFileReadUnknownError:        // 256
                return true
            default: break
            }
        }
        if nsErr.domain == NSPOSIXErrorDomain &&
           (nsErr.code == Int(EPERM) || nsErr.code == Int(EACCES)) {
            return true
        }
        // Fallback: TCC produces messages like "…you don't have permission to access…"
        return nsErr.localizedDescription.localizedCaseInsensitiveContains("permission")
    }

    private static func queryItems(at dbPath: String) throws -> [TCCImportItem] {
        let sql = """
            SELECT service, client, client_type, auth_value,
                   indirect_object_identifier, indirect_object_identifier_type
            FROM access
            WHERE auth_value IN (0, 2)
            ORDER BY service, client
            """

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/sqlite3")
        process.arguments     = ["-json", dbPath, sql]

        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError  = errPipe

        do { try process.run() } catch {
            throw TCCImportError.queryFailed("Could not launch sqlite3: \(error.localizedDescription)")
        }
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            let msg = String(data: errPipe.fileHandleForReading.readDataToEndOfFile(),
                            encoding: .utf8) ?? "unknown error"
            throw TCCImportError.queryFailed(msg.trimmingCharacters(in: .whitespacesAndNewlines))
        }

        let data = outPipe.fileHandleForReading.readDataToEndOfFile()
        guard !data.isEmpty,
              let rows = (try? JSONSerialization.jsonObject(with: data)) as? [[String: Any]]
        else { return [] }

        var items: [TCCImportItem] = []
        for row in rows {
            guard
                let service     = row["service"] as? String,
                let serviceType = tccServiceMap[service],
                let client      = row["client"] as? String, !client.isEmpty,
                let authValue   = row["auth_value"] as? Int
            else { continue }

            let clientType: IdentifierType = (row["client_type"] as? Int) == 1 ? .path : .bundleID

            // "UNUSED" is the literal string TCC stores when there is no receiver
            let aeRaw      = row["indirect_object_identifier"] as? String
            let aeReceiver = aeRaw.flatMap { ($0.isEmpty || $0 == "UNUSED") ? nil : $0 }
            let aeType: IdentifierType? = aeReceiver != nil
                ? ((row["indirect_object_identifier_type"] as? Int) == 1 ? .path : .bundleID)
                : nil

            items.append(TCCImportItem(
                serviceType:              serviceType,
                client:                   client,
                clientType:               clientType,
                authValue:                authValue,
                aeReceiverIdentifier:     aeReceiver,
                aeReceiverIdentifierType: aeType
            ))
        }
        return deduplicated(items)
    }

    // MARK: - Merge (user + system)

    /// Merges two item arrays, preferring auth_value = 2 (allow) over 0 (deny) on duplicate keys.
    nonisolated static func merge(_ a: [TCCImportItem], _ b: [TCCImportItem]) -> [TCCImportItem] {
        var result = a
        for item in b {
            let k = itemKey(item)
            if let idx = result.firstIndex(where: { itemKey($0) == k }) {
                if item.authValue > result[idx].authValue { result[idx] = item }
            } else {
                result.append(item)
            }
        }
        return deduplicated(result)
    }

    nonisolated private static func deduplicated(_ items: [TCCImportItem]) -> [TCCImportItem] {
        var seen: [String: Int] = [:]
        var result: [TCCImportItem] = []
        for item in items {
            let k = itemKey(item)
            if let idx = seen[k] {
                if item.authValue > result[idx].authValue { result[idx] = item }
            } else {
                seen[k] = result.count
                result.append(item)
            }
        }
        return result
    }

    nonisolated private static func itemKey(_ item: TCCImportItem) -> String {
        var key = "\(item.serviceType.jsonKey)|\(item.client)|\(item.clientType.rawValue)"
        if let r = item.aeReceiverIdentifier { key += "|\(r)" }
        return key
    }

    // MARK: - Code Requirement

    /// Runs codesign to extract the designated code requirement for a file path.
    /// `nonisolated` — safe to call without a MainActor hop.
    nonisolated static func codeRequirement(for path: String) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
        process.arguments     = ["-dr", "-", path]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError  = pipe
        guard (try? process.run()) != nil else { return nil }
        process.waitUntilExit()
        let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(),
                           encoding: .utf8) ?? ""
        guard let line  = output.split(separator: "\n").first(where: { $0.contains("designated =>") }),
              let range = line.range(of: "designated => ")
        else { return nil }
        let req = String(line[range.upperBound...])
        return req.isEmpty ? nil : req
    }

    // MARK: - PPPCAppEntry Builder

    /// Converts a fully-resolved TCCImportItem into a PPPCAppEntry.
    static func makeAppEntry(from item: TCCImportItem) -> PPPCAppEntry {
        var entry = PPPCAppEntry(for: item.serviceType)
        entry.identifier      = item.client
        entry.identifierType  = item.clientType
        entry.codeRequirement = item.resolvedCodeRequirement ?? ""

        switch item.serviceType {
        case .inputMonitoring, .screenRecording:
            // These always map to "Allow Standard User to Set System Service" per policy
            entry.permissionType     = .authorization
            entry.authorizationValue = .allowStandardUser
        default:
            entry.permissionType = .allowed
            entry.allowedValue   = (item.authValue == 2)
        }

        if let receiver = item.aeReceiverIdentifier {
            entry.aeReceiverIdentifier      = receiver
            entry.aeReceiverIdentifierType  = item.aeReceiverIdentifierType ?? .bundleID
            entry.aeReceiverCodeRequirement = item.resolvedAECodeRequirement ?? ""
        }

        return entry
    }
}
