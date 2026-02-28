// AppEntryView.swift
// Intune PPPC Utility
//
// Form fields for a single PPPC app entry within a service type.
// Shown as a Section inside ServiceDetailView's grouped Form.

import SwiftUI
import AppKit

struct AppEntryView: View {
    @Binding var app: PPPCAppEntry
    let serviceType: PPPCServiceType

    // Per-field help popover state
    @State private var showIdentifierHelp              = false
    @State private var showIdentifierTypeHelp          = false
    @State private var showPermissionTypeHelp          = false
    @State private var showValueHelp                   = false
    @State private var showCodeRequirementHelp         = false
    @State private var showStaticCodeHelp              = false
    @State private var showCommentHelp                 = false
    @State private var showAEReceiverIdentifierHelp    = false
    @State private var showAEReceiverTypeHelp          = false
    @State private var showAEReceiverCodeReqHelp       = false

    var body: some View {

        // MARK: Identifier
        LabeledContent {
            TextField("", text: $app.identifier,
                      prompt: Text("com.example.app or /path/to/tool"))
        } label: {
            fieldLabel("Identifier", isPresented: $showIdentifierHelp) {
                Text("The app or tool requesting the privacy permission. Enter its CFBundleIdentifier (e.g., com.apple.Safari) or the absolute file system path to a command-line tool.\n\nUse \"Read from App Bundle…\" to populate this field automatically from a selected app or binary.")
                    .fixedSize(horizontal: false, vertical: true)
            }
        }

        // MARK: Identifier Type
        Picker(selection: $app.identifierType) {
            ForEach(IdentifierType.allCases, id: \.self) { type in
                Text(type.displayName).tag(type)
            }
        } label: {
            fieldLabel("Type", isPresented: $showIdentifierTypeHelp) {
                Text("How the app is identified in this policy entry.\n\n• Bundle ID — use for .app bundles. The identifier is the CFBundleIdentifier from the app's Info.plist.\n\n• Path — use for command-line tools or apps referenced by their absolute file system path.")
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .pickerStyle(.segmented)

        // MARK: Permission Type
        Picker(selection: $app.permissionType) {
            ForEach(PPPCPermissionType.allCases, id: \.self) { type in
                Text(type.displayName).tag(type)
            }
        } label: {
            fieldLabel("Permission", isPresented: $showPermissionTypeHelp) {
                Text("The permission key to use in the policy entry.\n\n• Allowed - a boolean key that simply grants or denies access.\n\n• Authorization - an enum key with additional options. Available values depend on the service type.")
                    .fixedSize(horizontal: false, vertical: true)
                Text("Every payload needs to include either Authorization or Allowed, but not both.")
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .pickerStyle(.segmented)

        // MARK: Permission Value
        // Available options are constrained per service type:
        //   Camera, Microphone              → Deny only
        //   Input Monitoring, Screen Recording → Deny | Allow Standard User
        //   All others                      → Allow | Deny
        if app.permissionType == .allowed {
            Picker(selection: $app.allowedValue) {
                if !serviceType.isDenyOnly {
                    Text("Allow").tag(true)
                }
                Text("Deny").tag(false)
            } label: {
                fieldLabel("Value", isPresented: $showValueHelp) {
                    Text("The access level to grant or deny.\n\n• Allow — grants the app access to this service.\n\n• Deny — blocks the app from accessing this service.\n\nNote: some service types only permit Deny.")
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .pickerStyle(.segmented)
        } else {
            Picker(selection: $app.authorizationValue) {
                ForEach(serviceType.allowedAuthorizationValues, id: \.self) { value in
                    Text(value.displayName).tag(value)
                }
            } label: {
                fieldLabel("Value", isPresented: $showValueHelp) {
                    Text("The access level to grant or deny.\n\n• Allow — grants the app access to this service.\n\n• Deny — blocks the app from accessing this service.\n\n• Allow Standard User to Set System Service — lets a standard (non-admin) user approve the app's access at runtime. Available for Input Monitoring and Screen Recording only.")
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.bottom, 2.5)
        }

        // MARK: Code Requirement
        LabeledContent("Code Requirement") {
            VStack(alignment: .leading, spacing: 6) {
                fieldLabel("Code Requirement", isPresented: $showCodeRequirementHelp) {
                    Text("The designated code requirement string used to cryptographically verify the app's identity before the policy is applied.\n\nUse \"Read from App Bundle…\" to populate this field automatically.")
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Or can be obtained via the command:")
                        .fixedSize(horizontal: false, vertical: true)
                    Text("codesign -display -r -\n /path/to/item")
                        .fixedSize(horizontal: false, vertical: true)
                        .fontDesign(.monospaced)

                }
                .font(.system(.body))

                TextEditor(text: $app.codeRequirement)
                    .font(.system(.body, design: .monospaced))
                    .frame(maxWidth: .infinity, minHeight: 68, maxHeight: 120)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
                    )
            }
            .frame(maxWidth: .infinity, alignment: .trailing)

            VStack(alignment: .trailing, spacing: 6) {
                Button("Read from App Bundle\u{2026}") {
                    readFromApp()
                }
                .buttonStyle(.bordered)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .labelsHidden()

        // MARK: Static Code
        Picker(selection: $app.staticCode) {
            ForEach(StaticCodeOption.allCases, id: \.self) { option in
                Text(option.rawValue).tag(option)
            }
        } label: {
            fieldLabel("Static Code", isPresented: $showStaticCodeHelp) {
                Text("Controls how code signing is verified when the policy is applied.\n\n• Not Set — omits this key from the policy, using the system default.\n\n• True — statically validate the code requirement. Used only if the process invalidates its dynamic code signature.\n\n• False — uses the default dynamic code signing validation.")
                    .fixedSize(horizontal: false, vertical: true)
            }
        }

        // MARK: Comment
        LabeledContent {
            TextField("", text: $app.comment, prompt: Text("Optional comment"))
        } label: {
            fieldLabel("Comment", isPresented: $showCommentHelp) {
                if serviceType.isBluetooth {
                    Text("The Comment field is displayed in the Intune console for Bluetooth entries.")
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text("Intune only displays the Comment field for Bluetooth entries.")
                        .fontWeight(.semibold)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("For other service types this field is written to the JSON file but ignored by Intune. Use it as a documentation note for your own reference.")
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }

        // MARK: Apple Events Receiver
        if serviceType.isAppleEvents {
            Section("Apple Events Receiver") {
                LabeledContent {
                    TextField("", text: $app.aeReceiverIdentifier,
                              prompt: Text("com.company.something"))
                } label: {
                    fieldLabel("Receiver Identifier", isPresented: $showAEReceiverIdentifierHelp) {
                        Text("The bundle identifier or path of the app that will receive Apple Events sent by the app identified above.")
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Picker(selection: $app.aeReceiverIdentifierType) {
                    ForEach(IdentifierType.allCases, id: \.self) { type in
                        Text(type.displayName).tag(type)
                    }
                } label: {
                    fieldLabel("Receiver Type", isPresented: $showAEReceiverTypeHelp) {
                        Text("How the Apple Events receiver app is identified — by Bundle ID or absolute file system path.")
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .pickerStyle(.segmented)

                LabeledContent("Receiver Code Requirement") {
                    VStack(alignment: .leading, spacing: 6) {
                        fieldLabel("Receiver Code Requirement",
                                   isPresented: $showAEReceiverCodeReqHelp) {
                            Text("The designated code requirement of the Apple Events receiver app, used to cryptographically verify its identity before allowing the event to be sent.")
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .font(.system(.body))

                        TextEditor(text: $app.aeReceiverCodeRequirement)
                            .font(.system(.body, design: .monospaced))
                            .frame(maxWidth: .infinity, minHeight: 68, maxHeight: 120)
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
                            )
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)

                    HStack(alignment: .center, spacing: 6) {
                        Menu("Common Receivers\u{2026}") {
                            ForEach(Self.commonAEReceivers, id: \.bundleID) { receiver in
                                Button(receiver.displayName) {
                                    applyCommonAEReceiver(receiver)
                                }
                            }
                        }
                        .fixedSize()
                        
                        Button("Read from App Bundle\u{2026}") {
                            readFromAEReceiver()
                        }
                        .buttonStyle(.bordered)

                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .labelsHidden()
            }
        }        
    }
    

    // MARK: - Common AE Receivers

    private struct CommonAEReceiver {
        let displayName: String
        let bundleID: String
        /// Fallback path used when NSWorkspace lookup fails (e.g. in a sandbox or
        /// during early boot). These system apps have had stable locations since macOS 10.
        let knownPath: String
    }

    private static let commonAEReceivers: [CommonAEReceiver] = [
        CommonAEReceiver(
            displayName: "Finder",
            bundleID:    "com.apple.finder",
            knownPath:   "/System/Library/CoreServices/Finder.app"
        ),
        CommonAEReceiver(
            displayName: "SystemUIServer",
            bundleID:    "com.apple.systemuiserver",
            knownPath:   "/System/Library/CoreServices/SystemUIServer.app"
        ),
        CommonAEReceiver(
            displayName: "System Events",
            bundleID:    "com.apple.systemevents",
            knownPath:   "/System/Library/CoreServices/System Events.app"
        ),
        CommonAEReceiver(
            displayName: "Terminal",
            bundleID:    "com.apple.Terminal",
            knownPath:   "/System/Applications/Utilities/Terminal.app"
        ),
    ]

    /// Looks up a common AE receiver app and populates all three receiver fields.
    private func applyCommonAEReceiver(_ receiver: CommonAEReceiver) {
        // Prefer the live NSWorkspace lookup; fall back to the known on-disk path.
        let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: receiver.bundleID)
               ?? URL(fileURLWithPath: receiver.knownPath)

        guard FileManager.default.fileExists(atPath: url.path) else { return }

        app.aeReceiverIdentifier     = receiver.bundleID
        app.aeReceiverIdentifierType = .bundleID
        if let codeReq = extractCodeRequirement(from: url.path) {
            app.aeReceiverCodeRequirement = codeReq
        }
    }

    // MARK: - Field Label Helper

    /// Renders a label with an ⓘ button that opens a popover containing helpContent.
    @ViewBuilder
    private func fieldLabel<Content: View>(
        _ title: String,
        isPresented: Binding<Bool>,
        @ViewBuilder helpContent: () -> Content
    ) -> some View {
        // Build the help view eagerly so the resulting value type (not the
        // non-escaping closure) is captured by the popover's escaping closure.
        let help = helpContent()
        HStack(spacing: 4) {
            Text(title)
            Button { isPresented.wrappedValue = true } label: {
                Image(systemName: "info.circle")
                    .foregroundStyle(.secondary)
                    .imageScale(.small)
            }
            .buttonStyle(.plain)
            .popover(isPresented: isPresented, arrowEdge: .trailing) {
                VStack(alignment: .leading, spacing: 8) {
                    help
                }
                .padding()
                .frame(width: 260)
            }
        }
    }

    // MARK: - Read from App Bundle

    /// Presents the open panel and returns the selected URL, or nil if cancelled.
    private func pickFile() -> URL? {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories    = false
        panel.canChooseFiles          = true
        panel.title   = "Select App Bundle or Command Line Tool"
        panel.message = "Select an .app bundle or command line tool to read its code signing information."
        guard panel.runModal() == .OK else { return nil }
        return panel.url
    }

    /// Reads the main app identifier + code requirement fields.
    private func readFromApp() {
        guard let url = pickFile() else { return }
        // Populate the main identifier fields
        if url.pathExtension.lowercased() == "app",
           let bundle = Bundle(url: url), let bundleID = bundle.bundleIdentifier {
            app.identifier     = bundleID
            app.identifierType = .bundleID
        } else {
            app.identifier     = url.path
            app.identifierType = .path
        }
        if let codeReq = extractCodeRequirement(from: url.path) {
            app.codeRequirement = codeReq
        }
    }

    /// Reads the Apple Events receiver identifier + code requirement fields.
    private func readFromAEReceiver() {
        guard let url = pickFile() else { return }
        // Populate the AE receiver identifier fields — does NOT touch the main identifier
        if url.pathExtension.lowercased() == "app",
           let bundle = Bundle(url: url), let bundleID = bundle.bundleIdentifier {
            app.aeReceiverIdentifier     = bundleID
            app.aeReceiverIdentifierType = .bundleID
        } else {
            app.aeReceiverIdentifier     = url.path
            app.aeReceiverIdentifierType = .path
        }
        if let codeReq = extractCodeRequirement(from: url.path) {
            app.aeReceiverCodeRequirement = codeReq
        }
    }
}

// MARK: - codesign Helper (module-level, no actor isolation)

/// Runs `codesign -dr - <path>` and extracts the designated requirement string.
/// Called synchronously after NSOpenPanel.runModal() returns (~100–300 ms).
func extractCodeRequirement(from path: String) -> String? {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
    process.arguments     = ["-dr", "-", path]

    // codesign writes the designated requirement to stdout
    let errorPipe  = Pipe()     // stderr discarded
    let outputPipe = Pipe()
    process.standardError  = errorPipe
    process.standardOutput = outputPipe

    do {
        try process.run()
        process.waitUntilExit()
    } catch {
        return nil
    }

    let data   = outputPipe.fileHandleForReading.readDataToEndOfFile()
    let output = String(data: data, encoding: .utf8) ?? ""

    for line in output.components(separatedBy: "\n") {
        if line.contains("designated =>") {
            let parts = line.components(separatedBy: "designated => ")
            if parts.count >= 2 {
                let req = parts.dropFirst()
                    .joined(separator: "designated => ")
                    .trimmingCharacters(in: .whitespaces)
                if !req.isEmpty { return req }
            }
        }
    }
    return nil
}
