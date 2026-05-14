#!/usr/bin/env bash
set -euo pipefail

APP_NAME="Simple Image Viewer"
BINARY_NAME="simple-image-viewer"
BUNDLE_ID="app.simple-image-viewer"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
EXECUTABLE="$APP_BUNDLE/Contents/MacOS/$BINARY_NAME"
APP_LOG="$HOME/Library/Logs/$APP_NAME/app.log"
MODE="${1:-run}"

cd "$ROOT_DIR"

if [[ "$MODE" != "run" && "$MODE" != "--verify" && "$MODE" != "--debug" && "$MODE" != "--app-log" ]]; then
  echo "usage: $0 [run|--verify|--debug|--app-log] [image-or-folder]" >&2
  exit 2
fi

if [[ "$MODE" == "run" || "$MODE" == "--verify" || "$MODE" == "--debug" || "$MODE" == "--app-log" ]]; then
  shift || true
fi

pkill -f "$EXECUTABLE" >/dev/null 2>&1 || true

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources"

swiftc -parse-as-library "$ROOT_DIR"/Sources/SimpleImageViewer/*.swift \
  -o "$EXECUTABLE" \
  -framework SwiftUI \
  -framework AppKit \
  -framework UniformTypeIdentifiers

cat > "$APP_BUNDLE/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>$BINARY_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>CFBundleDisplayName</key>
  <string>$APP_NAME</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>CFBundleShortVersionString</key>
  <string>0.1.0</string>
  <key>LSMinimumSystemVersion</key>
  <string>13.0</string>
  <key>CFBundleDocumentTypes</key>
  <array>
    <dict>
      <key>CFBundleTypeName</key>
      <string>Image</string>
      <key>CFBundleTypeRole</key>
      <string>Viewer</string>
      <key>LSHandlerRank</key>
      <string>Alternate</string>
      <key>LSItemContentTypes</key>
      <array>
        <string>public.image</string>
      </array>
    </dict>
  </array>
</dict>
</plist>
PLIST

open_app() {
  if [[ "$#" -gt 0 ]]; then
    /usr/bin/open -n "$APP_BUNDLE" --args "$@"
  else
    /usr/bin/open -n "$APP_BUNDLE"
  fi
}

case "$MODE" in
  run)
    open_app "$@"
    ;;
  --verify)
    open_app "$@"
    sleep 2
    pgrep -f "$EXECUTABLE" >/dev/null
    echo "$APP_NAME is running"
    ;;
  --app-log)
    mkdir -p "$(dirname "$APP_LOG")"
    touch "$APP_LOG"
    open_app "$@"
    tail -f "$APP_LOG"
    ;;
  --debug)
    lldb "$EXECUTABLE"
    ;;
esac
