# Steam Controller Bridge for macOS

A menu bar utility that reads the 2026 Steam Controller / Steam Controller Puck
directly over HID and exposes it as a virtual gamepad, with an Xbox-style
default layout. Inspired by the Steam Controller Bridge tray app for Windows
(a separate project by another author).

## How it works

- **Input:** IOHIDManager opens the controller (VID `0x28DE`, PIDs
  `0x1302`/`0x1303`/`0x1304`) in seize mode, disables lizard mode with the
  same feature commands Steam uses, and parses the raw state reports
  (buttons, sticks, pads, triggers, IMU).
- **Output:** a virtual HID gamepad is published with CoreHID's
  `HIDVirtualDevice` (16 buttons, dpad hat, 4 stick axes, 2 trigger axes)
  under a generic VID/PID so SDL-based games read it through their IOKit
  backend.

Games using only Apple's GameController framework will **not** see the virtual
pad — macOS filters virtual HID devices there by design. SDL-based games
(most Mac Steam ports), Steam itself, and emulators do see it.

## One-time setup

### 1. HID Virtual Device entitlement (required for the virtual gamepad)

The app needs the restricted entitlement `com.apple.developer.hid.virtual.device`:

1. In the [Apple Developer portal](https://developer.apple.com/account/resources/identifiers/list),
   create/edit the app ID `com.arvindrao.SteamControllerBridgeMac` and look for
   **HID Virtual Device** under **Additional Capabilities**. Enable it if present.
   If it is not listed, request the entitlement from Apple (Account → contact /
   entitlement request), describing the controller-bridge use case.
2. Once the capability is on the app ID, uncomment the entitlement in
   `SteamControllerBridgeMac/SteamControllerBridgeMac.entitlements` and let
   Xcode regenerate the provisioning profile (automatic signing).
3. Verify after building:
   `codesign -d --entitlements - <path to SteamControllerBridgeMac.app>`

Do **not** sign with the entitlement before the provisioning profile includes
it — AMFI will kill the app at launch. Until the entitlement is in place the
app builds and runs, but enabling the bridge reports that the virtual pad
could not be created.

### 2. Input Monitoring permission

On first launch macOS prompts for **Input Monitoring**
(System Settings → Privacy & Security → Input Monitoring). Required to read
the controller's raw HID reports. Re-grant (or
`tccutil reset ListenEvent com.arvindrao.SteamControllerBridgeMac`) after
signing changes during development.

## Usage

1. Launch the app — a game controller icon appears in the menu bar.
2. Connect the Steam Controller by USB (or the Puck).
3. Click **Enable Bridge**. The icon fills in when bridging.
4. Quit or **Disable Bridge** to restore the controller's normal behavior
   (lizard mode).

Close Steam (or disable Steam Input for the controller) while bridging to
avoid double input.

## Verifying without a game

- Virtual pad exists: `hidutil list | grep -i 1209`
- Full button/axis check: open <https://hardwaretester.com/gamepad> in Chrome.
- SDL check: `brew install sdl2` and run `controllermap` / `testcontroller`
  (also generates the gamecontrollerdb mapping string for SDL games).
- Raw controller reports: menu → **Log Raw Reports**, watch in Console.app
  (subsystem `com.arvindrao.SteamControllerBridgeMac`).

## Remapping

Mappings live in
`~/Library/Application Support/SteamControllerBridgeMac/profile.json`
(created with the default layout on first launch). Use the menu's
**Edit Mappings…** to open it and **Reload Mappings** (⌘R in the menu) to
apply changes — no restart needed.

Each entry binds a physical input to a virtual pad output, with optional
per-button turbo:

```json
"r4": { "output": "b", "turbo": true }
```

Physical inputs: `a b x y leftBumper rightBumper view menu steam quickAccess
leftStickClick rightStickClick l4 l5 r4 r5 leftGrip rightGrip dpadUp dpadDown
dpadLeft dpadRight leftPadClick rightPadClick leftTriggerFull rightTriggerFull`.
Outputs: the same gamepad buttons plus `back start guide dpad*` and `none`.
`turboIntervalMs` (25-500) sets the global turbo pulse rate. The `padSticks`
and `gyro` sections tune trackpad-stick deadzone/sensitivity and gyro aiming
(activation threshold, deadzone, sensitivity), or disable either feature.

## Default layout

ABXY, bumpers, stick clicks, and d-pad map 1:1. View→Back, Menu→Start,
Steam→Guide. Rear paddles: L4→Y, L5→X, R4→B, R5→A. Sticks and analog
triggers pass through.

- **Trackpads as sticks:** while touched, the left pad drives the left
  stick and the right pad drives the right stick.
- **Gyro aiming:** while the left trigger is held (≥ 25%), gyro yaw/pitch
  blends into the right stick, with automatic drift-bias compensation.
  Tuning constants live in `MappingEngine.Tuning`.

## Roadmap

- Phase 2: remappable profiles (JSON), turbo, profile picker.
- Phase 3: keyboard/mouse output backend, trackpad-as-mouse, gyro-to-mouse,
  rumble passthrough to the controller's haptics, BLE/Puck hardening.
