# AMFI Route — Step-by-Step Checklist

Self-contained checklist for enabling the virtual gamepad via the AMFI route.
Readable from any browser (you'll lose access to the Mac during Recovery).

> ⚠️ This disables AMFI, which lowers your Mac's code-signing security
> system-wide. For your own machine only. The proper path is Apple's
> VirtualHID entitlement (under review). Undo this once it's granted (last
> section).

## 1. Reduce boot security (Recovery)

1. Shut down the Mac.
2. Apple Silicon: **hold the power button** until "Loading startup options"
   appears → click **Options** → **Continue**. Sign in if prompted.
3. Menu bar → **Utilities → Startup Security Utility**.
4. Select your system disk → **Security Policy** → choose **Reduced Security**
   → OK. Authenticate if asked.

## 2. Set the AMFI boot argument

Still in Recovery: menu bar → **Utilities → Terminal**.

On macOS 27, `nvram` refuses to set `boot-args` while SIP is fully enabled, so
disable SIP first (it gates the same protected NVRAM):

```
csrutil disable
nvram boot-args="amfi_get_out_of_my_way=1"
```

Then: Apple menu → **Restart**. (To re-enable SIP later, `csrutil enable` from
Recovery.)

## 3. Build the entitled app (back in macOS)

In a normal Terminal:

```
cd ~/Developer/SteamControllerBridgeMac
./tools/build_amfi.sh
```

It prints confirmation that `com.apple.developer.hid.virtual.device` is
embedded. Then move the app into place and launch it from there:

```
cp -R build/Release/SteamControllerBridgeMac.app /Applications/
open /Applications/SteamControllerBridgeMac.app
```

Grant **Input Monitoring** when prompted (System Settings → Privacy &
Security → Input Monitoring).

## 4. Verify the virtual pad (do this first!)

1. Confirm it exists: in Terminal, `hidutil list | grep -i 1209` should show
   "Steam Controller Bridge Pad".
2. Plug in the controller, click the menu bar icon → **Enable Bridge**.
3. Open **Chrome** (not Safari) → <https://hardwaretester.com/gamepad> and
   move sticks/press buttons. If they register, the pad works.
4. Then test the real target: **Xbox Cloud Gaming / GeForce Now in
   Chrome or Edge.** If the game sees the pad, you're done.

If the pad shows in hardwaretester but NOT in your cloud-gaming service,
the service likely uses a backend that ignores virtual devices — switch
that service to a keyboard/mouse profile instead (no AMFI needed).

## Undo (once Apple grants the entitlement)

1. Normal Terminal: `sudo nvram -d boot-args` then restart.
2. Back into Recovery → `csrutil enable` (re-enable SIP) → Startup Security
   Utility → **Full Security**.
