import Foundation

/// Translates parsed controller state into virtual gamepad reports.
///
/// Stateful because gyro aiming needs drift-bias tracking across reports.
/// Layout: the Windows app's defaults, plus trackpads-as-sticks and
/// gyro-to-right-stick while the left trigger is held. Tuning values are
/// ports of the Windows app's battle-tested constants
/// (XboxVirtualController.cs / GyroMouseEmulator.cs).
final class MappingEngine {
    struct Tuning {
        /// Trackpad deflection below this is ignored (raw units, 0-8000).
        var padStickDeadZone: Int = 800
        /// Trackpad-to-stick scaling percent.
        var padStickSensitivity: Int = 100
        /// Left-trigger value (0-255) that turns gyro aiming on.
        var gyroActivationThreshold: UInt8 = 64
        /// Raw gyro rotation below this is ignored (drift floor).
        var gyroDeadZone: Int = 45
        /// Raw gyro units → stick deflection multiplier (1-80).
        var gyroSensitivity: Int = 26
        /// Bias learning weights: fast on activation, slow while inactive.
        var gyroBiasFastWeight: Double = 0.65
        var gyroBiasSlowWeight: Double = 0.04
    }

    var tuning = Tuning()

    private var gyroBiasYaw = 0.0
    private var gyroBiasPitch = 0.0
    private var gyroWasActive = false

    func map(_ input: InputState) -> GamepadReport {
        var report = GamepadReport()
        report.buttons = mapButtons(input.buttons)
        report.hat = hatValue(up: input.buttons.contains(.dpadUp),
                              down: input.buttons.contains(.dpadDown),
                              left: input.buttons.contains(.dpadLeft),
                              right: input.buttons.contains(.dpadRight))
        report.leftTrigger = input.leftTrigger
        report.rightTrigger = input.rightTrigger

        // Axes are computed in controller space (Y up-positive) and flipped
        // to the HID convention (Y down-positive) at the end.
        var leftX = Int(input.leftStickX)
        var leftY = Int(input.leftStickY)
        var rightX = Int(input.rightStickX)
        var rightY = Int(input.rightStickY)

        // Trackpads drive their stick while touched.
        if input.buttons.contains(.lPadActive) {
            (leftX, leftY) = padAsStick(x: input.leftPadX, y: input.leftPadY)
        }
        if input.buttons.contains(.rPadActive) {
            (rightX, rightY) = padAsStick(x: input.rightPadX, y: input.rightPadY)
        }

        // Gyro aiming blends into the right stick while L2 is held.
        let (gyroX, gyroY) = gyroDelta(input)
        rightX += gyroX
        rightY += gyroY

        report.leftStickX = clampAxis(leftX)
        report.leftStickY = flipY(clampAxis(leftY))
        report.rightStickX = clampAxis(rightX)
        report.rightStickY = flipY(clampAxis(rightY))
        return report
    }

    private func mapButtons(_ pressed: SCButtons) -> GamepadReport.Buttons {
        var buttons: GamepadReport.Buttons = []
        // Rear paddles double as face buttons by default (L4→Y, L5→X,
        // R4→B, R5→A), matching the Windows app.
        if pressed.contains(.btnA) || pressed.contains(.btnR5) { buttons.insert(.a) }
        if pressed.contains(.btnB) || pressed.contains(.btnR4) { buttons.insert(.b) }
        if pressed.contains(.btnX) || pressed.contains(.btnL5) { buttons.insert(.x) }
        if pressed.contains(.btnY) || pressed.contains(.btnL4) { buttons.insert(.y) }
        if pressed.contains(.btnLB) { buttons.insert(.leftBumper) }
        if pressed.contains(.btnRB) { buttons.insert(.rightBumper) }
        if pressed.contains(.btnSelect) { buttons.insert(.back) }
        if pressed.contains(.btnStart) { buttons.insert(.start) }
        if pressed.contains(.btnSteam) { buttons.insert(.guide) }
        if pressed.contains(.lStickClick) { buttons.insert(.leftThumb) }
        if pressed.contains(.rStickClick) { buttons.insert(.rightThumb) }
        return buttons
    }

    /// Treats the absolute touch position as stick deflection.
    private func padAsStick(x: Int16, y: Int16) -> (Int, Int) {
        func scale(_ value: Int16) -> Int {
            guard abs(Int(value)) >= tuning.padStickDeadZone else { return 0 }
            return Int(value) * tuning.padStickSensitivity / 100
        }
        return (scale(x), scale(y))
    }

    /// Gyro yaw/pitch → right stick deflection while the left trigger is
    /// held. Bias learns fast at activation and drifts slowly while idle,
    /// so resting orientation never accumulates into aim.
    private func gyroDelta(_ input: InputState) -> (Int, Int) {
        let rawYaw = Double(input.gyroZ)
        let rawPitch = Double(input.gyroX)
        let active = input.leftTrigger >= tuning.gyroActivationThreshold

        if !active {
            gyroBiasYaw += (rawYaw - gyroBiasYaw) * tuning.gyroBiasSlowWeight
            gyroBiasPitch += (rawPitch - gyroBiasPitch) * tuning.gyroBiasSlowWeight
        } else if !gyroWasActive {
            gyroBiasYaw += (rawYaw - gyroBiasYaw) * tuning.gyroBiasFastWeight
            gyroBiasPitch += (rawPitch - gyroBiasPitch) * tuning.gyroBiasFastWeight
        }
        gyroWasActive = active
        guard active else { return (0, 0) }

        func deflection(_ value: Double) -> Int {
            guard abs(value) >= Double(tuning.gyroDeadZone) else { return 0 }
            return Int(value * Double(tuning.gyroSensitivity))
        }
        return (deflection(-(rawYaw - gyroBiasYaw)),
                deflection(-(rawPitch - gyroBiasPitch)))
    }

    /// Hat values run 0-7 clockwise from north; nil when centered.
    private func hatValue(up: Bool, down: Bool, left: Bool, right: Bool) -> UInt8? {
        switch (up, down, left, right) {
        case (true, false, false, false): return 0
        case (true, false, false, true):  return 1
        case (false, false, false, true): return 2
        case (false, true, false, true):  return 3
        case (false, true, false, false): return 4
        case (false, true, true, false):  return 5
        case (false, false, true, false): return 6
        case (true, false, true, false):  return 7
        default: return nil
        }
    }

    private func clampAxis(_ value: Int) -> Int16 {
        Int16(clamping: value)
    }

    /// Controller axes are up-positive; HID Y axes are down-positive.
    private func flipY(_ value: Int16) -> Int16 {
        value == .min ? .max : -value
    }
}
