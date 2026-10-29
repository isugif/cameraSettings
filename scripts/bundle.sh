#!/usr/bin/env bash
# Builds a release binary and wraps it in "build/Camera Settings.app" (ad-hoc signed).
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release --product CameraSettings
app="build/Camera Settings.app"
rm -rf "$app"
mkdir -p "$app/Contents/MacOS"
cp "$(swift build -c release --show-bin-path)/CameraSettings" "$app/Contents/MacOS/CameraSettings"
cat > "$app/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key><string>CameraSettings</string>
    <key>CFBundleIdentifier</key><string>local.cameraSettings</string>
    <key>CFBundleName</key><string>Camera Settings</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>1.0</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>NSCameraUsageDescription</key><string>Shows a live preview while you adjust camera settings.</string>
</dict>
</plist>
PLIST
codesign --force --sign - "$app"
echo "Built $app"
