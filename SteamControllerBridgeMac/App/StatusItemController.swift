import AppKit

/// The menu bar item: bridge toggle, status line, debug raw-report logging,
/// permission shortcut, quit.
@MainActor
final class StatusItemController: NSObject, NSMenuDelegate {
    var onToggleBridge: (() -> Void)?
    var onToggleRawLogging: (() -> Void)?
    var onOpenSettings: (() -> Void)?
    var onEditMappings: (() -> Void)?
    var onReloadMappings: (() -> Void)?

    private let statusItem: NSStatusItem
    private let statusLine = NSMenuItem(title: "Starting…", action: nil, keyEquivalent: "")
    private let toggleItem = NSMenuItem(title: "Enable Bridge", action: #selector(toggleBridge), keyEquivalent: "")
    private let rawLogItem = NSMenuItem(title: "Log Raw Reports", action: #selector(toggleRawLogging), keyEquivalent: "")
    private let permissionItem = NSMenuItem(title: "Open Input Monitoring Settings…",
                                            action: #selector(openPermissionSettings), keyEquivalent: "")

    override init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        super.init()

        statusItem.button?.image = Self.idleIcon

        let menu = NSMenu()
        statusLine.isEnabled = false
        menu.addItem(statusLine)
        menu.addItem(.separator())
        toggleItem.target = self
        menu.addItem(toggleItem)
        menu.addItem(.separator())
        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)
        let editItem = NSMenuItem(title: "Edit Mappings File…", action: #selector(editMappings), keyEquivalent: "")
        editItem.target = self
        menu.addItem(editItem)
        let reloadItem = NSMenuItem(title: "Reload Mappings", action: #selector(reloadMappings), keyEquivalent: "r")
        reloadItem.target = self
        menu.addItem(reloadItem)
        menu.addItem(.separator())
        rawLogItem.target = self
        menu.addItem(rawLogItem)
        permissionItem.target = self
        permissionItem.isHidden = true
        menu.addItem(permissionItem)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Steam Controller Bridge",
                                action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu
    }

    func update(statusText: String, bridging: Bool, bridgeEnabled: Bool,
                rawLogging: Bool, permissionNeeded: Bool) {
        statusLine.title = statusText
        toggleItem.title = bridgeEnabled ? "Disable Bridge" : "Enable Bridge"
        rawLogItem.state = rawLogging ? .on : .off
        permissionItem.isHidden = !permissionNeeded
        statusItem.button?.image = bridging ? Self.bridgingIcon : Self.idleIcon
    }

    /// The Steam Controller outline as a template image, so it follows the
    /// menu bar's light/dark appearance and highlight state.
    private static let idleIcon: NSImage = {
        if let icon = NSImage(named: "MenuBarIcon") {
            icon.isTemplate = true
            icon.size = NSSize(width: 18, height: 18)
            icon.accessibilityDescription = "Steam Controller Bridge"
            return icon
        }
        return NSImage(systemSymbolName: "gamecontroller",
                       accessibilityDescription: "Steam Controller Bridge")!
    }()

    /// The outline plus a green status dot. Color survives because this is
    /// not a template image; the outline is tinted with labelColor at draw
    /// time, which resolves against the menu bar's current appearance.
    private static let bridgingIcon: NSImage = {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { rect in
            idleIcon.draw(in: rect)
            NSColor.labelColor.set()
            rect.fill(using: .sourceAtop)

            let dot = NSRect(x: rect.maxX - 7, y: 0, width: 7, height: 7)
            NSColor.systemGreen.setFill()
            NSBezierPath(ovalIn: dot).fill()
            return true
        }
        image.accessibilityDescription = "Steam Controller Bridge (active)"
        return image
    }()

    @objc private func toggleBridge() {
        onToggleBridge?()
    }

    @objc private func toggleRawLogging() {
        onToggleRawLogging?()
    }

    @objc private func openSettings() {
        onOpenSettings?()
    }

    @objc private func editMappings() {
        onEditMappings?()
    }

    @objc private func reloadMappings() {
        onReloadMappings?()
    }

    @objc private func openPermissionSettings() {
        PermissionsCoordinator.openInputMonitoringSettings()
    }
}
