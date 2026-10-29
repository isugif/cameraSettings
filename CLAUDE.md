# Camera Settings

A macOS app that adjusts USB (UVC) webcam controls — zoom, pan/tilt, focus, exposure, white balance,
image levels, anti-flicker — replacing Logitech's discontinued Camera Settings app. No driver: macOS's
built-in UVC driver runs the camera; this app only sends standard UVC control requests over USB.

## Non-negotiables

1. **No drivers, no root.** Everything goes through IOKit default-pipe control requests as the user.
   If a feature needs a DriverKit extension or `sudo`, it is out of scope.
2. **`UVCKit` imports no UI and no store.** Descriptor parsing, control catalog, codec, and the
   restore order are pure functions over `ControlTransport`; persistence lives in the app target.
3. **Hardware facts come from the device.** Ranges, steps and defaults are read with GET_MIN/MAX/RES/DEF,
   and supported controls from the descriptor's bmControls — never hard-coded per camera model.
4. **Modes before values.** Restoring writes auto/manual toggles first and skips values the camera is
   currently driving itself (`UVCCamera.apply`). Breaking this order silently drops saved settings.
5. **Read back after every write.** The UI shows what the camera reports, not what was sent.
6. **Tests run without hardware.** New UVCKit logic gets a test against `StubTransport` and the captured
   `Fixtures/c930e-config.hex` descriptor; hardware checks go in `uvc-probe`.

## Commands

- `swift test` — unit tests (no camera needed)
- `swift run uvc-probe` — list controls; `uvc-probe roundtrip` writes/reads back/restores each one
  (visibly changes the image for a moment); `uvc-probe descriptor` dumps a fixture
- `scripts/bundle.sh` — builds `build/Camera Settings.app` (ad-hoc signed)
