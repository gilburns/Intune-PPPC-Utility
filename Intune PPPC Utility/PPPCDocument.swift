// PPPCDocument.swift
// Intune PPPC Utility
//
// FileDocument conformance — the Intune JSON file IS the document.
// Opening a file parses it; saving serializes back to the same format.

import SwiftUI
import UniformTypeIdentifiers

struct PPPCDocument: FileDocument {

    static var readableContentTypes: [UTType] { [.json] }
    static var writableContentTypes: [UTType] { [.json] }

    var profile: PPPCProfile

    // New blank document
    init(profile: PPPCProfile = .new()) {
        self.profile = profile
    }

    // Open an existing Intune JSON file
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        profile = try IntuneJSONParser.parse(data)
    }

    // Save — writes the Intune JSON format without BOM
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = try IntuneJSONGenerator.generate(profile)
        return FileWrapper(regularFileWithContents: data)
    }
}
