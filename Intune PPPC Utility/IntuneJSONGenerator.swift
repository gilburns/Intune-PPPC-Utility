// IntuneJSONGenerator.swift
// Intune PPPC Utility
//
// Generates the Microsoft Graph API configurationPolicies JSON format
// from the internal PPPCProfile model.
//
// Field ordering within each app entry's children array matches the
// ordering observed in Intune-exported JSON files.

import Foundation

struct IntuneJSONGenerator {

    private static let basePrefix  = "com.apple.tcc.configuration-profile-policy"
    private static let groupType   = "#microsoft.graph.deviceManagementConfigurationGroupSettingCollectionInstance"
    private static let choiceType  = "#microsoft.graph.deviceManagementConfigurationChoiceSettingInstance"
    private static let simpleType  = "#microsoft.graph.deviceManagementConfigurationSimpleSettingInstance"
    private static let stringValue = "#microsoft.graph.deviceManagementConfigurationStringSettingValue"

    static func generate(_ profile: PPPCProfile) throws -> Data {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let now = formatter.string(from: Date())

        let json: [String: Any] = [
            "@odata.context":       "https://graph.microsoft.com/beta/$metadata#deviceManagement/configurationPolicies/$entity",
            "createdDateTime":      profile.createdDateTime ?? now,
            "creationSource":       NSNull(),
            "description":          profile.description,
            "lastModifiedDateTime": now,
            "name":                 profile.name,
            "platforms":            "macOS",
            "priorityMetaData":     NSNull(),
            "roleScopeTagIds":      ["0"],
            "settingCount":         1,
            "technologies":         "mdm,appleRemoteManagement",
            "id":                   profile.id,
            "templateReference": [
                "templateId":           "",
                "templateFamily":       "none",
                "templateDisplayName":  NSNull(),
                "templateDisplayVersion": NSNull()
            ] as [String: Any],
            "settings": [buildSettingsNode(from: profile.services)]
        ]

        return try JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted])
    }

    // MARK: - Top-Level Settings Node

    private static func buildSettingsNode(from services: [PPPCServiceEntry]) -> [String: Any] {
        [
            "id": "0",
            "settingInstance": [
                "@odata.type":                    groupType,
                "settingDefinitionId":            "\(basePrefix)_\(basePrefix)",
                "settingInstanceTemplateReference": NSNull(),
                "auditRuleInformation":           NSNull(),
                "groupSettingCollectionValue": [
                    [
                        "settingValueTemplateReference": NSNull(),
                        "children": [buildServicesNode(from: services)]
                    ] as [String: Any]
                ]
            ] as [String: Any]
        ]
    }

    // MARK: - Services Container Node

    private static func buildServicesNode(from services: [PPPCServiceEntry]) -> [String: Any] {
        [
            "@odata.type":                    groupType,
            "settingDefinitionId":            "\(basePrefix)_services",
            "settingInstanceTemplateReference": NSNull(),
            "auditRuleInformation":           NSNull(),
            "groupSettingCollectionValue": [
                [
                    "settingValueTemplateReference": NSNull(),
                    "children": services.map { buildServiceNode(from: $0) }
                ] as [String: Any]
            ]
        ]
    }

    // MARK: - Per-Service Node

    private static func buildServiceNode(from entry: PPPCServiceEntry) -> [String: Any] {
        [
            "@odata.type":                    groupType,
            "settingDefinitionId":            "\(basePrefix)_services_\(entry.serviceType.jsonKey)",
            "settingInstanceTemplateReference": NSNull(),
            "auditRuleInformation":           NSNull(),
            "groupSettingCollectionValue":    entry.apps.map {
                buildAppNode(from: $0, serviceType: entry.serviceType)
            }
        ]
    }

    // MARK: - Per-App Node

    private static func buildAppNode(
        from app: PPPCAppEntry,
        serviceType: PPPCServiceType
    ) -> [String: Any] {
        let prefix = "\(basePrefix)_services_\(serviceType.jsonKey)_item"
        var children: [[String: Any]] = []

        // 1. Apple Events receiver fields (present only for appleEvents service)
        if serviceType.isAppleEvents {
            if !app.aeReceiverCodeRequirement.isEmpty {
                children.append(simple(defId: "\(prefix)_aereceivercoderequirement",
                                       value: app.aeReceiverCodeRequirement))
            }
            if !app.aeReceiverIdentifier.isEmpty {
                children.append(simple(defId: "\(prefix)_aereceiveridentifier",
                                       value: app.aeReceiverIdentifier))
                children.append(choice(defId: "\(prefix)_aereceiveridentifiertype",
                                       value: "\(prefix)_aereceiveridentifiertype\(app.aeReceiverIdentifierType.jsonSuffix)"))
            }
        }

        // 2. Permission field (allowed XOR authorization — never both)
        switch app.permissionType {
        case .allowed:
            let suffix = app.allowedValue ? "_true" : "_false"
            children.append(choice(defId: "\(prefix)_allowed",
                                   value: "\(prefix)_allowed\(suffix)"))
        case .authorization:
            children.append(choice(defId: "\(prefix)_authorization",
                                   value: "\(prefix)_authorization\(app.authorizationValue.jsonSuffix)"))
        }

        // 3. Code requirement
        children.append(simple(defId: "\(prefix)_coderequirement",
                               value: app.codeRequirement))

        // 4. Comment (always written when non-empty; Intune only displays it for Bluetooth,
        //    but other service types accept and preserve it — useful as a documentation note)
        if !app.comment.isEmpty {
            children.append(simple(defId: "\(prefix)_comment", value: app.comment))
        }

        // 5. Identifier
        children.append(simple(defId: "\(prefix)_identifier", value: app.identifier))

        // 6. Identifier type
        children.append(choice(defId: "\(prefix)_identifiertype",
                               value: "\(prefix)_identifiertype\(app.identifierType.jsonSuffix)"))

        // 7. Static code (omitted when .notSet — keeps JSON clean by default)
        if let staticBool = app.staticCode.boolValue {
            let suffix = staticBool ? "_true" : "_false"
            children.append(choice(defId: "\(prefix)_staticcode",
                                   value: "\(prefix)_staticcode\(suffix)"))
        }

        return [
            "settingValueTemplateReference": NSNull(),
            "children": children
        ]
    }

    // MARK: - Node Builders

    private static func simple(defId: String, value: String) -> [String: Any] {
        [
            "@odata.type":                    simpleType,
            "settingDefinitionId":            defId,
            "settingInstanceTemplateReference": NSNull(),
            "auditRuleInformation":           NSNull(),
            "simpleSettingValue": [
                "@odata.type":                  stringValue,
                "settingValueTemplateReference": NSNull(),
                "value":                        value
            ] as [String: Any]
        ]
    }

    private static func choice(defId: String, value: String) -> [String: Any] {
        [
            "@odata.type":                    choiceType,
            "settingDefinitionId":            defId,
            "settingInstanceTemplateReference": NSNull(),
            "auditRuleInformation":           NSNull(),
            "choiceSettingValue": [
                "settingValueTemplateReference": NSNull(),
                "value":                        value,
                "children":                     [] as [[String: Any]]
            ] as [String: Any]
        ]
    }
}
