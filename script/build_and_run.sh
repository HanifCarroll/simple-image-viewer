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
VERIFY_FIXTURE_DIR="$DIST_DIR/verify-fixtures"
VERIFY_NESTED_DIR="$VERIFY_FIXTURE_DIR/nested"
VERIFY_HELPER="$DIST_DIR/verify-image-discovery"
MODE="${1:-run}"
VERIFY_APP_PID=""

cd "$ROOT_DIR"

if [[ "$MODE" != "run" && "$MODE" != "--verify" && "$MODE" != "--debug" && "$MODE" != "--app-log" ]]; then
  echo "usage: $0 [run|--verify|--debug|--app-log] [image-or-folder]" >&2
  exit 2
fi

if [[ "$MODE" == "run" || "$MODE" == "--verify" || "$MODE" == "--debug" || "$MODE" == "--app-log" ]]; then
  shift || true
fi

pkill -f "$EXECUTABLE" >/dev/null 2>&1 || true

if [[ "$MODE" == "--verify" ]]; then
  cleanup_verify_app() {
    pkill -f "$EXECUTABLE" >/dev/null 2>&1 || true
  }
  trap cleanup_verify_app EXIT
fi

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources"

swiftc -parse-as-library "$ROOT_DIR"/Sources/SimpleImageViewer/*.swift \
  -o "$EXECUTABLE" \
  -framework SwiftUI \
  -framework AppKit \
  -framework UniformTypeIdentifiers

if [[ -f "$ROOT_DIR/Assets/AppIcon.png" ]]; then
  ICONSET="$DIST_DIR/AppIcon.iconset"
  rm -rf "$ICONSET"
  mkdir -p "$ICONSET"
  sips -z 16 16 "$ROOT_DIR/Assets/AppIcon.png" --out "$ICONSET/icon_16x16.png" >/dev/null
  sips -z 32 32 "$ROOT_DIR/Assets/AppIcon.png" --out "$ICONSET/icon_16x16@2x.png" >/dev/null
  sips -z 32 32 "$ROOT_DIR/Assets/AppIcon.png" --out "$ICONSET/icon_32x32.png" >/dev/null
  sips -z 64 64 "$ROOT_DIR/Assets/AppIcon.png" --out "$ICONSET/icon_32x32@2x.png" >/dev/null
  sips -z 128 128 "$ROOT_DIR/Assets/AppIcon.png" --out "$ICONSET/icon_128x128.png" >/dev/null
  sips -z 256 256 "$ROOT_DIR/Assets/AppIcon.png" --out "$ICONSET/icon_128x128@2x.png" >/dev/null
  sips -z 256 256 "$ROOT_DIR/Assets/AppIcon.png" --out "$ICONSET/icon_256x256.png" >/dev/null
  sips -z 512 512 "$ROOT_DIR/Assets/AppIcon.png" --out "$ICONSET/icon_256x256@2x.png" >/dev/null
  sips -z 512 512 "$ROOT_DIR/Assets/AppIcon.png" --out "$ICONSET/icon_512x512.png" >/dev/null
  sips -z 1024 1024 "$ROOT_DIR/Assets/AppIcon.png" --out "$ICONSET/icon_512x512@2x.png" >/dev/null
  iconutil -c icns "$ICONSET" -o "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
  rm -rf "$ICONSET"
fi

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
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
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
    /usr/bin/open -n -a "$APP_BUNDLE" "$@"
  else
    /usr/bin/open -n "$APP_BUNDLE"
  fi
}

launch_verify_app() {
  "$EXECUTABLE" "$@" >/dev/null 2>&1 &
  VERIFY_APP_PID="$!"
}

create_verify_fixtures() {
  rm -rf "$VERIFY_FIXTURE_DIR"
  mkdir -p "$VERIFY_FIXTURE_DIR" "$VERIFY_NESTED_DIR"

  if [[ ! -f "$ROOT_DIR/Assets/AppIcon.png" ]]; then
    echo "verify fixture source missing: Assets/AppIcon.png" >&2
    exit 1
  fi

  sips -s format png "$ROOT_DIR/Assets/AppIcon.png" --out "$VERIFY_FIXTURE_DIR/image-02.png" >/dev/null
  sips -s format jpeg "$ROOT_DIR/Assets/AppIcon.png" --out "$VERIFY_FIXTURE_DIR/image-10.jpg" >/dev/null
  sips -s format png "$ROOT_DIR/Assets/AppIcon.png" --out "$VERIFY_NESTED_DIR/image-03.png" >/dev/null
  printf '%s\n' "not an image" > "$VERIFY_FIXTURE_DIR/notes.txt"
}

verify_image_code_paths() {
  swiftc "$ROOT_DIR/Sources/SimpleImageViewer/ImageDiscovery.swift" \
    "$ROOT_DIR/Sources/SimpleImageViewer/ImageListPresentation.swift" \
    "$ROOT_DIR/Sources/SimpleImageViewer/ImageOpeningService.swift" \
    "$ROOT_DIR/script/verify_image_discovery.swift" \
    -o "$VERIFY_HELPER" \
    -framework AppKit
  "$VERIFY_HELPER" "$VERIFY_FIXTURE_DIR"
}

wait_for_app_pid() {
  local pid
  if [[ -n "$VERIFY_APP_PID" ]] && kill -0 "$VERIFY_APP_PID" >/dev/null 2>&1; then
    printf '%s\n' "$VERIFY_APP_PID"
    return 0
  fi

  for _ in {1..40}; do
    pid="$(pgrep -f "$EXECUTABLE" | head -n 1 || true)"
    if [[ -n "$pid" ]]; then
      printf '%s\n' "$pid"
      return 0
    fi
    sleep 0.25
  done
  return 1
}

stop_verify_app() {
  if [[ -n "$VERIFY_APP_PID" ]] && kill -0 "$VERIFY_APP_PID" >/dev/null 2>&1; then
    kill "$VERIFY_APP_PID" >/dev/null 2>&1 || true
    wait "$VERIFY_APP_PID" >/dev/null 2>&1 || true
    VERIFY_APP_PID=""
  fi

  pkill -f "$EXECUTABLE" >/dev/null 2>&1 || true
  for _ in {1..40}; do
    if ! pgrep -f "$EXECUTABLE" >/dev/null 2>&1; then
      return 0
    fi
    sleep 0.25
  done

  echo "$APP_NAME did not stop after verification smoke" >&2
  exit 1
}

window_title_for_pid() {
  osascript - "$1" <<'APPLESCRIPT'
on run argv
  set targetPid to item 1 of argv as integer
  tell application "System Events"
    tell (first process whose unix id is targetPid)
      if (count of windows) is 0 then return ""
      return title of window 1
    end tell
  end tell
end run
APPLESCRIPT
}

verify_app_opened_fixture() {
  local expected_title="$1"
  local pid
  local title

  pid="$(wait_for_app_pid)" || {
    echo "$APP_NAME did not start" >&2
    exit 1
  }

  for _ in {1..40}; do
    title="$(window_title_for_pid "$pid" 2>/dev/null || true)"
    if [[ "$title" == "$expected_title" ]]; then
      echo "$APP_NAME opened fixture image: $title"
      return 0
    fi
    sleep 0.25
  done

  echo "$APP_NAME started but did not show fixture image title: expected '$expected_title', got '${title:-<none>}'" >&2
  exit 1
}

case "$MODE" in
  run)
    open_app "$@"
    ;;
  --verify)
    create_verify_fixtures
    verify_image_code_paths
    launch_verify_app "$VERIFY_FIXTURE_DIR/image-10.jpg"
    verify_app_opened_fixture "image-10.jpg"
    stop_verify_app
    launch_verify_app "$VERIFY_FIXTURE_DIR"
    verify_app_opened_fixture "image-02.png"
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
