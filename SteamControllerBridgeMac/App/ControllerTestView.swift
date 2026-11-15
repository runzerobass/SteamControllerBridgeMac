import SwiftUI

/// "Test Controls" tab: live physical Steam Controller state next to what
/// the bridge relays to the virtual XInput-style pad (and kb/m), plus the
/// raw button bitmask for diagnosing mismatched inputs.
struct ControllerTestView: View {
    @ObservedObject var monitor: LiveInputMonitor

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                statusHeader
                GroupBox("Steam Controller (physical input)") {
                    SteamControllerDiagram(input: monitor.snapshot.input)
                        .frame(width: 540, height: 290)
                        .frame(maxWidth: .infinity)
                }
                GroupBox("Pressed → bound output (applied profile)") {
                    bindingList.frame(maxWidth: .infinity, alignment: .leading)
                }
                GroupBox("Relayed to virtual pad (XInput layout)") {
                    VStack(alignment: .leading, spacing: 6) {
                        XInputDiagram(report: monitor.snapshot.output.report,
                                      yUpPositive: monitor.appliedProfile.sticks?.yAxisUpPositive ?? true)
                            .frame(width: 540, height: 230)
                            .frame(maxWidth: .infinity)
                        kbmLine
                    }
                }
                GroupBox("Raw button bits (state report bytes 2–5)") {
                    RawBitsGrid(raw: monitor.snapshot.input.buttons.rawValue)
                        .frame(maxWidth: .infinity)
                }
                GroupBox("Button events") {
                    eventLog.frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(12)
        }
        .onAppear { monitor.beginObserving() }
        .onDisappear { monitor.endObserving() }
    }

    private var statusHeader: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Circle().fill(monitor.connected ? Color.green : Color.orange)
                    .frame(width: 8, height: 8)
                Text(monitor.connectionText).font(.callout.weight(.medium))
            }
            Text(monitor.connected
                 ? "Press anything on the controller. Input is still relayed to games while testing."
                 : "Enable the bridge from the menu bar and connect the controller to test.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    // MARK: Binding list

    private var bindingList: some View {
        let input = monitor.snapshot.input
        let bindings = monitor.appliedProfile.bindings ?? Profile.defaultProfile.bindings ?? [:]
        let pressed = PhysicalInput.allCases.filter { input.buttons.contains($0.buttonMask) }
        return VStack(alignment: .leading, spacing: 3) {
            if pressed.isEmpty {
                Text("Nothing pressed").foregroundStyle(.secondary)
            }
            ForEach(pressed, id: \.self) { physical in
                let binding = bindings[physical.rawValue]
                HStack(spacing: 6) {
                    Text(physical.label).bold()
                    Image(systemName: "arrow.right").foregroundStyle(.secondary)
                    Text(Self.describe(binding?.output ?? .none))
                    if binding?.turbo == true {
                        Text("TURBO").font(.caption2.bold()).foregroundStyle(.orange)
                    }
                }
            }
        }
        .font(.callout)
    }

    static func describe(_ action: OutputAction) -> String {
        switch action {
        case .none: return "Nothing"
        case .button(let b): return "Pad " + XInputDiagram.name(of: b)
        case .dpad(let d): return "Pad D-Pad " + d.rawValue.capitalized
        case .key(let code): return "Key " + (KeyCodes.name(for: code) ?? "#\(code)")
        case .mouse(let m): return "Mouse " + m.rawValue.capitalized
        }
    }

    private var kbmLine: some View {
        let output = monitor.snapshot.output
        let keys = output.keys.compactMap { KeyCodes.name(for: $0) }.sorted()
        let mouse = output.mouseButtons.map(\.rawValue.capitalized).sorted()
        return HStack(spacing: 16) {
            Label(keys.isEmpty ? "—" : keys.joined(separator: ", "), systemImage: "keyboard")
            Label(mouse.isEmpty ? "—" : mouse.joined(separator: ", "), systemImage: "computermouse")
            Label(String(format: "Δ %.1f, %.1f", output.mouseDX, output.mouseDY),
                  systemImage: "cursorarrow.motionlines")
        }
        .font(.caption.monospacedDigit())
    }

    private var eventLog: some View {
        VStack(alignment: .leading, spacing: 2) {
            if monitor.events.isEmpty {
                Text("Press/release events appear here, with their raw bit.")
                    .foregroundStyle(.secondary)
            }
            ForEach(Array(monitor.events.enumerated()), id: \.offset) { _, line in
                Text(line)
            }
        }
        .font(.caption.monospaced())
    }
}

