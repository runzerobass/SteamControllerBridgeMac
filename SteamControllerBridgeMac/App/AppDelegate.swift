import AppKit
import SwiftUI
import os.log

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let log = Logger(subsystem: "com.arvindrao.SteamControllerBridgeMac", category: "app")
    private let controller = SteamControllerDevice()
    private let gamepad = VirtualGamepad()
    private let engine = MappingEngine(profile: ProfileStore.load())
    private let keyboardMouse = KeyboardMouseOutput()
    private var statusItem: StatusItemController!
    private var settingsWindow: NSWindow?

    private var bridgeEnabled = false
    private var rawLogging = false
    private var connection: SteamControllerDevice.ConnectionState = .stopped
    private var gamepadError: String?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = StatusItemController()
        statusItem.onToggleBridge = { [weak self] in self?.toggleBridge() }
        statusItem.onToggleRawLogging = { [weak self] in self?.toggleRawLogging() }
        statusItem.onOpenSettings = { [weak self] in self?.openSettings() }
        statusItem.onEditMappings = {
            ProfileStore.writeDefaultIfMissing()
            NSWorkspace.shared.open(ProfileStore.url)
        }
        statusItem.onReloadMappings = { [weak self] in
            guard let self else { return }
            keyboardMouse.releaseAll() // old bindings may hold keys
            engine.apply(ProfileStore.load())
            promptAccessibilityIfNeeded()
            refreshUI()
        }

        wirePipeline()

        if !PermissionsCoordinator.inputMonitoringGranted {
            PermissionsCoordinator.requestInputMonitoring()
        }
        refreshUI()
    }

    func applicationWillTerminate(_ notification: Notification) {
        if bridgeEnabled {
            keyboardMouse.releaseAll()
            controller.stop() // restores lizard mode synchronously
            gamepad.destroy()
        }
    }

    private func wirePipeline() {
        // Runs on the main thread (the controller is run-loop scheduled):
        // parse → map → forward only on change.
        var lastSent: GamepadReport?
        controller.onInput = { [gamepad, engine, keyboardMouse] state in
            let output = engine.map(state)
            if output.report != lastSent {
                lastSent = output.report
                gamepad.send(output.report)
            }
            keyboardMouse.apply(keys: output.keys, mouseButtons: output.mouseButtons)
            keyboardMouse.moveMouse(dx: output.mouseDX, dy: output.mouseDY)
        }
        controller.onStateChange = { [weak self] state in
            self?.connection = state
            self?.refreshUI()
        }
    }

    private func toggleBridge() {
        bridgeEnabled ? disableBridge() : enableBridge()
    }

    private func enableBridge() {
        bridgeEnabled = true
        gamepadError = nil
        promptAccessibilityIfNeeded()
        Task { @MainActor in
            do {
                try await gamepad.create()
            } catch {
                // Keep reading the controller anyway: raw logging and the
                // future keyboard/mouse backend don't need the virtual pad.
                gamepadError = error.localizedDescription
                log.error("\(error.localizedDescription, privacy: .public)")
            }
            controller.start()
            refreshUI()
        }
        refreshUI()
    }

    private func disableBridge() {
        bridgeEnabled = false
        keyboardMouse.releaseAll()
        controller.stop()
        gamepad.destroy()
        refreshUI()
    }

    private func openSettings() {
        // Rebuild each open so the editor always reflects the saved file.
        let view = SettingsView(profile: ProfileStore.load()) { [weak self] profile in
            self?.saveProfile(profile)
        }
        let window = settingsWindow ?? {
            let window = NSWindow(contentRect: .zero,
                                  styleMask: [.titled, .closable, .miniaturizable],
                                  backing: .buffered, defer: false)
            window.title = "Steam Controller Bridge Settings"
            window.isReleasedWhenClosed = false
            settingsWindow = window
            return window
        }()
        window.contentViewController = NSHostingController(rootView: view)
        NSApp.activate(ignoringOtherApps: true)
        window.center()
        window.makeKeyAndOrderFront(nil)
    }

    private func saveProfile(_ profile: Profile) {
        do {
            try ProfileStore.save(profile)
        } catch {
            log.error("Saving profile failed: \(error.localizedDescription, privacy: .public)")
        }
        keyboardMouse.releaseAll() // old bindings may hold keys
        engine.apply(profile)
        promptAccessibilityIfNeeded()
        refreshUI()
    }

    /// Kb/m bindings need the Accessibility permission; only prompt when the
    /// profile actually uses them.
    private func promptAccessibilityIfNeeded() {
        if engine.usesKeyboardMouse && !PermissionsCoordinator.accessibilityGranted {
            PermissionsCoordinator.requestAccessibility()
        }
    }

    private func toggleRawLogging() {
        rawLogging.toggle()
        controller.logRawReports = rawLogging
        refreshUI()
    }

    private func refreshUI() {
        let permissionNeeded = connection == .permissionDenied
            || (!bridgeEnabled && !PermissionsCoordinator.inputMonitoringGranted)

        var status: String
        if !bridgeEnabled {
            status = "Bridge off"
        } else {
            switch connection {
            case .stopped, .searching:
                status = "Searching for Steam Controller…"
            case .connected(let name):
                status = gamepad.isActive ? "Bridging: \(name)" : "Connected: \(name) (no virtual pad)"
            case .permissionDenied:
                status = "Input Monitoring permission needed"
            }
        }
        if let gamepadError {
            status += " — ⚠ \(gamepadError)"
        }
        if engine.usesKeyboardMouse && !PermissionsCoordinator.accessibilityGranted {
            status += " — ⚠ kb/m bindings need Accessibility permission"
        }

        let bridging = bridgeEnabled && gamepad.isActive && connection.isConnected
        statusItem.update(statusText: status,
                          bridging: bridging,
                          bridgeEnabled: bridgeEnabled,
                          rawLogging: rawLogging,
                          permissionNeeded: permissionNeeded)
    }
}

private extension SteamControllerDevice.ConnectionState {
    var isConnected: Bool {
        if case .connected = self { return true }
        return false
    }
}
