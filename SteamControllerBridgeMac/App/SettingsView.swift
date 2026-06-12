import SwiftUI

/// Editable, non-optional mirror of Profile for the settings UI.
struct EditableProfile {
    struct Row {
        var output = "none"
        var turbo = false
    }

    var bindings: [PhysicalInput: Row] = [:]
    var turboIntervalMs = 80.0
    var stickDeadZone = 2500.0
    var padSticksEnabled = true
    var padDeadZone = 800.0
    var padSensitivity = 100.0
    var padMouseEnabled = false
    var padMouseRight = true
    var padMouseDivisor = 65.0
    var stickKeysEnabled = false
    var stickKeysLeft = true
    var stickKeysDeadZone = 1500.0
    var stickKeyUp = "key:w"
    var stickKeyDown = "key:s"
    var stickKeyLeft = "key:a"
    var stickKeyRight = "key:d"
    var stickMouseEnabled = false
    var stickMouseRight = true
    var stickMouseDeadZone = 1500.0
    var stickMouseMaxSpeed = 1200.0
    var gyroEnabled = true
    var gyroToMouse = false
    var gyroActivation = "leftTrigger"
    var gyroSuppressMode = false
    var gyroThreshold = 64.0
    var gyroDeadZone = 45.0
    var gyroSensitivity = 26.0
    var gyroMouseSensitivity = 0.018

    init(_ profile: Profile) {
        let fallback = Profile.defaultProfile.bindings ?? [:]
        for input in PhysicalInput.allCases {
            let binding = profile.bindings?[input.rawValue] ?? fallback[input.rawValue]
            bindings[input] = Row(output: binding?.output.stringValue ?? "none",
                                  turbo: binding?.turbo ?? false)
        }
        turboIntervalMs = Double(profile.turboIntervalMs ?? 80)
        stickDeadZone = Double(profile.sticks?.deadZone ?? 2500)
        padSticksEnabled = profile.padSticks?.enabled ?? true
        padDeadZone = Double(profile.padSticks?.deadZone ?? 800)
        padSensitivity = Double(profile.padSticks?.sensitivityPercent ?? 100)
        padMouseEnabled = profile.padMouse?.enabled ?? false
        padMouseRight = (profile.padMouse?.pad ?? "right") != "left"
        padMouseDivisor = Double(profile.padMouse?.sensitivityDivisor ?? 65)
        stickKeysEnabled = profile.stickKeys?.enabled ?? false
        stickKeysLeft = (profile.stickKeys?.stick ?? "left") != "right"
        stickKeysDeadZone = Double(profile.stickKeys?.deadZone ?? 1500)
        stickKeyUp = profile.stickKeys?.up?.stringValue ?? "key:w"
        stickKeyDown = profile.stickKeys?.down?.stringValue ?? "key:s"
        stickKeyLeft = profile.stickKeys?.left?.stringValue ?? "key:a"
        stickKeyRight = profile.stickKeys?.right?.stringValue ?? "key:d"
        stickMouseEnabled = profile.stickMouse?.enabled ?? false
        stickMouseRight = (profile.stickMouse?.stick ?? "right") != "left"
        stickMouseDeadZone = Double(profile.stickMouse?.deadZone ?? 1500)
        stickMouseMaxSpeed = profile.stickMouse?.maxSpeed ?? 1200
        gyroEnabled = profile.gyro?.enabled ?? true
        gyroToMouse = profile.gyro?.output == "mouse"
        gyroActivation = profile.gyro?.activation ?? "leftTrigger"
        gyroSuppressMode = profile.gyro?.activationMode == "suppress"
        gyroThreshold = Double(profile.gyro?.activationThreshold ?? 64)
        gyroDeadZone = Double(profile.gyro?.deadZone ?? 45)
        gyroSensitivity = Double(profile.gyro?.sensitivity ?? 26)
        gyroMouseSensitivity = profile.gyro?.mouseSensitivity ?? 0.018
    }

