#!/usr/bin/env bash
set -euo pipefail

APP_NAME="Simple Image Viewer"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE_APP="$ROOT_DIR/dist/$APP_NAME.app"
INSTALL_DIR="${INSTALL_DIR:-/Applications}"
TARGET_APP="$INSTALL_DIR/$APP_NAME.app"

if [[ ! -d "$SOURCE_APP" ]]; then
  "$ROOT_DIR/script/build_and_run.sh" --verify
fi

if [[ ! -d "$INSTALL_DIR" || ! -w "$INSTALL_DIR" ]]; then
  echo "Install directory is not writable: $INSTALL_DIR" >&2
  echo "Set INSTALL_DIR to a writable Applications folder, or rerun with permissions." >&2
  exit 1
fi

pkill -f "$TARGET_APP/Contents/MacOS" >/dev/null 2>&1 || true
rm -rf "$TARGET_APP"
ditto "$SOURCE_APP" "$TARGET_APP"
rm -rf "$SOURCE_APP"

/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister \
  -f "$TARGET_APP" >/dev/null 2>&1 || true

mdimport "$TARGET_APP" >/dev/null 2>&1 || true

echo "Installed $TARGET_APP"
