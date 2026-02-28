// MobileconfigParser.swift
// Intune PPPC Utility
//
// Parses Apple Configuration Profile (.mobileconfig) files — which are plists —
// into the internal PPPCProfile model. One-way import only; no export back to
// mobileconfig format is provided.

import Foundation
import UniformTypeIdentifiers

// MARK: - UTType for .mobileconfig

extension UTType {
    /// Uniform type identifier for Apple Configuration Profile (.mobileconfig) files.
    static let mobileconfig = UTType(filenameExtension: "mobileconfig") ?? .data
}

// MARK: - Parse Errors

enum MobileconfigParseError: LocalizedError, CustomNSError {
    case notPlist
    case noPPPCPayload

    var errorDescription: String? {
        switch self {
        case .notPlist:
            return "\n\nThe selected file is not a valid property list. " +
                   "Mobileconfig files must be XML or binary plist format."
        case .noPPPCPayload:
            return "\n\nNo PPPC payload was found in this mobileconfig file.\n\n" +
                   "The file must contain a payload with PayloadType " +
                   "\"com.apple.TCC.configuration-profile-policy\"."
        }
    }

    static var errorDomain: String { "com.IntunePPPCUtility.MobileconfigParseError" }

    var errorCode: Int {
        switch self {
        case .notPlist:      return 1
        case .noPPPCPayload: return 2
        }
    }

    var errorUserInfo: [String: Any] {
        [NSLocalizedFailureReasonErrorKey: errorDescription ?? ""]
    }
}

// MARK: - Parser

struct MobileconfigParser {

    private static let pppcPayloadType = "com.apple.TCC.configuration-profile-policy"

    /// Parses a `.mobileconfig` plist and returns a new `PPPCProfile`.
    ///
    /// The returned profile gets a fresh UUID and nil timestamps — it is treated as
    /// a new Intune policy, not a round-trip of an existing one.
    ///
    /// - Parameters:
    ///   - data: Raw file data (XML or binary plist).
    ///   - suggestedName: Fallback display name used when `PayloadDisplayName` is absent.
    static func parse(_ data: Data, suggestedName: String = "Imported PPPC Profile") throws -> PPPCProfile {
        guard let root = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else {
            throw MobileconfigParseError.notPlist
        }

        let profileName        = root["PayloadDisplayName"] as? String ?? suggestedName
        let profileDescription = root["PayloadDescription"] as? String ?? ""

        // Locate the PPPC payload inside the PayloadContent array
        guard
            let payloadContent = root["PayloadContent"] as? [[String: Any]],
            let pppcPayload    = payloadContent.first(where: {
                ($0["PayloadType"] as? String) == pppcPayloadType
            })
        else {
            throw MobileconfigParseError.noPPPCPayload
        }

        let services = parseServices(from: pppcPayload)

        return PPPCProfile(
            name:                profileName,
            description:         profileDescription,
            id:                  UUID().uuidString.lowercased(),
            createdDateTime:     nil,
            lastModifiedDateTime: nil,
            services:            services
        )
    }

    // MARK: - Services

    private static func parseServices(from payload: [String: Any]) -> [PPPCServiceEntry] {
        guard let services = payload["Services"] as? [String: Any] else { return [] }

        var entries: [PPPCServiceEntry] = []

        for (key, value) in services {
            // Mobileconfig service keys are CamelCase (e.g. "Accessibility", "AppleEvents").
            // Lowercasing them gives the jsonKey used by PPPCServiceType directly.
            guard
                let serviceType = PPPCServiceType(jsonKey: key.lowercased()),
                let appDicts    = value as? [[String: Any]]
            else { continue }

            let apps = appDicts.compactMap { parseAppEntry(from: $0, serviceType: serviceType) }
            if !apps.isEmpty {
                entries.append(PPPCServiceEntry(serviceType: serviceType, apps: apps))
            }
        }

        entries.sortByServiceType()
        return entries
    }

    // MARK: - App Entry

    private static func parseAppEntry(
        from dict: [String: Any],
        serviceType: PPPCServiceType
    ) -> PPPCAppEntry? {
        guard
            let identifier = dict["Identifier"] as? String,
            !identifier.isEmpty
        else { return nil }

        var app        = PPPCAppEntry(for: serviceType)
        app.identifier = identifier

        if let typeStr = dict["IdentifierType"] as? String {
            app.identifierType = (typeStr == "path") ? .path : .bundleID
        }

        if let cr = dict["CodeRequirement"] as? String {
            app.codeRequirement = cr
        }

        // Allowed (Bool) and Authorization (String) are mutually exclusive
        if let allowed = dict["Allowed"] as? Bool {
            app.permissionType = .allowed
            app.allowedValue   = allowed
        } else if let authStr = dict["Authorization"] as? String {
            app.permissionType     = .authorization
            app.authorizationValue = AuthorizationValue(mobileconfigString: authStr) ?? .allow
        }

        if let staticBool = dict["StaticCode"] as? Bool {
            app.staticCode = staticBool ? .enabled : .disabled
        }

        if let comment = dict["Comment"] as? String, !comment.isEmpty {
            app.comment = comment
        }

        // Apple Events receiver fields (present only for the AppleEvents service type)
        if let aeID = dict["AEReceiverIdentifier"] as? String, !aeID.isEmpty {
            app.aeReceiverIdentifier = aeID
        }
        if let aeCR = dict["AEReceiverCodeRequirement"] as? String, !aeCR.isEmpty {
            app.aeReceiverCodeRequirement = aeCR
        }
        if let aeTypeStr = dict["AEReceiverIdentifierType"] as? String {
            app.aeReceiverIdentifierType = (aeTypeStr == "path") ? .path : .bundleID
        }

        return app
    }
}