    func toProfile(name: String) -> Profile {
        var profileBindings: [String: Profile.Binding] = [:]
        for (input, row) in bindings {
            profileBindings[input.rawValue] = Profile.Binding(
                output: OutputAction(string: row.output) ?? .none,
                turbo: row.turbo)
        }
        return Profile(
            name: name,
            turboIntervalMs: Int(turboIntervalMs),
            bindings: profileBindings,
            sticks: Profile.Sticks(deadZone: Int(stickDeadZone)),
            padSticks: Profile.PadSticks(enabled: padSticksEnabled,
                                         deadZone: Int(padDeadZone),
                                         sensitivityPercent: Int(padSensitivity)),
            padMouse: Profile.PadMouse(enabled: padMouseEnabled,
                                       pad: padMouseRight ? "right" : "left",
                                       sensitivityDivisor: Int(padMouseDivisor)),
            stickKeys: Profile.StickKeys(enabled: stickKeysEnabled,
                                         stick: stickKeysLeft ? "left" : "right",
                                         deadZone: Int(stickKeysDeadZone),
                                         up: OutputAction(string: stickKeyUp) ?? .none,
                                         down: OutputAction(string: stickKeyDown) ?? .none,
                                         left: OutputAction(string: stickKeyLeft) ?? .none,
                                         right: OutputAction(string: stickKeyRight) ?? .none),
            stickMouse: Profile.StickMouse(enabled: stickMouseEnabled,
                                           stick: stickMouseRight ? "right" : "left",
                                           deadZone: Int(stickMouseDeadZone),
                                           maxSpeed: stickMouseMaxSpeed),
            gyro: Profile.Gyro(enabled: gyroEnabled,
                               output: gyroToMouse ? "mouse" : "rightStick",
                               activation: gyroActivation,
                               activationMode: gyroSuppressMode ? "suppress" : "hold",
                               activationThreshold: Int(gyroThreshold),
                               deadZone: Int(gyroDeadZone),
                               sensitivity: Int(gyroSensitivity),
                               mouseSensitivity: gyroMouseSensitivity))
    }
}

extension PhysicalInput {
    var label: String {
        switch self {
        case .a: return "A"
        case .b: return "B"
        case .x: return "X"
        case .y: return "Y"
        case .leftBumper: return "Left Bumper"
        case .rightBumper: return "Right Bumper"
        case .view: return "View"
        case .menu: return "Menu"
        case .steam: return "Steam"
        case .quickAccess: return "Quick Access"
        case .leftStickClick: return "Left Stick Click"
        case .rightStickClick: return "Right Stick Click"
        case .l4: return "L4 Paddle"
        case .l5: return "L5 Paddle"
        case .r4: return "R4 Paddle"
        case .r5: return "R5 Paddle"
        case .leftGrip: return "Left Grip"
        case .rightGrip: return "Right Grip"
        case .dpadUp: return "D-Pad Up"
        case .dpadDown: return "D-Pad Down"
        case .dpadLeft: return "D-Pad Left"
        case .dpadRight: return "D-Pad Right"
        case .leftPadClick: return "Left Pad Click"
        case .rightPadClick: return "Right Pad Click"
        case .leftTriggerFull: return "Left Trigger (full pull)"
        case .rightTriggerFull: return "Right Trigger (full pull)"
        }
    }
}

struct SettingsView: View {
    @State private var edit: EditableProfile
    @State private var profileName: String
    @State private var saveStatus = ""
    @State private var profileSelection = ""
    @State private var userProfiles = ProfileStore.listUserProfiles()
    private let onSave: (Profile) -> Void

    init(profile: Profile, onSave: @escaping (Profile) -> Void) {
        _edit = State(initialValue: EditableProfile(profile))
        _profileName = State(initialValue: profile.name ?? "Custom")
        self.onSave = onSave
    }

    /// All selectable outputs, as (label, encoded value) pairs.
    private static let outputOptions: [(label: String, value: String)] = {
        var options: [(String, String)] = [("None", "none")]
        let gamepad: [(String, String)] = [
            ("A", "a"), ("B", "b"), ("X", "x"), ("Y", "y"),
            ("Left Bumper", "leftBumper"), ("Right Bumper", "rightBumper"),
            ("Back", "back"), ("Start", "start"), ("Guide", "guide"),
            ("Left Stick Click", "leftStickClick"), ("Right Stick Click", "rightStickClick"),
            ("D-Pad Up", "dpadUp"), ("D-Pad Down", "dpadDown"),
            ("D-Pad Left", "dpadLeft"), ("D-Pad Right", "dpadRight"),
        ]
        options += gamepad.map { ("Pad: \($0.0)", $0.1) }
        options += [("Mouse: Left Click", "mouse:left"),
                    ("Mouse: Right Click", "mouse:right"),
                    ("Mouse: Middle Click", "mouse:middle")]
        options += KeyCodes.canonicalNames.map { ("Key: \($0)", "key:\($0)") }
        return options
    }()

    var body: some View {
        VStack(spacing: 0) {
            presetBar
            Divider()
            TabView {
                buttonsTab.tabItem { Text("Buttons") }
                sticksPadsTab.tabItem { Text("Sticks & Pads") }
                gyroTab.tabItem { Text("Gyro") }
            }
            .padding(8)
            Divider()
            footer
        }
        .frame(width: 600, height: 660)
    }

