# Camera Settings

A small macOS app for adjusting a USB webcam: zoom, pan/tilt, focus, exposure, white balance,
brightness, contrast, saturation, sharpness, gain, backlight compensation, and anti-flicker.

## Why

I needed a replacement for Logitech's Camera Settings app to operate my Logitech C930e. The old
app is no longer maintained, and zoom stopped working. Logitech's current app, Logi Tune, does a
lot more than adjust the camera.

New drivers turned out to be unnecessary. The C930e is a standard USB Video Class (UVC) camera,
and macOS already runs it with its own built-in driver. The old app was only a settings panel.
This app sends the same standard UVC control requests over USB, with no driver, kernel extension,
or root access.

This was a single-shot creation with [Claude Code](https://claude.com/claude-code).

## Features

- **Live preview** next to the controls.
- **Ranges come from the camera.** Each control's range and step are read from the camera itself,
  so any UVC webcam should work, not just Logitech.
- **Auto modes.** Auto focus, exposure, and white balance can be turned on or off. Manual
  sliders are disabled while auto is on.
- **Settings persist** for each camera model and are re-applied when the camera is plugged back
  in, since UVC cameras forget their settings on unplug.
- **Menu-bar icon.** The app keeps running in the menu bar after the window closes, so
  re-applying keeps working.
- **Works while the camera is in use** by Zoom, FaceTime, and similar apps.

## Build

Requires macOS 14+ and Xcode (Swift 6).

```bash
scripts/bundle.sh                 # builds "build/Camera Settings.app"
open "build/Camera Settings.app"
```

The app is ad-hoc signed for the machine that built it. On another Mac, right-click → Open the
first time.

## Command-line probe

```bash
swift run uvc-probe              # list each camera's controls, ranges, and current values
swift run uvc-probe roundtrip    # write, read back, and restore each control (briefly changes the image)
swift test                       # unit tests; no camera needed
```

## Tested with

- Logitech Webcam C930e (`046d:0843`) on macOS 26, Apple Silicon. `uvc-probe roundtrip` passes
  for every adjustable control.

## Layout

- `Sources/CUSB`: minimal IOKit wrapper in C, which sends USB control requests.
- `Sources/UVCKit`: UVC descriptor parsing, the control catalog, and the restore order. No UI.
- `Sources/CameraSettings`: the SwiftUI app.
- `Sources/uvc-probe`: hardware check CLI.
