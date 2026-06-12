import AppKit
import IOKit.hid

/// Input Monitoring (TCC "ListenEvent") permission handling. Reading the
/// Steam Controller's raw HID reports requires this permission; denial shows
/// up as kIOReturnNotPermitted (0xE00002E2) from IOHIDManagerOpen.
enum PermissionsCoordinator {
    static var inputMonitoringGranted: Bool {
        IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) == kIOHIDAccessTypeGranted
    }

    /// Triggers the system permission prompt (first time only).
    @discardableResult
    static func requestInputMonitoring() -> Bool {
        IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
    }

    static func openInputMonitoringSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent")!
        NSWorkspace.shared.open(url)
    }

    // MARK: - Accessibility (required to post keyboard/mouse events)

    static var accessibilityGranted: Bool {
        AXIsProcessTrusted()
    }

    /// Triggers the system Accessibility prompt (first time only).
    static func requestAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }
}