// MARK: - Shared drawing pieces

private let activeColor = Color.accentColor
private let idleFill = Color.secondary.opacity(0.12)
private let idleStroke = Color.secondary.opacity(0.5)

/// A labeled button that lights up while pressed.
private struct Key: View {
    let label: String
    let active: Bool
    var width: CGFloat = 28
    var height: CGFloat = 20
    var tint: Color = activeColor

    var body: some View {
        RoundedRectangle(cornerRadius: min(width, height) / 2)
            .fill(active ? tint : idleFill)
            .overlay(RoundedRectangle(cornerRadius: min(width, height) / 2)
                .stroke(active ? tint : idleStroke, lineWidth: 1))
            .overlay(Text(label).font(.system(size: 9, weight: .semibold))
                .foregroundStyle(active ? Color.white : Color.primary))
            .frame(width: width, height: height)
    }
}

/// A stick: dot shows deflection (normalized ±1, screen Y down), ring
/// shows touch, fill shows click.
private struct Stick: View {
    let label: String
    let x: Double
    let y: Double
    let clicked: Bool
    var touched = false
    var radius: CGFloat = 28

    var body: some View {
        ZStack {
            Circle().fill(clicked ? activeColor.opacity(0.45) : idleFill)
            Circle().stroke(touched || clicked ? activeColor : idleStroke,
                            lineWidth: touched ? 2.5 : 1)
            Circle().fill(activeColor)
                .frame(width: 10, height: 10)
                .offset(x: x * (radius - 6), y: y * (radius - 6))
            Text(label).font(.system(size: 8, weight: .bold))
                .foregroundStyle(.secondary)
                .offset(y: radius + 8)
        }
        .frame(width: radius * 2, height: radius * 2)
    }
}

/// A horizontal analog trigger meter; `full` highlights the full-pull bit.
private struct TriggerBar: View {
    let label: String
    let value: UInt8
    var full = false

    var body: some View {
        HStack(spacing: 4) {
            Text(label).font(.system(size: 9, weight: .bold))
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3).fill(idleFill)
                RoundedRectangle(cornerRadius: 3).fill(activeColor)
                    .frame(width: 70 * Double(value) / 255)
            }
            .frame(width: 70, height: 10)
            .overlay(RoundedRectangle(cornerRadius: 3)
                .stroke(full ? Color.orange : idleStroke, lineWidth: full ? 2 : 1))
            Text("\(value)").font(.system(size: 9).monospacedDigit())
                .frame(width: 22, alignment: .trailing)
        }
    }
}

private func axis(_ value: Int16) -> Double { Double(value) / 32767.0 }

// MARK: - Steam Controller diagram

private struct SteamControllerDiagram: View {
    let input: InputState

