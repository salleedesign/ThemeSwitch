#!/bin/bash
# Builds ThemeSwitch.app. Needs only the Command Line Tools (no Xcode project).
set -euo pipefail

cd "$(dirname "$0")"

NAME="ThemeSwitch"
APP="$NAME.app"

# Staged outside the project directory, then moved into place. Under iCloud's
# "Desktop & Documents" sync the file provider stamps com.apple.FinderInfo onto
# the bundle in the window between the xattr clear and codesign, and signing
# then fails with "resource fork, Finder information, or similar detritus not
# allowed". Building on unsynced storage removes the race.
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
BUILD="$STAGE/$APP"

mkdir -p "$BUILD/Contents/MacOS" "$BUILD/Contents/Resources"

swiftc -O \
    -target arm64-apple-macos13.0 \
    -o "$BUILD/Contents/MacOS/$NAME" \
    Sources/main.swift

cp Resources/AppIcon.icns "$BUILD/Contents/Resources/AppIcon.icns"

cat > "$BUILD/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>          <string>ThemeSwitch</string>
    <key>CFBundleIconFile</key>            <string>AppIcon</string>
    <key>CFBundleIdentifier</key>          <string>com.jeremysallee.ThemeSwitch</string>
    <key>CFBundleName</key>                <string>ThemeSwitch</string>
    <key>CFBundlePackageType</key>         <string>APPL</string>
    <key>CFBundleShortVersionString</key>  <string>1.0</string>
    <key>CFBundleVersion</key>             <string>1</string>
    <key>LSMinimumSystemVersion</key>      <string>13.0</string>
    <!-- Menu bar only: no Dock icon, no app menu. -->
    <key>LSUIElement</key>                 <true/>
    <key>NSAppleEventsUsageDescription</key>
    <string>ThemeSwitch changes the system appearance.</string>
</dict>
</plist>
PLIST

# Ad-hoc signature: enough for local use and for "Open at Login" to register.
xattr -cr "$BUILD"
codesign --force --sign - "$BUILD"

rm -rf "$APP"
mv "$BUILD" "$APP"

echo "Built $(pwd)/$APP"
