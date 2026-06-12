import AppKit
import os.log

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let log = Logger(subsystem: "com.arvindrao.SteamControllerBridgeMac", category: "app")
    private let controller = SteamControllerDevice()
    private let gamepad = VirtualGamepad()
    private var statusItem: StatusItemController!

    private var bridgeEnabled = false
    private var rawLogging = false
    private var connection: SteamControllerDevice.ConnectionState = .stopped
    private var gamepadError: String?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = StatusItemController()
        statusItem.onToggleBridge = { [weak self] in self?.toggleBridge() }
        statusItem.onToggleRawLogging = { [weak self] in self?.toggleRawLogging() }

        wirePipeline()

        if !PermissionsCoordinator.inputMonitoringGranted {
            PermissionsCoordinator.requestInputMonitoring()
        }
        refreshUI()
    }

    func applicationWillTerminate(_ notification: Notification) {
        if bridgeEnabled {
            controller.stop() // restores lizard mode synchronously
            gamepad.destroy()
        }
    }

    private func wirePipeline() {
        // Runs on the main thread (the controller is run-loop scheduled):
        // parse → map → forward only on change.
        let engine = MappingEngine()
        var lastSent: GamepadReport?
        controller.onInput = { [gamepad] state in
            let report = engine.map(state)
            if report != lastSent {
                lastSent = report
                gamepad.send(report)
            }
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
        controller.stop()
        gamepad.destroy()
        refreshUI()
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
            status += "\n⚠ \(gamepadError)"
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