    private func on(_ b: SCButtons) -> Bool { input.buttons.contains(b) }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 80)
                .stroke(idleStroke, lineWidth: 1.5)
                .frame(width: 520, height: 200)
                .position(x: 270, y: 145)

            TriggerBar(label: "LT", value: input.leftTrigger, full: on(.lTrigFull))
                .position(x: 120, y: 12)
            TriggerBar(label: "RT", value: input.rightTrigger, full: on(.rTrigFull))
                .position(x: 420, y: 12)
            Key(label: "LB", active: on(.btnLB), width: 70, height: 16).position(x: 120, y: 34)
            Key(label: "RB", active: on(.btnRB), width: 70, height: 16).position(x: 420, y: 34)

            // D-pad
            Key(label: "▲", active: on(.dpadUp), width: 20).position(x: 80, y: 82)
            Key(label: "▼", active: on(.dpadDown), width: 20).position(x: 80, y: 126)
            Key(label: "◀", active: on(.dpadLeft), width: 20).position(x: 58, y: 104)
            Key(label: "▶", active: on(.dpadRight), width: 20).position(x: 102, y: 104)

            Stick(label: "LS", x: axis(input.leftStickX), y: -axis(input.leftStickY),
                  clicked: on(.lStickClick), touched: on(.lStickTouch))
                .position(x: 170, y: 100)
            Stick(label: "RS", x: axis(input.rightStickX), y: -axis(input.rightStickY),
                  clicked: on(.rStickClick), touched: on(.rStickTouch))
                .position(x: 370, y: 100)

            // Center cluster
            Key(label: "View", active: on(.btnSelect), width: 34).position(x: 230, y: 72)
            Key(label: "Steam", active: on(.btnSteam), width: 40, height: 22).position(x: 270, y: 72)
            Key(label: "Menu", active: on(.btnStart), width: 34).position(x: 310, y: 72)
            Key(label: "•••", active: on(.btnQAM), width: 34).position(x: 270, y: 102)

            // Face buttons
            Key(label: "Y", active: on(.btnY), width: 22, height: 22).position(x: 460, y: 78)
            Key(label: "A", active: on(.btnA), width: 22, height: 22).position(x: 460, y: 130)
            Key(label: "X", active: on(.btnX), width: 22, height: 22).position(x: 434, y: 104)
            Key(label: "B", active: on(.btnB), width: 22, height: 22).position(x: 486, y: 104)

            Trackpad(label: "L PAD", x: input.leftPadX, y: input.leftPadY,
                     pressure: input.leftPadPressure,
                     touched: on(.lPadActive), clicked: on(.lPadClick))
                .position(x: 190, y: 190)
            Trackpad(label: "R PAD", x: input.rightPadX, y: input.rightPadY,
                     pressure: input.rightPadPressure,
                     touched: on(.rPadActive), clicked: on(.rPadClick))
                .position(x: 350, y: 190)

            Key(label: "Grip", active: on(.lGrip), width: 44).position(x: 60, y: 200)
            Key(label: "Grip", active: on(.rGrip), width: 44).position(x: 480, y: 200)

            // Back paddles (rear of the controller)
            Text("BACK").font(.system(size: 8, weight: .bold)).foregroundStyle(.secondary)
                .position(x: 270, y: 262)
            Key(label: "L4", active: on(.btnL4), width: 40).position(x: 120, y: 262)
            Key(label: "L5", active: on(.btnL5), width: 40).position(x: 170, y: 262)
            Key(label: "R5", active: on(.btnR5), width: 40).position(x: 370, y: 262)
            Key(label: "R4", active: on(.btnR4), width: 40).position(x: 420, y: 262)

            Text("gyro \(input.gyroX) / \(input.gyroY) / \(input.gyroZ)")
                .font(.system(size: 9).monospacedDigit()).foregroundStyle(.secondary)
                .position(x: 270, y: 282)
        }
    }
}

private struct Trackpad: View {
    let label: String
    let x: Int16
    let y: Int16
    let pressure: Int16
    let touched: Bool
    let clicked: Bool
    private let size: CGFloat = 70

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(clicked ? activeColor.opacity(0.45) : idleFill)
            RoundedRectangle(cornerRadius: 12)
                .stroke(touched ? activeColor : idleStroke, lineWidth: touched ? 2.5 : 1)
            if touched {
                Circle().fill(activeColor)
                    .frame(width: 8 + 8 * max(axis(pressure), 0),
                           height: 8 + 8 * max(axis(pressure), 0))
                    .offset(x: axis(x) * (size / 2 - 6), y: -axis(y) * (size / 2 - 6))
            }
            Text(label).font(.system(size: 8, weight: .bold)).foregroundStyle(.secondary)
                .offset(y: size / 2 + 8)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - XInput diagram

struct XInputDiagram: View {
    let report: GamepadReport
    /// Matches the profile's Y direction so the dots move with the stick.
    var yUpPositive = true

    private var ySign: Double { yUpPositive ? -1 : 1 }

    static func name(of buttons: GamepadReport.Buttons) -> String {
        let names: [(GamepadReport.Buttons, String)] = [
            (.a, "A"), (.b, "B"), (.x, "X"), (.y, "Y"),
            (.leftBumper, "LB"), (.rightBumper, "RB"),
            (.back, "Back"), (.start, "Start"), (.guide, "Guide"),
            (.leftThumb, "LS Click"), (.rightThumb, "RS Click"),
        ]
        let matched = names.filter { buttons.contains($0.0) }.map(\.1)
        return matched.isEmpty ? "—" : matched.joined(separator: "+")
    }

    private func on(_ b: GamepadReport.Buttons) -> Bool { report.buttons.contains(b) }

    /// Hat 0-7 clockwise from north.
    private func hat(_ directions: Set<UInt8>) -> Bool {
        guard let hat = report.hat else { return false }
        return directions.contains(hat)
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 70)
                .stroke(idleStroke, lineWidth: 1.5)
                .frame(width: 440, height: 160)
                .position(x: 270, y: 135)

            TriggerBar(label: "LT", value: report.leftTrigger).position(x: 140, y: 12)
            TriggerBar(label: "RT", value: report.rightTrigger).position(x: 400, y: 12)
            Key(label: "LB", active: on(.leftBumper), width: 70, height: 16).position(x: 140, y: 36)
            Key(label: "RB", active: on(.rightBumper), width: 70, height: 16).position(x: 400, y: 36)

