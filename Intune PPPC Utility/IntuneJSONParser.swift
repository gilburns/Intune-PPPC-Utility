// IntuneJSONParser.swift
// Intune PPPC Utility
//
// Parses the Microsoft Graph API configurationPolicies JSON format
// into the internal PPPCProfile model.

import Foundation

enum IntuneParseError: LocalizedError, CustomNSError {
    case notJSONObject
    case notIntuneConfigurationPolicy
    case notMacOSPolicy(String)
    case notPPPCPolicy

    // MARK: LocalizedError

    var errorDescription: String? {
        switch self {
        case .notJSONObject:
            return "\n\nThe file does not contain a valid JSON object."
        case .notIntuneConfigurationPolicy:
            return "\n\nThis file does not appear to be an Intune configuration policy. " +
                   "Only Intune Settings Catalog policies exported from the Microsoft Intune console can be opened."
        case .notMacOSPolicy(let platform):
            return "\n\nThis Intune policy targets \"\(platform)\", not macOS. " +
                   "Only macOS PPPC configuration policies can be opened."
        case .notPPPCPolicy:
            return "\n\nThis is a macOS Intune policy, but it is not a Privacy Preferences Policy Control (PPPC) policy. " +
                   "Only PPPC policies using the com.apple.tcc profile key can be opened."
        }
    }

    // MARK: CustomNSError
    // Ensures our message survives the Swift → AppKit error bridging and appears
    // as the informative (secondary) text in the document-could-not-be-opened alert.

    static var errorDomain: String { "com.IntunePPPCUtility.ParseError" }

    var errorCode: Int {
        switch self {
        case .notJSONObject:                return 1
        case .notIntuneConfigurationPolicy: return 2
        case .notMacOSPolicy:               return 3
        case .notPPPCPolicy:                return 4
        }
    }

    var errorUserInfo: [String: Any] {
        [NSLocalizedFailureReasonErrorKey: errorDescription ?? ""]
    }
}

struct IntuneJSONParser {

    static func parse(_ data: Data) throws -> PPPCProfile {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw IntuneParseError.notJSONObject
        }

        // Validate: must have the Intune settings structure with a settingDefinitionId
        guard let settings    = json["settings"] as? [[String: Any]],
              let firstSetting = settings.first,
              let instance     = firstSetting["settingInstance"] as? [String: Any],
              let defId        = instance["settingDefinitionId"] as? String else {
            throw IntuneParseError.notIntuneConfigurationPolicy
        }

        // Validate: must be a macOS policy
        if let platform = json["platforms"] as? String, platform != "macOS" {
            throw IntuneParseError.notMacOSPolicy(platform)
        }

        // Validate: must be a PPPC policy (TCC prefix), not some other settings catalog item
        guard defId.contains("com.apple.tcc.configuration-profile-policy") else {
            throw IntuneParseError.notPPPCPolicy
        }

        let name               = json["name"] as? String ?? ""
        let description        = json["description"] as? String ?? ""
        let id                 = json["id"] as? String ?? UUID().uuidString.lowercased()
        let createdDateTime    = json["createdDateTime"] as? String
        let lastModifiedDateTime = json["lastModifiedDateTime"] as? String
        let services           = parseServices(from: json)

