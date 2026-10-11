import AppKit

/// Offers a newer GitHub release and installs it over the running app.
enum Updater {
    struct Failure: LocalizedError { let errorDescription: String? }

    @MainActor
    static func checkAndOffer() async {
        guard let release = try? await Updates.latest(),
              Updates.isNewer(release.version, than: Updates.currentVersion) else { return }

        let alert = NSAlert()
        alert.messageText = String(format: NSLocalizedString("Create New %@ is available", comment: ""), release.version)
        alert.informativeText = String(format: NSLocalizedString("You have version %@. Update now?", comment: ""),
                                       Updates.currentVersion)
        alert.addButton(withTitle: NSLocalizedString("Update", comment: ""))
        alert.addButton(withTitle: NSLocalizedString("Later", comment: ""))
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        do {
            try await install(release)
        } catch {
            let alert = NSAlert(error: error)
            alert.messageText = NSLocalizedString("The update couldn't be installed", comment: "")
            alert.runModal()
        }
    }

    @MainActor
    static func install(_ release: Release) async throws {
        let fm = FileManager.default
        let app = Bundle.main.bundleURL
        let folder = app.deletingLastPathComponent()
        // A copy running from the DMG or translocated by Gatekeeper can't be replaced: send the user to the download page.
        guard fm.isWritableFile(atPath: folder.path), !app.path.contains("/AppTranslocation/"),
              let asset = release.assets.first(where: { $0.name.hasSuffix(".dmg") }) else {
            NSWorkspace.shared.open(release.page)
            return
        }

        let work = fm.temporaryDirectory.appendingPathComponent("CreateNewUpdate-\(UUID().uuidString)")
        let mount = work.appendingPathComponent("mnt")
        try fm.createDirectory(at: mount, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: work) }

        let (dmg, _) = try await URLSession.shared.download(from: asset.url)
        defer { try? fm.removeItem(at: dmg) }
        // ponytail: hdiutil/ditto block the main thread for about a second; move off-main if the DMG grows large.
        try run("/usr/bin/hdiutil", "attach", "-nobrowse", "-readonly", "-noautoopen", "-mountpoint", mount.path, dmg.path)
        defer { try? run("/usr/bin/hdiutil", "detach", mount.path, "-force") }

        // The download is untrusted until it proves to be our app at the advertised version.
        guard let newApp = try fm.contentsOfDirectory(at: mount, includingPropertiesForKeys: nil)
                .first(where: { $0.pathExtension == "app" }),
              let bundle = Bundle(url: newApp),
              bundle.bundleIdentifier == Bundle.main.bundleIdentifier,
              bundle.infoDictionary?["CFBundleShortVersionString"] as? String == release.version else {
            throw Failure(errorDescription: NSLocalizedString("The downloaded update isn't valid.", comment: ""))
        }
        try run("/usr/bin/codesign", "--verify", "--deep", "--strict", newApp.path)

        // Stage next to the app so the swap stays on one volume and is atomic.
        let staged = folder.appendingPathComponent(".\(app.lastPathComponent).update")
        try? fm.removeItem(at: staged)
        defer { try? fm.removeItem(at: staged) }
        try run("/usr/bin/ditto", newApp.path, staged.path)
        _ = try fm.replaceItemAt(app, withItemAt: staged)

        // Finder starts the extension again from the new copy.
        try? run("/usr/bin/pkill", "-x", "CreateNewExtension")
        let relaunch = NSWorkspace.OpenConfiguration()
        relaunch.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: app, configuration: relaunch) { _, _ in
            DispatchQueue.main.async { NSApp.terminate(nil) }
        }
    }

    private static func run(_ tool: String, _ arguments: String...) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: tool)
        process.arguments = arguments
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw Failure(errorDescription: "\((tool as NSString).lastPathComponent) failed (\(process.terminationStatus))")
        }
    }
}