            Stick(label: "LS", x: axis(report.leftStickX), y: ySign * axis(report.leftStickY),
                  clicked: on(.leftThumb))
                .position(x: 150, y: 100)
            Stick(label: "RS", x: axis(report.rightStickX), y: ySign * axis(report.rightStickY),
                  clicked: on(.rightThumb))
                .position(x: 330, y: 165)

            Key(label: "▲", active: hat([7, 0, 1]), width: 20).position(x: 210, y: 145)
            Key(label: "▼", active: hat([3, 4, 5]), width: 20).position(x: 210, y: 189)
            Key(label: "◀", active: hat([5, 6, 7]), width: 20).position(x: 188, y: 167)
            Key(label: "▶", active: hat([1, 2, 3]), width: 20).position(x: 232, y: 167)

            Key(label: "Back", active: on(.back), width: 36).position(x: 230, y: 95)
            Key(label: "Guide", active: on(.guide), width: 42, height: 22).position(x: 270, y: 72)
            Key(label: "Start", active: on(.start), width: 36).position(x: 310, y: 95)

            Key(label: "Y", active: on(.y), width: 22, height: 22, tint: .yellow).position(x: 390, y: 74)
            Key(label: "A", active: on(.a), width: 22, height: 22, tint: .green).position(x: 390, y: 126)
            Key(label: "X", active: on(.x), width: 22, height: 22, tint: .blue).position(x: 364, y: 100)
            Key(label: "B", active: on(.b), width: 22, height: 22, tint: .red).position(x: 416, y: 100)

            Text(String(format: "LS X/Y %6d,%6d   RS Rx/Ry %6d,%6d   LT Z %3d   RT Rz %3d",
                        report.leftStickX, report.leftStickY,
                        report.rightStickX, report.rightStickY,
                        report.leftTrigger, report.rightTrigger))
                .font(.system(size: 9).monospaced()).foregroundStyle(.secondary)
                .position(x: 270, y: 224)
        }
    }
}

// MARK: - Raw bits

/// Every bit of the 32-bit button field, labeled with what the app
/// believes it is. A press that lights the wrong label is a mismatch.
private struct RawBitsGrid: View {
    let raw: UInt32

    static let names: [Int: String] = [
        0: "A", 1: "B", 2: "X", 3: "Y", 4: "QAM", 5: "RS clk", 6: "Menu", 7: "R4",
        8: "R5", 9: "RB", 10: "D↓", 11: "D→", 12: "D←", 13: "D↑", 14: "View", 15: "LS clk",
        16: "Steam", 17: "L4", 18: "L5", 19: "LB", 20: "RS tch", 21: "RP tch", 22: "RP clk",
        23: "RT full", 24: "LS tch", 25: "LP tch", 26: "LP clk", 27: "LT full",
        28: "R grip", 29: "L grip",
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Grid(horizontalSpacing: 3, verticalSpacing: 3) {
                ForEach(0..<2) { row in
                    GridRow {
                        ForEach(0..<16) { col in
                            cell(row * 16 + col)
                        }
                    }
                }
            }
            Text(String(format: "0x%08X", raw))
                .font(.caption.monospaced()).foregroundStyle(.secondary)
        }
    }

    private func cell(_ bit: Int) -> some View {
        let set = raw & (1 << UInt32(bit)) != 0
        let known = Self.names[bit] != nil
        let tint: Color = known ? activeColor : .orange
        return VStack(spacing: 1) {
            Text("\(bit)").font(.system(size: 8).monospacedDigit())
            Text(Self.names[bit] ?? "?").font(.system(size: 7, weight: .semibold))
                .lineLimit(1).minimumScaleFactor(0.6)
        }
        .foregroundStyle(set ? Color.white : Color.primary)
        .frame(width: 30, height: 28)
        .background(RoundedRectangle(cornerRadius: 4).fill(set ? tint : idleFill))
        .overlay(RoundedRectangle(cornerRadius: 4)
            .stroke(known ? idleStroke : Color.orange.opacity(0.6), lineWidth: 1))
    }
}

extension RawBitsGrid {
    static func label(forBit bit: Int) -> String { names[bit] ?? "unknown" }
}

/// Event-log helper usable from the monitor.
enum ButtonBitNames {
    static func label(_ bit: Int) -> String { RawBitsGrid.label(forBit: bit) }
}