        return PPPCProfile(
            name: name,
            description: description,
            id: id,
            createdDateTime: createdDateTime,
            lastModifiedDateTime: lastModifiedDateTime,
            services: services
        )
    }

    // MARK: - Service Parsing

    private static func parseServices(from json: [String: Any]) -> [PPPCServiceEntry] {
        // Path: settings[0]
        //         .settingInstance
        //         .groupSettingCollectionValue[0].children
        //           → find child whose settingDefinitionId ends with "_services"
        //         .groupSettingCollectionValue[0].children
        //           → one element per configured service type
        guard
            let settings       = json["settings"] as? [[String: Any]],
            let setting        = settings.first,
            let instance       = setting["settingInstance"] as? [String: Any],
            let outerValues    = instance["groupSettingCollectionValue"] as? [[String: Any]],
            let outerFirst     = outerValues.first,
            let outerChildren  = outerFirst["children"] as? [[String: Any]]
        else { return [] }

        guard
            let servicesNode   = outerChildren.first(where: {
                ($0["settingDefinitionId"] as? String)?.hasSuffix("_services") == true
            }),
            let servicesValues = servicesNode["groupSettingCollectionValue"] as? [[String: Any]],
            let servicesFirst  = servicesValues.first,
            let serviceNodes   = servicesFirst["children"] as? [[String: Any]]
        else { return [] }

        var entries: [PPPCServiceEntry] = []

        for serviceNode in serviceNodes {
            guard
                let defId = serviceNode["settingDefinitionId"] as? String
            else { continue }

            // Extract the type key:
            // "com.apple.tcc.configuration-profile-policy_services_accessibility"
            //   → split on "_services_" → take [1] → "accessibility"
            let parts = defId.components(separatedBy: "_services_")
            guard parts.count >= 2 else { continue }
            let typeKey = parts[1]

            guard let serviceType = PPPCServiceType(jsonKey: typeKey) else { continue }

            guard
                let appValues = serviceNode["groupSettingCollectionValue"] as? [[String: Any]]
            else { continue }

            var apps: [PPPCAppEntry] = []
            for appValue in appValues {
                guard let children = appValue["children"] as? [[String: Any]] else { continue }
                if let app = parseAppEntry(from: children, serviceType: serviceType) {
                    apps.append(app)
                }
            }

            if !apps.isEmpty {
                entries.append(PPPCServiceEntry(serviceType: serviceType, apps: apps))
            }
        }

        entries.sortByServiceType()
        return entries
    }

    // MARK: - App Entry Parsing

    private static func parseAppEntry(
        from children: [[String: Any]],
        serviceType: PPPCServiceType
    ) -> PPPCAppEntry? {
        var app = PPPCAppEntry(for: serviceType)
        var hasIdentifier = false

        for child in children {
            guard let defId = child["settingDefinitionId"] as? String else { continue }

            // Extract field name:
            // "com.apple.tcc..._services_accessibility_item_allowed" → split on "_item_" → "allowed"
            let itemParts = defId.components(separatedBy: "_item_")
            guard itemParts.count >= 2 else { continue }
            let fieldName = itemParts[1]

            switch fieldName {

            case "identifier":
                if let str = simpleString(from: child) {
                    app.identifier = str
                    hasIdentifier = true
                }

            case "identifiertype":
                if let suffix = choiceSuffix(from: child, fieldDefId: defId) {
                    app.identifierType = IdentifierType(jsonSuffix: suffix) ?? .bundleID
                }

            case "coderequirement":
                if let str = simpleString(from: child) {
                    app.codeRequirement = str
                }

            case "allowed":
                if let suffix = choiceSuffix(from: child, fieldDefId: defId) {
                    app.permissionType = .allowed
                    app.allowedValue   = suffix == "_true"
                }

            case "authorization":
                if let suffix = choiceSuffix(from: child, fieldDefId: defId) {
                    app.permissionType      = .authorization
                    app.authorizationValue  = AuthorizationValue(jsonSuffix: suffix) ?? .allow
                }

            case "staticcode":
                if let suffix = choiceSuffix(from: child, fieldDefId: defId) {
                    app.staticCode = suffix == "_true" ? .enabled : .disabled
                }

            case "comment":
                if let str = simpleString(from: child) {
                    app.comment = str
                }

            case "aereceiveridentifier":
                if let str = simpleString(from: child) {
                    app.aeReceiverIdentifier = str
                }

            case "aereceivercoderequirement":
                if let str = simpleString(from: child) {
                    app.aeReceiverCodeRequirement = str
                }

            case "aereceiveridentifiertype":
                if let suffix = choiceSuffix(from: child, fieldDefId: defId) {
                    app.aeReceiverIdentifierType = IdentifierType(jsonSuffix: suffix) ?? .bundleID
                }

            default:
                break
            }
        }

        return hasIdentifier ? app : nil
    }

    // MARK: - Helpers

    private nonisolated static func simpleString(from child: [String: Any]) -> String? {
        guard
            let val = child["simpleSettingValue"] as? [String: Any],
            let str = val["value"] as? String
        else { return nil }
        return str
    }

    private nonisolated static func choiceSuffix(
        from child: [String: Any],
        fieldDefId: String
    ) -> String? {
        guard
            let val   = child["choiceSettingValue"] as? [String: Any],
            let value = val["value"] as? String
        else { return nil }

        // The choice value is the field's settingDefinitionId with the option appended,
        // e.g. fieldDefId = "...accessibility_item_allowed"
        //      value      = "...accessibility_item_allowed_true"
        //      suffix     = "_true"
        if value.hasPrefix(fieldDefId) {
            return String(value.dropFirst(fieldDefId.count))
        }

        // Fallback: take everything after the last known suffix separator
        if let lastUnderscore = value.lastIndex(of: "_") {
            return String(value[lastUnderscore...])
        }
        return nil
    }
}
