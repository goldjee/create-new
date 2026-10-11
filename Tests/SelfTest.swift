import Foundation

@main
struct SelfTest {
    static func main() throws {
        let fm = FileManager.default
        let dir = fm.temporaryDirectory.appendingPathComponent("CreateNewTest-\(UUID().uuidString)")
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: dir) }

        // (N) suffixing, including reuse of a freed number.
        let txt = FileTypes.defaults[0]
        let names = try (1...3).map { _ in try FileTypes.create(txt, in: dir, templateDirs: []).lastPathComponent }
        check(names == ["Text document.txt", "Text document (2).txt", "Text document (3).txt"], "suffixes: \(names)")
        try fm.removeItem(at: dir.appendingPathComponent("Text document (2).txt"))
        check(try FileTypes.create(txt, in: dir, templateDirs: []).lastPathComponent == "Text document (2).txt", "gap reuse")

        // Templates: first matching dir wins, otherwise empty.
        let templates = dir.appendingPathComponent("templates")
        try fm.createDirectory(at: templates, withIntermediateDirectories: true)
        try Data("hello".utf8).write(to: templates.appendingPathComponent("template.md"))
        let md = try FileTypes.create(FileTypes.defaults[1], in: dir, templateDirs: [templates])
        check(try Data(contentsOf: md) == Data("hello".utf8), "template copied")
        check(try Data(contentsOf: dir.appendingPathComponent("Text document.txt")).isEmpty, "empty file")

        // Config round-trip, sanitizing and fallback.
        let config = dir.appendingPathComponent("types.json")
        check(FileTypes.load(from: config) == FileTypes.defaults, "missing config -> defaults")
        try FileTypes.save([FileType(name: " Log ", ext: ".log", defaultName: "a/b:c"),
                            FileType(name: "Bad", ext: "", defaultName: "x")], to: config)
        let loaded = FileTypes.load(from: config)
        check(loaded.map { [$0.name, $0.ext, $0.defaultName] } == [["Log", "log", "a-b-c"]], "sanitize: \(loaded)")
        try Data("garbage".utf8).write(to: config)
        check(FileTypes.load(from: config) == FileTypes.defaults, "corrupt config -> defaults")

        // Every language has the same keys and the same format placeholders.
        func table(_ lang: String) -> [String: String] {
            NSDictionary(contentsOfFile: "Resources/\(lang).lproj/Localizable.strings") as? [String: String] ?? [:]
        }
        let en = table("en"), ru = table("ru")
        check(!en.isEmpty && Set(en.keys) == Set(ru.keys), "en/ru keys differ: \(Set(en.keys).symmetricDifference(ru.keys))")
        for (key, value) in ru where key.components(separatedBy: "%@").count != value.components(separatedBy: "%@").count {
            check(false, "placeholder mismatch in ru: \(key)")
        }

        // Update version comparison and release parsing.
        check(Updates.isNewer("v1.1.0", than: "1.0.0"), "1.1.0 > 1.0.0")
        check(Updates.isNewer("1.10.0", than: "1.9.9"), "1.10.0 > 1.9.9")
        check(!Updates.isNewer("1.0", than: "1.0.0") && !Updates.isNewer("1.0.0", than: "1.0"), "1.0 == 1.0.0")
        check(!Updates.isNewer("v0.9.0", than: "1.0.0"), "older is not newer")
        let json = #"{"tag_name":"v1.2.0","html_url":"https://github.com/goldjee/create-new/releases/tag/v1.2.0","#
            + #""assets":[{"name":"CreateNew.dmg","browser_download_url":"https://example.com/CreateNew.dmg"}]}"#
        let release = try JSONDecoder().decode(Release.self, from: Data(json.utf8))
        check(release.version == "1.2.0" && release.assets.first?.name == "CreateNew.dmg", "release decoding")

        // Auto-update setting: unanswered until saved, nil again if the file is corrupt.
        let updates = dir.appendingPathComponent("updates.json")
        check(Updates.autoCheck(from: updates) == nil, "unanswered -> nil")
        try Updates.setAutoCheck(true, to: updates)
        check(Updates.autoCheck(from: updates) == true, "saved true")
        try Updates.setAutoCheck(false, to: updates)
        check(Updates.autoCheck(from: updates) == false, "saved false")
        try Data("garbage".utf8).write(to: updates)
        check(Updates.autoCheck(from: updates) == nil, "corrupt -> nil")

        print("selftest: all checks passed")
    }

    static func check(_ ok: Bool, _ what: String) {
        if !ok { print("selftest FAILED: \(what)"); exit(1) }
    }
}
