// PPPCServiceType.swift
// Intune PPPC Utility

import Foundation

enum PPPCServiceType: String, CaseIterable, Identifiable, Hashable {
    case accessibility
    case addressbook           = "addressbook"
    case appleEvents           = "appleevents"
    case bluetoothAlways       = "bluetoothalways"
    case calendar
    case camera
    case fileProviderPresence  = "fileproviderpresence"
    case inputMonitoring       = "listenevent"
    case mediaLibrary          = "medialibrary"
    case microphone
    case photos
    case postEvent             = "postevent"
    case reminders
    case screenRecording       = "screencapture"
    case speechRecognition     = "speechrecognition"
    case systemPolicyAllFiles          = "systempolicyallfiles"
    case systemPolicyAppBundles        = "systempolicyappbundles"
    case systemPolicyAppData           = "systempolicyappdata"
    case systemPolicyDesktopFolder     = "systempolicydesktopfolder"
    case systemPolicyDocumentsFolder   = "systempolicydocumentsfolder"
    case systemPolicyDownloadsFolder   = "systempolicydownloadsfolder"
    case systemPolicyNetworkVolumes    = "systempolicynetworkvolumes"
    case systemPolicyRemovableVolumes  = "systempolicyremovablevolumes"
    case systemPolicySysAdminFiles     = "systempolicysysadminfiles"

    nonisolated var id: String { rawValue }

    // The key used verbatim in Intune settingDefinitionId
    nonisolated var jsonKey: String { rawValue }

    nonisolated var displayName: String {
        switch self {
        case .accessibility:              return "Accessibility"
        case .addressbook:                return "Address Book"
        case .appleEvents:                return "Apple Events"
        case .bluetoothAlways:            return "Bluetooth Always"
        case .calendar:                   return "Calendar"
        case .camera:                     return "Camera"
        case .fileProviderPresence:       return "File Provider Presence"
        case .inputMonitoring:            return "Input Monitoring (Listen Event)"
        case .mediaLibrary:               return "Media Library"
        case .microphone:                 return "Microphone"
        case .photos:                     return "Photos"
        case .postEvent:                  return "Post Event"
        case .reminders:                  return "Reminders"
        case .screenRecording:            return "Screen Capture"
        case .speechRecognition:          return "Speech Recognition"
        case .systemPolicyAllFiles:       return "System Policy All Files (Full Disk Access)"
        case .systemPolicyAppBundles:     return "System Policy App Bundles"
        case .systemPolicyAppData:        return "System Policy App Data"
        case .systemPolicyDesktopFolder:  return "System Policy Desktop Folder"
        case .systemPolicyDocumentsFolder:return "System Policy Documents Folder"
        case .systemPolicyDownloadsFolder:return "System Policy Downloads Folder"
        case .systemPolicyNetworkVolumes: return "System Policy Network Volumes"
        case .systemPolicyRemovableVolumes:return "System Policy Removable Volumes"
        case .systemPolicySysAdminFiles:  return "System Admin Files"
        }
    }

