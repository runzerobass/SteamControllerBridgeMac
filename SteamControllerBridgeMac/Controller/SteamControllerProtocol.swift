import Foundation

/// Protocol constants for the 2026 Steam Controller / Steam Controller Puck.
/// Sources: SteamControllerBridge (Windows) SteamControllerReports.cs and the
/// HIDExplorer prototype, both verified against real hardware.
enum SteamControllerProtocol {
    static let vendorID = 0x28DE
    static let wiredProductID = 0x1302
    static let bluetoothProductID = 0x1303
    static let puckProductID = 0x1304
    static let productIDs = [wiredProductID, bluetoothProductID, puckProductID]

    static let stateReportID: UInt32 = 0x42
    static let stateBleReportID: UInt32 = 0x45
    static let minStateReportLength = 30
    static let imuStateReportLength = 46

    static let featureReportID: CFIndex = 0x01
    static let featureReportLength = 64

    /// Heartbeat interval for re-sending clearDigitalMappings while bridging.
    static let heartbeatInterval: TimeInterval = 0.8
    static let featureWriteAttempts = 5
    static let featureWriteRetryDelayMicroseconds: UInt32 = 2000

    /// Disables lizard mode (built-in keyboard/mouse digital mappings).
    static var clearDigitalMappings: [UInt8] {
        var report = [UInt8](repeating: 0, count: featureReportLength)
        report[0] = 0x01
        report[1] = 0x81
        return report
    }

    /// Companion command the HIDExplorer prototype sends after 0x81; kept for
    /// parity with the known-working init sequence on this hardware.
    static var clearMappingsCompanion: [UInt8] {
        var report = [UInt8](repeating: 0, count: featureReportLength)
        report[0] = 0x01
        report[1] = 0x8E
        return report
    }

    /// Sets trackpad modes and enables raw IMU (gyro + accel) output.
    /// Only needed once gyro features are in use.
    static var applySettings: [UInt8] {
        var report = [UInt8](repeating: 0, count: featureReportLength)
        report[0] = 0x01
        report[1] = 0x87
        report[2] = 0x09 // payload length
        report[3] = 0x08 // left trackpad mode
        report[6] = 0x07 // right trackpad mode
        report[9] = 0x30 // IMU mode
        report[10] = 0x18 // send raw accel (0x08) | send raw gyro (0x10)
        return report
    }

    /// Restores the controller's default mappings (lizard mode back on).
    static var restoreDefaultMappings: [UInt8] {
        var report = [UInt8](repeating: 0, count: featureReportLength)
        report[0] = 0x01
        report[1] = 0x85
        return report
    }

    /// Builds the 10-byte rumble output report.
    static func rumbleReport(intensity: UInt16, leftSpeed: UInt16, leftGain: Int8,
                             rightSpeed: UInt16, rightGain: Int8) -> [UInt8] {
        [
            0x80, 0x00,
            UInt8(intensity & 0xFF), UInt8(intensity >> 8),
            UInt8(leftSpeed & 0xFF), UInt8(leftSpeed >> 8),
            UInt8(bitPattern: leftGain),
            UInt8(rightSpeed & 0xFF), UInt8(rightSpeed >> 8),
            UInt8(bitPattern: rightGain),
        ]
    }
}

/// Button bitmask across state report bytes 2-5 (little-endian UInt32).
/// Verified on hardware by the HIDExplorer prototype.
struct SCButtons: OptionSet {
    let rawValue: UInt32

    static let btnA         = SCButtons(rawValue: 1 << 0)
    static let btnB         = SCButtons(rawValue: 1 << 1)
    static let btnX         = SCButtons(rawValue: 1 << 2)
    static let btnY         = SCButtons(rawValue: 1 << 3)
    static let btnQAM       = SCButtons(rawValue: 1 << 4)
    static let rStickClick  = SCButtons(rawValue: 1 << 5)
    static let btnStart     = SCButtons(rawValue: 1 << 6)
    static let btnR4        = SCButtons(rawValue: 1 << 7)
    static let btnR5        = SCButtons(rawValue: 1 << 8)
    static let btnRB        = SCButtons(rawValue: 1 << 9)
    static let dpadDown     = SCButtons(rawValue: 1 << 10)
    static let dpadRight    = SCButtons(rawValue: 1 << 11)
    static let dpadLeft     = SCButtons(rawValue: 1 << 12)
    static let dpadUp       = SCButtons(rawValue: 1 << 13)
    static let btnSelect    = SCButtons(rawValue: 1 << 14)
    static let lStickClick  = SCButtons(rawValue: 1 << 15)
    static let btnSteam     = SCButtons(rawValue: 1 << 16)
    static let btnL4        = SCButtons(rawValue: 1 << 17)
    static let btnL5        = SCButtons(rawValue: 1 << 18)
    static let btnLB        = SCButtons(rawValue: 1 << 19)
    static let rStickTouch  = SCButtons(rawValue: 1 << 20)
    static let rPadActive   = SCButtons(rawValue: 1 << 21)
    static let rPadClick    = SCButtons(rawValue: 1 << 22)
    static let rTrigFull    = SCButtons(rawValue: 1 << 23)
    static let lStickTouch  = SCButtons(rawValue: 1 << 24)
    static let lPadActive   = SCButtons(rawValue: 1 << 25)
    static let lPadClick    = SCButtons(rawValue: 1 << 26)
    /// Hardware-verified 2026-06-11: fires on a full left trigger pull
    /// (mirrors rTrigFull at bit 23; absent from both reference repos).
    static let lTrigFull    = SCButtons(rawValue: 1 << 27)
    static let rGrip        = SCButtons(rawValue: 1 << 28)
    static let lGrip        = SCButtons(rawValue: 1 << 29)
}
