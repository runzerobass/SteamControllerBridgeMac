import AppKit

/// The menu bar item: bridge toggle, status line, debug raw-report logging,
/// permission shortcut, quit.
@MainActor
final class StatusItemController: NSObject, NSMenuDelegate {
    var onToggleBridge: (() -> Void)?
    var onToggleRawLogging: (() -> Void)?

    private let statusItem: NSStatusItem
    private let statusLine = NSMenuItem(title: "Starting…", action: nil, keyEquivalent: "")
    private let toggleItem = NSMenuItem(title: "Enable Bridge", action: #selector(toggleBridge), keyEquivalent: "")
    private let rawLogItem = NSMenuItem(title: "Log Raw Reports", action: #selector(toggleRawLogging), keyEquivalent: "")
    private let permissionItem = NSMenuItem(title: "Open Input Monitoring Settings…",
                                            action: #selector(openPermissionSettings), keyEquivalent: "")

    override init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        super.init()

        statusItem.button?.image = NSImage(systemSymbolName: "gamecontroller",
                                           accessibilityDescription: "Steam Controller Bridge")

        let menu = NSMenu()
        statusLine.isEnabled = false
        menu.addItem(statusLine)
        menu.addItem(.separator())
        toggleItem.target = self
        menu.addItem(toggleItem)
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
        statusItem.button?.image = NSImage(
            systemSymbolName: bridging ? "gamecontroller.fill" : "gamecontroller",
            accessibilityDescription: "Steam Controller Bridge")
    }

    @objc private func toggleBridge() {
        onToggleBridge?()
    }

    @objc private func toggleRawLogging() {
        onToggleRawLogging?()
    }

    @objc private func openPermissionSettings() {
        PermissionsCoordinator.openInputMonitoringSettings()
    }
}
