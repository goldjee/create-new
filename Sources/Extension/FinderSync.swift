import Cocoa
import FinderSync

class FinderSync: FIFinderSync {
    override init() {
        super.init()
        FIFinderSyncController.default().directoryURLs = [URL(fileURLWithPath: "/")]
    }

    override func menu(for menuKind: FIMenuKind) -> NSMenu? {
        guard menuKind == .contextualMenuForContainer || menuKind == .contextualMenuForItems else { return nil }
        let types = FileTypes.load()
        guard !types.isEmpty else { return nil }

        let submenu = NSMenu()
        for (index, type) in types.enumerated() {
            // Finder copies menu items, so only the tag survives to the action.
            let item = NSMenuItem(title: type.name, action: #selector(createFile(_:)), keyEquivalent: "")
            item.tag = index
            item.image = FileTypes.icon(for: type.ext)
            submenu.addItem(item)
        }
        let menu = NSMenu()
        let root = menu.addItem(withTitle: NSLocalizedString("Create New…", comment: "Finder submenu"), action: nil, keyEquivalent: "")
        menu.setSubmenu(submenu, for: root)
        return menu
    }

    @objc func createFile(_ sender: NSMenuItem) {
        let types = FileTypes.load()
        guard types.indices.contains(sender.tag),
              let dir = FIFinderSyncController.default().targetedURL() else { return }
        do {
            try FileTypes.create(types[sender.tag], in: dir)
        } catch {
            let alert = NSAlert(error: error)
            alert.messageText = String(format: NSLocalizedString("Couldn't create %@", comment: ""), types[sender.tag].name)
            alert.runModal()
        }
    }
}
