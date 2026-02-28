// PPPCModels.swift
// Intune PPPC Utility

import Foundation

// MARK: - Core Profile

struct PPPCProfile {
    var name: String
    var description: String
    var id: String
    var createdDateTime: String?
    var lastModifiedDateTime: String?
    var services: [PPPCServiceEntry]

    static func new() -> PPPCProfile {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let now = formatter.string(from: Date())
        return PPPCProfile(
            name: "New PPPC Profile",
            description: "",
            id: UUID().uuidString.lowercased(),
            createdDateTime: now,
            lastModifiedDateTime: now,
            services: []
        )
    }
}

// MARK: - Service Entry

struct PPPCServiceEntry: Identifiable {
    var id: UUID = UUID()
    var serviceType: PPPCServiceType
    var apps: [PPPCAppEntry]
}

// MARK: - App Entry

struct PPPCAppEntry: Identifiable {
    var id: UUID = UUID()
    var identifier: String = ""
    var identifierType: IdentifierType = .bundleID
    var codeRequirement: String = ""
    var permissionType: PPPCPermissionType
    var allowedValue: Bool = true
    var authorizationValue: AuthorizationValue = .allow
    var staticCode: StaticCodeOption = .notSet
    var comment: String = ""                    // Bluetooth only in console
    var aeReceiverIdentifier: String = ""       // Apple Events only
    var aeReceiverCodeRequirement: String = ""  // Apple Events only
    var aeReceiverIdentifierType: IdentifierType = .bundleID  // Apple Events only

    init(for serviceType: PPPCServiceType) {
        self.permissionType     = serviceType.defaultPermissionType
        self.allowedValue       = serviceType.isDenyOnly ? false : true
        self.authorizationValue = serviceType.allowedAuthorizationValues.first ?? .allow
    }
}

// MARK: - Identifier Type

enum IdentifierType: String, CaseIterable, Hashable {
    case bundleID
    case path

    nonisolated var displayName: String {
        switch self {
        case .bundleID: return "Bundle ID"
        case .path: return "Path"
        }
    }

    nonisolated var jsonSuffix: String {
        switch self {
        case .bundleID: return "_0"
        case .path: return "_1"
        }
    }

    init?(jsonSuffix: String) {
        switch jsonSuffix {
        case "_0": self = .bundleID
        case "_1": self = .path
        default: return nil
        }
    }
}

// MARK: - Permission Type

enum PPPCPermissionType: String, CaseIterable, Hashable {
    case allowed
    case authorization

    nonisolated var displayName: String {
        switch self {
        case .allowed: return "Allowed"
        case .authorization: return "Authorization"
        }
    }
}

// MARK: - Authorization Value

enum AuthorizationValue: Int, CaseIterable, Hashable {
    case allow = 0
    case deny = 1
    case allowStandardUser = 2

    nonisolated var displayName: String {
        switch self {
        case .allow: return "Allow"
        case .deny: return "Deny"
        case .allowStandardUser: return "Allow Standard User to Set System Service"
        }
    }

    nonisolated var jsonSuffix: String { "_\(rawValue)" }

    init?(jsonSuffix: String) {
        switch jsonSuffix {
        case "_0": self = .allow
        case "_1": self = .deny
        case "_2": self = .allowStandardUser
        default: return nil
        }
    }

    /// Initializes from the string values used in mobileconfig `Authorization` keys.
    init?(mobileconfigString: String) {
        switch mobileconfigString {
        case "Allow":                               self = .allow
        case "Deny":                                self = .deny
        case "AllowStandardUserToSetSystemService": self = .allowStandardUser
        default: return nil
        }
    }
}

// MARK: - Static Code Option

enum StaticCodeOption: String, CaseIterable, Hashable {
    case notSet = "Not Set"
    case enabled = "True"
    case disabled = "False"

    nonisolated var boolValue: Bool? {
        switch self {
        case .notSet: return nil
        case .enabled: return true
        case .disabled: return false
        }
    }

    init(from bool: Bool) {
        self = bool ? .enabled : .disabled
    }
}

// MARK: - Service Sorting

extension Array where Element == PPPCServiceEntry {
    /// Sorts in-place by position in PPPCServiceType.allCases (enum declaration order).
    mutating func sortByServiceType() {
        let order = PPPCServiceType.allCases
        sort {
            (order.firstIndex(of: $0.serviceType) ?? order.count) <
            (order.firstIndex(of: $1.serviceType) ?? order.count)
        }
    }
}
