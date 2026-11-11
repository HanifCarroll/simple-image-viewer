#!/usr/bin/env bash
set -euo pipefail

APP_NAME="Folder Image Viewer"
LEGACY_APP_NAME="Simple Image Viewer"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE_APP="$ROOT_DIR/dist/$APP_NAME.app"
INSTALL_DIR="${INSTALL_DIR:-/Applications}"
TARGET_APP="$INSTALL_DIR/$APP_NAME.app"
LEGACY_TARGET_APP="$INSTALL_DIR/$LEGACY_APP_NAME.app"
CLI_NAME="${CLI_NAME:-fiv}"
LEGACY_CLI_NAME="siv"
BIN_DIR="${BIN_DIR:-$HOME/.local/bin}"
TARGET_CLI="$BIN_DIR/$CLI_NAME"
LEGACY_TARGET_CLI="$BIN_DIR/$LEGACY_CLI_NAME"
UPDATED_LEGACY_CLI=0
SKIPPED_LEGACY_CLI=0

if [[ ! -d "$SOURCE_APP" ]]; then
  "$ROOT_DIR/script/build_and_run.sh" --verify
fi

if [[ ! -d "$INSTALL_DIR" || ! -w "$INSTALL_DIR" ]]; then
  echo "Install directory is not writable: $INSTALL_DIR" >&2
  echo "Set INSTALL_DIR to a writable Applications folder, or rerun with permissions." >&2
  exit 1
fi

mkdir -p "$BIN_DIR"

if [[ ! -d "$BIN_DIR" || ! -w "$BIN_DIR" ]]; then
  echo "CLI install directory is not writable: $BIN_DIR" >&2
  echo "Set BIN_DIR to a writable directory on PATH." >&2
  exit 1
fi

pkill -f "$TARGET_APP/Contents/MacOS" >/dev/null 2>&1 || true
pkill -f "$LEGACY_TARGET_APP/Contents/MacOS" >/dev/null 2>&1 || true
rm -rf "$TARGET_APP" "$LEGACY_TARGET_APP"
ditto "$SOURCE_APP" "$TARGET_APP"
rm -rf "$SOURCE_APP"

target_app_literal="$(printf "%q" "$TARGET_APP")"

write_cli() {
  local target_cli="$1"
  cat > "$target_cli" <<SH
#!/usr/bin/env bash
set -euo pipefail

app=\${FIV_APP:-\${SIV_APP:-$target_app_literal}}

if [[ "\$#" -eq 0 ]]; then
  set -- "."
fi

if [[ ! -d "\$app" ]]; then
  echo "Folder Image Viewer app not found: \$app" >&2
  echo "Set FIV_APP=/path/to/Folder Image Viewer.app or rerun script/install_app.sh." >&2
  exit 1
fi

exec /usr/bin/open -n -a "\$app" "\$@"
SH
  chmod +x "$target_cli"
}

write_cli "$TARGET_CLI"

# Only replace an existing siv when it launches this app (old or new name).
cli_points_at_this_app() {
  local cli="$1" pattern="(Folder|Simple) Image Viewer\.app"
  if [[ -L "$cli" ]]; then
    [[ "$(readlink "$cli")" =~ $pattern ]] && return 0
  fi
  [[ -f "$cli" ]] && grep -qE "(Folder|Simple)( |\\\\ )Image( |\\\\ )Viewer\.app" "$cli"
}

if [[ "$CLI_NAME" != "$LEGACY_CLI_NAME" && ( -e "$LEGACY_TARGET_CLI" || -L "$LEGACY_TARGET_CLI" ) ]]; then
  if cli_points_at_this_app "$LEGACY_TARGET_CLI"; then
    rm -f "$LEGACY_TARGET_CLI"
    write_cli "$LEGACY_TARGET_CLI"
    UPDATED_LEGACY_CLI=1
  else
    SKIPPED_LEGACY_CLI=1
  fi
fi

/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister \
  -f "$TARGET_APP" >/dev/null 2>&1 || true

mdimport "$TARGET_APP" >/dev/null 2>&1 || true

echo "Installed $TARGET_APP"
echo "Installed $CLI_NAME command at $TARGET_CLI"
if [[ "$UPDATED_LEGACY_CLI" == "1" ]]; then
  echo "Updated legacy $LEGACY_CLI_NAME command at $LEGACY_TARGET_CLI"
elif [[ "$SKIPPED_LEGACY_CLI" == "1" ]]; then
  echo "Skipped $LEGACY_TARGET_CLI: it doesn't point at $APP_NAME, so it was left unchanged."
fi

case ":$PATH:" in
  *":$BIN_DIR:"*) ;;
  *) echo "Add $BIN_DIR to PATH to run $CLI_NAME from any shell." ;;
esac
