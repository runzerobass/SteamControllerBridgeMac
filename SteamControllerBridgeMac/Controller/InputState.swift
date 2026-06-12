import Foundation

/// A parsed Steam Controller state report.
struct InputState {
    var buttons: SCButtons = []
    /// Triggers scaled to 0...255.
    var leftTrigger: UInt8 = 0
    var rightTrigger: UInt8 = 0
    /// Sticks and pads in raw controller range (±32767).
    var leftStickX: Int16 = 0
    var leftStickY: Int16 = 0
    var rightStickX: Int16 = 0
    var rightStickY: Int16 = 0
    var leftPadX: Int16 = 0
    var leftPadY: Int16 = 0
    /// Touch pressure, 0...32767; ramps up over ~1s of contact.
    var leftPadPressure: Int16 = 0
    var rightPadX: Int16 = 0
    var rightPadY: Int16 = 0
    var rightPadPressure: Int16 = 0
    /// IMU values; only populated when the report carries them (length >= 46).
    var accelX: Int16 = 0
    var accelY: Int16 = 0
    var accelZ: Int16 = 0
    var gyroX: Int16 = 0
    var gyroY: Int16 = 0
    var gyroZ: Int16 = 0

    /// Byte offsets verified on hardware 2026-06-11 via raw-dump capture:
    /// pads are symmetric X/Y/pressure triples at 18-23 (left) and 24-29
    /// (right); position lands instantly on touch while pressure ramps.
    static func parse(reportID: UInt32, bytes: UnsafePointer<UInt8>, length: Int) -> InputState? {
        guard reportID == SteamControllerProtocol.stateReportID
                || reportID == SteamControllerProtocol.stateBleReportID else { return nil }
        guard length >= SteamControllerProtocol.minStateReportLength else { return nil }

        func i16(_ offset: Int) -> Int16 {
            Int16(bitPattern: UInt16(bytes[offset]) | UInt16(bytes[offset + 1]) << 8)
        }
        func trigger(_ offset: Int) -> UInt8 {
            UInt8(clamping: Int(i16(offset)) >> 7)
        }

        var state = InputState()
        state.buttons = SCButtons(rawValue:
            UInt32(bytes[2]) | UInt32(bytes[3]) << 8 |
            UInt32(bytes[4]) << 16 | UInt32(bytes[5]) << 24)
        state.leftTrigger = trigger(6)
        state.rightTrigger = trigger(8)
        state.leftStickX = i16(10)
        state.leftStickY = i16(12)
        state.rightStickX = i16(14)
        state.rightStickY = i16(16)
        state.leftPadX = i16(18)
        state.leftPadY = i16(20)
        state.leftPadPressure = i16(22)
        state.rightPadX = i16(24)
        state.rightPadY = i16(26)
        state.rightPadPressure = i16(28)

        if length >= SteamControllerProtocol.imuStateReportLength {
            state.accelX = i16(34)
            state.accelY = i16(36)
            state.accelZ = i16(38)
            state.gyroX = i16(40)
            state.gyroY = i16(42)
            state.gyroZ = i16(44)
        }
        return state
    }

    static func hexDump(reportID: UInt32, bytes: UnsafePointer<UInt8>, length: Int) -> String {
        let hex = (0..<length).map { String(format: "%02X", bytes[$0]) }.joined(separator: " ")
        return String(format: "[%02X len=%d] %@", reportID, length, hex)
    }
}
