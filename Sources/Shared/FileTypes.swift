import AppKit
import UniformTypeIdentifiers

struct FileType: Codable, Hashable, Identifiable {
    var id = UUID()
    var name: String
    var ext: String
    var defaultName: String

    enum CodingKeys: String, CodingKey { case name, ext, defaultName }
}

/// Shared by the app (writes settings) and the Finder extension (reads settings, creates files).
enum FileTypes {
    /// Localized once per process; saved settings keep whatever language they were saved in.
    static let defaults = [
        FileType(name: NSLocalizedString("Text file", comment: ""), ext: "txt", defaultName: NSLocalizedString("Text document", comment: "")),
        FileType(name: NSLocalizedString("Markdown", comment: ""), ext: "md", defaultName: NSLocalizedString("Markdown document", comment: "")),
        FileType(name: NSLocalizedString("Word document", comment: ""), ext: "doc", defaultName: NSLocalizedString("Word document", comment: "")),
        FileType(name: NSLocalizedString("Excel spreadsheet", comment: ""), ext: "xlsx", defaultName: NSLocalizedString("Spreadsheet", comment: "")),
        FileType(name: NSLocalizedString("PowerPoint presentation", comment: ""), ext: "pptx", defaultName: NSLocalizedString("Presentation", comment: "")),
    ]

    /// Real home folder: inside the sandboxed extension NSHomeDirectory() points at its container.
    static let supportDir = URL(fileURLWithPath: String(cString: getpwuid(getuid())!.pointee.pw_dir))
        .appendingPathComponent("Library/Application Support/CreateNew")
    static let configURL = supportDir.appendingPathComponent("types.json")

    /// User templates override the bundled ones, like Windows' ShellNew.
    static var templateDirs: [URL] {
        [supportDir.appendingPathComponent("Templates"),
         Bundle.main.url(forResource: "Templates", withExtension: nil)].compactMap { $0 }
    }

    static func load(from url: URL = configURL) -> [FileType] {
        guard let data = try? Data(contentsOf: url),
              let types = try? JSONDecoder().decode([FileType].self, from: data) else { return defaults }
        return types.compactMap(sanitized)
    }

    static func save(_ types: [FileType], to url: URL = configURL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        try encoder.encode(types.compactMap(sanitized)).write(to: url, options: .atomic)
    }

    /// Makes a type safe to use in a file path; nil if a required field is empty.
    static func sanitized(_ type: FileType) -> FileType? {
        func clean(_ s: String) -> String {
            s.trimmingCharacters(in: .whitespaces)
                .replacingOccurrences(of: "/", with: "-")
                .replacingOccurrences(of: ":", with: "-")
        }
        var t = type
        t.name = t.name.trimmingCharacters(in: .whitespaces)
        t.defaultName = clean(t.defaultName)
        t.ext = clean(t.ext).trimmingCharacters(in: CharacterSet(charactersIn: "."))
        return t.name.isEmpty || t.ext.isEmpty || t.defaultName.isEmpty ? nil : t
    }

    /// "Name.ext", or "Name (2).ext", "Name (3).ext"… for the first free number.
    static func uniqueURL(in dir: URL, base: String, ext: String) -> URL {
        var url = dir.appendingPathComponent("\(base).\(ext)")
        var n = 2
        while FileManager.default.fileExists(atPath: url.path) {
            url = dir.appendingPathComponent("\(base) (\(n)).\(ext)")
            n += 1
        }
        return url
    }

    @discardableResult
    static func create(_ type: FileType, in dir: URL, templateDirs: [URL] = FileTypes.templateDirs) throws -> URL {
        let url = uniqueURL(in: dir, base: type.defaultName, ext: type.ext)
        let template = templateDirs.map { $0.appendingPathComponent("template.\(type.ext)") }
            .first { FileManager.default.fileExists(atPath: $0.path) }
        // Copy bytes, not the file, so the new file gets fresh dates and no quarantine flag.
        let data = try template.map { try Data(contentsOf: $0) } ?? Data()
        try data.write(to: url, options: .withoutOverwriting)
        return url
    }

    static func icon(for ext: String) -> NSImage {
        let icon = NSWorkspace.shared.icon(for: UTType(filenameExtension: ext) ?? .data).copy() as! NSImage
        icon.size = NSSize(width: 16, height: 16)
        return icon
    }
}