    nonisolated var serviceDescription: String {
        switch self {
        case .accessibility:
            return "Allows specified apps to control the Mac via Accessibility APIs."
        case .addressbook:
            return "Allows specified apps access to contact information managed by Contacts."
        case .appleEvents:
            return "Allows specified apps to send a restricted AppleEvent to another process."
        case .bluetoothAlways:
            return "Specifies the policies for the app to access Bluetooth devices."
        case .calendar:
            return "Allows specified apps access to event information managed by Calendar."
        case .camera:
            return "A system camera. Access to the camera can't be given in a profile; it can only be denied."
        case .fileProviderPresence:
            return "Allows a File Provider application to know when the user is using files managed by the File Provider."
        case .inputMonitoring:
            return "Set which approved apps have specified access to input devices (mouse, keyboard, trackpad)."
        case .mediaLibrary:
            return "Allows specified apps access to Apple Music, music and video activity, and the media library."
        case .microphone:
            return "Deny specified apps access to the microphone."
        case .photos:
            return "Allows specified apps access to images managed by the Photos app in:\n\n/Users/username/Pictures/Photos Library\n\nNote: If the user put their photo library somewhere else, it won't be protected from apps."
        case .postEvent:
            return "Allows the application to use CoreGraphics and HID APIs to listen to (receive) CGEvents and HID events from all processes. Access to these events can't be given in a profile; it can only be denied."
        case .reminders:
            return "Allows specified apps access to information managed by Reminders."
        case .screenRecording:
            return "Deny specified apps access to capture (read) the contents of the system display."
        case .speechRecognition:
            return "Allows specified apps to use the system Speech Recognition feature and to send speech data to Apple."
        case .systemPolicyAllFiles:
            return "Allows specified apps access to data like Mail, Messages, Safari, Home, Time Machine backups, and certain administrative settings for all users of the Mac."
        case .systemPolicyAppBundles:
            return "Allows the application to update or delete other apps. Available in macOS 13 and later."
        case .systemPolicyAppData:
            return "Specifies the policies for the app to access the data of other apps."
        case .systemPolicyDesktopFolder:
            return "Allows specified apps access to the Desktop folder."
        case .systemPolicyDocumentsFolder:
            return "Allows specified apps access to the Documents folder."
        case .systemPolicyDownloadsFolder:
            return "Allows specified apps access to the Downloads folder."
        case .systemPolicyNetworkVolumes:
            return "Allows specified apps access to files on network volumes."
        case .systemPolicyRemovableVolumes:
            return "Allows specified apps access to files on removable volumes."
        case .systemPolicySysAdminFiles:
            return "Allows specified apps access to some files used by system administrators."
        }
    }

    // Services that naturally use Allowed (true/false) rather than Authorization enum
    // Users can freely switch between the two types
    nonisolated var defaultPermissionType: PPPCPermissionType {
        switch self {
        case .accessibility, .bluetoothAlways, .systemPolicyAllFiles,
             .systemPolicyDownloadsFolder, .systemPolicySysAdminFiles:
            return .allowed
        default:
            return .authorization
        }
    }

    nonisolated var isAppleEvents: Bool { self == .appleEvents }
    nonisolated var isBluetooth: Bool  { self == .bluetoothAlways }

    /// Service types where access can only be denied via configuration profile, never granted.
    /// Apple requires user consent for these at runtime; a profile can only block, not pre-approve.
    nonisolated var isDenyOnly: Bool { self == .camera || self == .microphone }

    /// The subset of AuthorizationValue cases that are valid for this service type.
    ///   • Camera, Microphone   → [.deny]                     (access cannot be granted by profile)
    ///   • Input Monitoring,
    ///     Screen Recording     → [.deny, .allowStandardUser]  (no direct allow; user must consent)
    ///   • all others           → [.allow, .deny]              (allowStandardUser not applicable)
    nonisolated var allowedAuthorizationValues: [AuthorizationValue] {
        switch self {
        case .camera, .microphone:
            return [.deny]
        case .inputMonitoring, .screenRecording:
            return [.deny, .allowStandardUser]
        default:
            return [.allow, .deny]
        }
    }

    nonisolated var systemImage: String {
        switch self {
        case .accessibility:               return "figure.arms.open"
        case .addressbook:                 return "person.crop.circle"
        case .appleEvents:                 return "arrow.up.arrow.down.circle"
        case .bluetoothAlways:             return "dot.radiowaves.left.and.right"
        case .calendar:                    return "calendar"
        case .camera:                      return "camera"
        case .fileProviderPresence:        return "folder"
        case .inputMonitoring:             return "keyboard"
        case .mediaLibrary:                return "music.note"
        case .microphone:                  return "microphone"
        case .photos:                      return "photo"
        case .postEvent:                   return "ear"
        case .reminders:                   return "checklist"
        case .screenRecording:             return "rectangle.on.rectangle"
        case .speechRecognition:           return "waveform"
        case .systemPolicyAllFiles:        return "internaldrive"
        case .systemPolicyAppBundles:      return "app"
        case .systemPolicyAppData:         return "doc"
        case .systemPolicyDesktopFolder:   return "desktopcomputer"
        case .systemPolicyDocumentsFolder: return "doc.text"
        case .systemPolicyDownloadsFolder: return "arrow.down.circle"
        case .systemPolicyNetworkVolumes:  return "network"
        case .systemPolicyRemovableVolumes:return "externaldrive"
        case .systemPolicySysAdminFiles:   return "gearshape.2"
        }
    }

    init?(jsonKey: String) {
        self.init(rawValue: jsonKey)
    }
}
