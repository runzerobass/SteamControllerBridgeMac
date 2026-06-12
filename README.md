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

> **Status:** the VirtualHID capability request for this app is **currently
> under review by Apple**. Until it is granted, the standard build runs fine
> for keyboard/mouse output, but the virtual gamepad cannot be created. The
> AMFI route below is a stopgap for the virtual gamepad in the meantime.

### 1b. AMFI route (advanced stopgap — reduces system security)

> ## ⚠️ READ THIS FIRST
>
> This route makes the virtual gamepad work **without** Apple's entitlement by
> **disabling AMFI (Apple Mobile File Integrity)** — the macOS subsystem that
> verifies code signatures and entitlements. **This lowers your Mac's security
> system-wide:** with AMFI off, the OS will load improperly-signed code from
> *any* application, not just this one.
>
> - It requires booting into **Recovery** and **downgrading boot security**
>   (Apple Silicon) to set a boot argument. The change persists across reboots
>   until you undo it.
> - It is **for your own machine only.** Do **not** ask anyone else to do this,
>   and do not ship a build that depends on it as the install path.
> - The **proper, secure path is the entitlement above**, which is in review
>   with Apple. Prefer waiting for it if you can.
>
> Proceed only if you understand and accept that you are weakening your own
> system's code-signing enforcement.

If you accept the trade-off:

1. Reboot into Recovery (Apple Silicon: hold the power button → Options).
   In **Startup Security Utility**, set the system to **Reduced Security**.
2. From a Terminal (in Recovery, or after booting back with reduced security):
   `sudo nvram boot-args="amfi_get_out_of_my_way=1"`
   then reboot. (SIP can stay enabled; only AMFI needs the boot-arg.)
3. Build the entitled binary with the helper script:
   `tools/build_amfi.sh` — it builds Release and ad-hoc-signs it with the
   `com.apple.developer.hid.virtual.device` entitlement, printing confirmation
   that the entitlement is embedded.
4. Move the resulting `build/Release/SteamControllerBridgeMac.app` to
   `/Applications` and launch it from there.

**To undo:** `sudo nvram -d boot-args` (and restore Full Security in Recovery),
then reboot. Do this once Apple grants the entitlement.

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

## Cloud gaming (GeForce Now, Xbox Cloud Gaming)

These services read controllers through the browser's Gamepad API or a native
app, and the backend decides whether the virtual pad is visible:

- **Chrome / Edge** read generic HID gamepads through their IOKit backend — the
  virtual pad should appear. **Use one of these.**
- **Safari** uses GameController.framework, which ignores virtual HID devices —
  the pad will **not** appear there.
- GeForce Now's **native Mac app** is untested; prefer its browser version in
  Chrome/Edge, or fall back to a keyboard/mouse profile.

If your service only works in Safari or a native app that can't see the pad,
use a keyboard/mouse mapping profile instead (no entitlement required).

## Verifying without a game

- Virtual pad exists: `hidutil list | grep -i 1209`
- Full button/axis check: open <https://hardwaretester.com/gamepad> in Chrome.
- SDL check: `brew install sdl2` and run `controllermap` / `testcontroller`
  (also generates the gamecontrollerdb mapping string for SDL games).
- Raw controller reports: menu → **Log Raw Reports**, watch in Console.app
  (subsystem `com.arvindrao.SteamControllerBridgeMac`).

## Remapping

The easiest way: menu → **Settings…** (⌘,) opens a window with one-click
presets (Default, Nintendo Swap, Desktop Mouse, FPS Keyboard & Mouse), a
dropdown per physical input with optional per-button turbo, and sliders
for all trackpad/stick/gyro tuning. **Save & Apply** takes effect
immediately.

For hand editing and sharing, the same mappings live in
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

Outputs come in three flavors:

- **Gamepad:** `a b x y leftBumper rightBumper back start guide
  leftStickClick rightStickClick dpadUp dpadDown dpadLeft dpadRight`
- **Keyboard:** `key:<name>` — letters/digits (`key:w`), plus `space return
  tab escape shift control option command backspace delete grave minus equal
  comma period slash semicolon quote leftbracket rightbracket backslash
  up down left right home end pageup pagedown f1`–`f12`. Example:
  `"r4": { "output": "key:space" }`
- **Mouse:** `mouse:left`, `mouse:right`, `mouse:middle`
- `none` unbinds an input.

Keyboard/mouse bindings require the **Accessibility** permission (System
Settings → Privacy & Security → Accessibility); the app prompts when a
profile uses them. Held keys are always released on profile reload, bridge
disable, and quit.

`turboIntervalMs` (25-500) sets the global turbo pulse rate; turbo works on
keyboard/mouse outputs too. The `padSticks` and `gyro` sections tune
trackpad-stick deadzone/sensitivity and gyro aiming (activation threshold,
deadzone, sensitivity), or disable either feature.

**Trackpad as mouse:** set `padMouse.enabled` to `true` to make a pad drive
the macOS cursor laptop-trackpad style (finger-travel deltas). `pad` picks
`"left"` or `"right"` (the chosen pad stops acting as a stick);
`sensitivityDivisor` controls speed (lower = faster, default 65). Combine
with `"rightPadClick": { "output": "mouse:left" }` for tap-to-click.

**Gyro as mouse:** set `gyro.output` to `"mouse"` to aim the cursor with the
gyro instead of the right stick; `mouseSensitivity` scales it (default
0.018). Both mouse modes require the Accessibility permission, like key
bindings.

**Gyro activation:** `gyro.activation` picks what gates gyro aiming —
`always`, `leftTrigger` (default), `rightTrigger`, `leftPadTouch`,
`rightPadTouch`, `leftStickTouch`, `rightStickTouch`, or any physical
button name. `gyro.activationMode` is `hold` (gyro on while held, default)
or `suppress` (gyro always on except while held).
`activationThreshold` (0-255) applies to trigger activators.

**Stick to keys (WASD):** set `stickKeys.enabled` to `true` to turn a
stick's cardinal directions into outputs (defaults: left stick → W/A/S/D;
each direction accepts any output form). The stick stops driving its
virtual axis while enabled.

**Stick to mouse:** set `stickMouse.enabled` to `true` for joystick-style
cursor control (deflection = velocity). `stick` picks left/right (default
right), `maxSpeed` is pixels/second at full deflection (default 1200).

A full keyboard/mouse "desktop mode" profile is: `stickKeys` on,
`stickMouse` on, button bindings to keys, and triggers via
`leftTriggerFull`/`rightTriggerFull` to `mouse:right`/`mouse:left`.

## Default layout

ABXY, bumpers, stick clicks, and d-pad map 1:1. View→Back, Menu→Start,
Steam→Guide. Rear paddles: L4→Y, L5→X, R4→B, R5→A. Sticks and analog
triggers pass through.

- **Trackpads as sticks:** while touched, the left pad drives the left
  stick and the right pad drives the right stick.
- **Gyro aiming:** while the left trigger is held (≥ 25%), gyro yaw/pitch
  blends into the right stick, with automatic drift-bias compensation.
  Tuning constants live in `MappingEngine.Tuning`.

## Credits

Menu bar icon: [Steam Controller](https://icons8.com/icons/set/steam-controller) by [Icons8](https://icons8.com).

## Roadmap

- Phase 2: remappable profiles (JSON), turbo, profile picker.
- Phase 3: keyboard/mouse output backend, trackpad-as-mouse, gyro-to-mouse,
  rumble passthrough to the controller's haptics, BLE/Puck hardening.