    private var presetBar: some View {
        HStack(spacing: 8) {
            Picker("Profile", selection: $profileSelection) {
                Text("Current").tag("")
                Section("Presets") {
                    ForEach(Profile.presets, id: \.name) { preset in
                        Text(preset.name).tag("preset:" + preset.name)
                    }
                }
                if !userProfiles.isEmpty {
                    Section("My Profiles") {
                        ForEach(userProfiles, id: \.self) { name in
                            Text(name).tag("user:" + name)
                        }
                    }
                }
            }
            .frame(maxWidth: 280)
            .onChange(of: profileSelection) { _, selection in
                loadSelection(selection)
            }

            TextField("Profile name", text: $profileName)
                .textFieldStyle(.roundedBorder)
                .frame(width: 150)
            Button("Save As") {
                saveAsUserProfile()
            }
            .disabled(profileName.trimmingCharacters(in: .whitespaces).isEmpty)
            Button(role: .destructive) {
                deleteSelectedUserProfile()
            } label: {
                Image(systemName: "trash")
            }
            .disabled(!profileSelection.hasPrefix("user:"))
            Spacer()
        }
        .padding(10)
    }

    private func loadSelection(_ selection: String) {
        if selection.hasPrefix("preset:") {
            let name = String(selection.dropFirst(7))
            guard let preset = Profile.presets.first(where: { $0.name == name }) else { return }
            edit = EditableProfile(preset.profile)
            profileName = name
            saveStatus = "Loaded preset \"\(name)\" — Save & Apply to use it"
        } else if selection.hasPrefix("user:") {
            let name = String(selection.dropFirst(5))
            guard let profile = ProfileStore.loadUserProfile(named: name) else { return }
            edit = EditableProfile(profile)
            profileName = name
            saveStatus = "Loaded \"\(name)\" — Save & Apply to use it"
        }
    }

    private func saveAsUserProfile() {
        let name = profileName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        do {
            try ProfileStore.saveUserProfile(edit.toProfile(name: name), named: name)
            userProfiles = ProfileStore.listUserProfiles()
            profileSelection = "user:" + name
            saveStatus = "Saved profile \"\(name)\""
        } catch {
            saveStatus = "Could not save \"\(name)\": \(error.localizedDescription)"
        }
    }

    private func deleteSelectedUserProfile() {
        guard profileSelection.hasPrefix("user:") else { return }
        let name = String(profileSelection.dropFirst(5))
        ProfileStore.deleteUserProfile(named: name)
        userProfiles = ProfileStore.listUserProfiles()
        profileSelection = ""
        saveStatus = "Deleted profile \"\(name)\""
    }

    private var buttonsTab: some View {
        ScrollView {
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 6) {
                GridRow {
                    Text("Input").bold()
                    Text("Output").bold()
                    Text("Turbo").bold()
                }
                ForEach(PhysicalInput.allCases, id: \.self) { input in
                    GridRow {
                        Text(input.label)
                        Picker("", selection: outputBinding(input)) {
                            ForEach(Self.outputOptions, id: \.value) { option in
                                Text(option.label).tag(option.value)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 230)
                        Toggle("", isOn: turboBinding(input)).labelsHidden()
                    }
                }
            }
            .padding(12)
        }
    }

    private var sticksPadsTab: some View {
        Form {
            Section("Joysticks") {
                slider("Dead zone (radial, rescaled)", $edit.stickDeadZone, 0...10000, "%.0f")
            }
            Section("Trackpads as Sticks") {
                Toggle("Enabled (pad drives its stick while touched)", isOn: $edit.padSticksEnabled)
                slider("Dead zone", $edit.padDeadZone, 0...8000, "%.0f")
                slider("Sensitivity %", $edit.padSensitivity, 25...300, "%.0f")
            }
            Section("Trackpad as Mouse") {
                Toggle("Enabled (overrides stick duty for that pad)", isOn: $edit.padMouseEnabled)
                Picker("Pad", selection: $edit.padMouseRight) {
                    Text("Right").tag(true)
                    Text("Left").tag(false)
                }
                slider("Slowness divisor (lower = faster)", $edit.padMouseDivisor, 10...200, "%.0f")
            }
            Section("Stick to Keys (WASD-style)") {
                Toggle("Enabled (stick stops driving its virtual axis)", isOn: $edit.stickKeysEnabled)
                Picker("Stick", selection: $edit.stickKeysLeft) {
                    Text("Left").tag(true)
                    Text("Right").tag(false)
                }
                directionPicker("Up", $edit.stickKeyUp)
                directionPicker("Down", $edit.stickKeyDown)
                directionPicker("Left", $edit.stickKeyLeft)
                directionPicker("Right", $edit.stickKeyRight)
                slider("Dead zone", $edit.stickKeysDeadZone, 500...8000, "%.0f")
            }
            Section("Stick to Mouse") {
                Toggle("Enabled (stick stops driving its virtual axis)", isOn: $edit.stickMouseEnabled)
                Picker("Stick", selection: $edit.stickMouseRight) {
                    Text("Right").tag(true)
                    Text("Left").tag(false)
                }
                slider("Dead zone", $edit.stickMouseDeadZone, 500...8000, "%.0f")
                slider("Max speed (px/s)", $edit.stickMouseMaxSpeed, 200...4000, "%.0f")
            }
            Section("Turbo") {
                slider("Pulse interval (ms)", $edit.turboIntervalMs, 25...500, "%.0f")
            }
        }
        .formStyle(.grouped)
    }

