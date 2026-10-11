import SwiftUI
import FinderSync

@main
struct CreateNewApp: App {
    @NSApplicationDelegateAdaptor private var delegate: AppDelegate

    var body: some Scene {
        Window("Create New", id: "settings") { SettingsView() }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        Task { await Updater.checkAndOffer() }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

struct SettingsView: View {
    @State private var types = FileTypes.load()
    @State private var selection: FileType.ID?
    @State private var enabled = FIFinderSyncController.isExtensionEnabled
    @State private var saveError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Table($types, selection: $selection) {
                TableColumn("") { $type in Image(nsImage: FileTypes.icon(for: type.ext)) }.width(20)
                TableColumn("Menu title") { $type in TextField("Menu title", text: $type.name) }
                TableColumn("Extension") { $type in TextField("ext", text: $type.ext) }.width(80)
                TableColumn("Default file name") { $type in TextField("File name", text: $type.defaultName) }
            }
            HStack {
                Button { types.append(FileType(name: NSLocalizedString("New type", comment: ""), ext: "txt",
                                         defaultName: NSLocalizedString("New file", comment: ""))) } label: {
                    Image(systemName: "plus").frame(width: 14, height: 14)
                }.help("Add a file type")
                Button { types.removeAll { $0.id == selection } } label: {
                    Image(systemName: "minus").frame(width: 14, height: 14)
                }.help("Remove the selected file type").disabled(selection == nil)
                Button("Reset to Defaults") { types = FileTypes.defaults }
                Button("Templates Folder…", action: openTemplates)
                    .help("Put template.<ext> files here to use them instead of empty files")
                Spacer()
            }
            if let saveError { Text(saveError).foregroundStyle(.red) }
            Divider()
            HStack {
                Image(systemName: enabled ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundStyle(enabled ? .green : .orange)
                enabled ? Text("Finder extension is enabled.") : Text("Finder extension is disabled.")
                Spacer()
                // A ternary yields a plain String, which SwiftUI would show untranslated.
                Button(LocalizedStringKey(enabled ? "Extension Settings…" : "Enable Finder Extension"), action: enableExtension)
            }
        }
        .padding()
        .frame(minWidth: 620, minHeight: 320)
        .onChange(of: types) { _ in
            do { try FileTypes.save(types); saveError = nil } catch { saveError = error.localizedDescription }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            enabled = FIFinderSyncController.isExtensionEnabled
        }
    }

    private func enableExtension() {
        if !enabled, let id = Bundle.main.bundleIdentifier {
            let pluginkit = Process()
            pluginkit.executableURL = URL(fileURLWithPath: "/usr/bin/pluginkit")
            pluginkit.arguments = ["-e", "use", "-i", id + ".FinderExtension"]
            try? pluginkit.run()
            pluginkit.waitUntilExit()
            enabled = FIFinderSyncController.isExtensionEnabled
            if enabled { return }
        }
        FIFinderSyncController.showExtensionManagementInterface()
    }

    private func openTemplates() {
        let dir = FileTypes.supportDir.appendingPathComponent("Templates")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        NSWorkspace.shared.open(dir)
    }
}
