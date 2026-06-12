import Foundation

/// The virtual pad's HID report descriptor and input report packing.
///
/// Input report ID 1 (13-byte payload): 16 buttons, dpad hat, four 16-bit
/// stick axes (X/Y/Z/Rz), two 8-bit trigger axes (Rx/Ry).
/// Output report ID 2: 8 vendor bytes, reserved as a future rumble channel.
enum GamepadDescriptor {
    /// Generic (community pool) VID/PID, deliberately not a known Xbox/PS pair:
    /// SDL skips its IOKit backend for recognized vendor IDs, assuming
    /// GameController.framework handles them — which ignores virtual devices.
    static let vendorID = 0x1209
    static let productID = 0x5C20
    static let productName = "Steam Controller Bridge Pad"

    static let inputReportID: UInt8 = 1
    static let outputReportID: UInt8 = 2

    static let descriptor: [UInt8] = [
        0x05, 0x01,        // Usage Page (Generic Desktop)
        0x09, 0x05,        // Usage (Game Pad)
        0xA1, 0x01,        // Collection (Application)
        0x85, 0x01,        //   Report ID (1)
        0x05, 0x09,        //   Usage Page (Button)
        0x19, 0x01,        //   Usage Minimum (1)
        0x29, 0x10,        //   Usage Maximum (16)
        0x15, 0x00,        //   Logical Minimum (0)
        0x25, 0x01,        //   Logical Maximum (1)
        0x75, 0x01,        //   Report Size (1)
        0x95, 0x10,        //   Report Count (16)
        0x81, 0x02,        //   Input (Data,Var,Abs)
        0x05, 0x01,        //   Usage Page (Generic Desktop)
        0x09, 0x39,        //   Usage (Hat Switch)
        0x15, 0x00,        //   Logical Minimum (0)
        0x25, 0x07,        //   Logical Maximum (7)
        0x35, 0x00,        //   Physical Minimum (0)
        0x46, 0x3B, 0x01,  //   Physical Maximum (315)
        0x65, 0x14,        //   Unit (Degrees)
        0x75, 0x04,        //   Report Size (4)
        0x95, 0x01,        //   Report Count (1)
        0x81, 0x42,        //   Input (Data,Var,Abs,Null State)
        0x65, 0x00,        //   Unit (None)
        0x75, 0x04,        //   Report Size (4)
        0x95, 0x01,        //   Report Count (1)
        0x81, 0x03,        //   Input (Const) — pad to byte boundary
        0x09, 0x30,        //   Usage (X)
        0x09, 0x31,        //   Usage (Y)
        0x09, 0x32,        //   Usage (Z)
        0x09, 0x35,        //   Usage (Rz)
        0x16, 0x00, 0x80,  //   Logical Minimum (-32768)
        0x26, 0xFF, 0x7F,  //   Logical Maximum (32767)
        0x75, 0x10,        //   Report Size (16)
        0x95, 0x04,        //   Report Count (4)
        0x81, 0x02,        //   Input (Data,Var,Abs)
        0x09, 0x33,        //   Usage (Rx)
        0x09, 0x34,        //   Usage (Ry)
        0x15, 0x00,        //   Logical Minimum (0)
        0x26, 0xFF, 0x00,  //   Logical Maximum (255)
        0x75, 0x08,        //   Report Size (8)
        0x95, 0x02,        //   Report Count (2)
        0x81, 0x02,        //   Input (Data,Var,Abs)
        0x85, 0x02,        //   Report ID (2)
        0x06, 0x00, 0xFF,  //   Usage Page (Vendor Defined)
        0x09, 0x01,        //   Usage (1)
        0x15, 0x00,        //   Logical Minimum (0)
        0x26, 0xFF, 0x00,  //   Logical Maximum (255)
        0x75, 0x08,        //   Report Size (8)
        0x95, 0x08,        //   Report Count (8)
        0x91, 0x02,        //   Output (Data,Var,Abs)
        0xC0,              // End Collection
    ]
}

/// One frame of virtual gamepad state.
struct GamepadReport: Equatable {
    struct Buttons: OptionSet, Equatable {
        let rawValue: UInt16
        static let a           = Buttons(rawValue: 1 << 0)
        static let b           = Buttons(rawValue: 1 << 1)
        static let x           = Buttons(rawValue: 1 << 2)
        static let y           = Buttons(rawValue: 1 << 3)
        static let leftBumper  = Buttons(rawValue: 1 << 4)
        static let rightBumper = Buttons(rawValue: 1 << 5)
        static let back        = Buttons(rawValue: 1 << 6)
        static let start       = Buttons(rawValue: 1 << 7)
        static let guide       = Buttons(rawValue: 1 << 8)
        static let leftThumb   = Buttons(rawValue: 1 << 9)
        static let rightThumb  = Buttons(rawValue: 1 << 10)
    }

    var buttons: Buttons = []
    /// 0-7 clockwise from north; nil = centered.
    var hat: UInt8?
    var leftStickX: Int16 = 0
    var leftStickY: Int16 = 0
    var rightStickX: Int16 = 0
    var rightStickY: Int16 = 0
    var leftTrigger: UInt8 = 0
    var rightTrigger: UInt8 = 0

    /// Packs the 14-byte HID input report (report ID + 13-byte payload).
    func packed() -> [UInt8] {
        func le(_ value: Int16) -> [UInt8] {
            let bits = UInt16(bitPattern: value)
            return [UInt8(bits & 0xFF), UInt8(bits >> 8)]
        }
        return [GamepadDescriptor.inputReportID,
                UInt8(buttons.rawValue & 0xFF), UInt8(buttons.rawValue >> 8),
                hat ?? 0x0F]
            + le(leftStickX) + le(leftStickY)
            + le(rightStickX) + le(rightStickY)
            + [leftTrigger, rightTrigger]
    }
}