    /// Gyro activator choices: special sources first, then every button.
    private static let gyroActivationOptions: [(label: String, value: String)] = {
        var options: [(String, String)] = [
            ("Always On", "always"),
            ("Left Trigger (soft pull)", "leftTrigger"),
            ("Right Trigger (soft pull)", "rightTrigger"),
            ("Left Pad Touch", "leftPadTouch"),
            ("Right Pad Touch", "rightPadTouch"),
            ("Left Stick Touch", "leftStickTouch"),
            ("Right Stick Touch", "rightStickTouch"),
        ]
        options += PhysicalInput.allCases.map { ($0.label, $0.rawValue) }
        return options
    }()

    private var gyroTab: some View {
        Form {
            Section("Gyro Aiming") {
                Toggle("Enabled", isOn: $edit.gyroEnabled)
                Picker("Output", selection: $edit.gyroToMouse) {
                    Text("Right Stick").tag(false)
                    Text("Mouse").tag(true)
                }
            }
            Section("Activation") {
                Picker("Activator", selection: $edit.gyroActivation) {
                    ForEach(Self.gyroActivationOptions, id: \.value) { option in
                        Text(option.label).tag(option.value)
                    }
                }
                Picker("Mode", selection: $edit.gyroSuppressMode) {
                    Text("Hold to enable gyro").tag(false)
                    Text("Hold to suppress gyro").tag(true)
                }
                .disabled(edit.gyroActivation == "always")
                slider("Trigger threshold (0-255, trigger activators only)",
                       $edit.gyroThreshold, 0...255, "%.0f")
            }
            Section("Tuning") {
                slider("Dead zone", $edit.gyroDeadZone, 0...300, "%.0f")
                slider("Stick sensitivity", $edit.gyroSensitivity, 1...80, "%.0f")
                slider("Mouse sensitivity", $edit.gyroMouseSensitivity, 0.002...0.1, "%.3f")
            }
        }
        .formStyle(.grouped)
    }

    private var footer: some View {
        HStack {
            Text(saveStatus).font(.caption).foregroundStyle(.secondary)
            Spacer()
            Button("Revert to Saved") {
                let saved = ProfileStore.load()
                edit = EditableProfile(saved)
                profileName = saved.name ?? "Custom"
                saveStatus = ""
            }
            Button("Save & Apply") {
                onSave(edit.toProfile(name: profileName))
                saveStatus = "Saved and applied"
            }
            .keyboardShortcut("s")
            .buttonStyle(.borderedProminent)
        }
        .padding(10)
    }

    private func slider(_ label: String, _ value: SwiftUI.Binding<Double>,
                        _ range: ClosedRange<Double>, _ format: String) -> some View {
        HStack {
            Text(label)
            Slider(value: value, in: range)
            Text(String(format: format, value.wrappedValue))
                .frame(width: 56, alignment: .trailing)
                .monospacedDigit()
        }
    }

    private func directionPicker(_ label: String, _ selection: SwiftUI.Binding<String>) -> some View {
        Picker(label, selection: selection) {
            ForEach(Self.outputOptions, id: \.value) { option in
                Text(option.label).tag(option.value)
            }
        }
    }

    private func outputBinding(_ input: PhysicalInput) -> SwiftUI.Binding<String> {
        SwiftUI.Binding(
            get: { edit.bindings[input]?.output ?? "none" },
            set: { edit.bindings[input, default: EditableProfile.Row()].output = $0 })
    }

    private func turboBinding(_ input: PhysicalInput) -> SwiftUI.Binding<Bool> {
        SwiftUI.Binding(
            get: { edit.bindings[input]?.turbo ?? false },
            set: { edit.bindings[input, default: EditableProfile.Row()].turbo = $0 })
    }
}
