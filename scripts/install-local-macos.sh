#!/usr/bin/env bash
# Build tty7 from this checkout and replace only the executable inside the
# installed macOS app. This is the fast self-use path; use bundle-macos.sh when
# Info.plist, icons, completion assets, entitlements, or distribution artifacts
# change.
set -euo pipefail

usage() {
    cat <<'EOF'
Usage: scripts/install-local-macos.sh --gui-only|--full

  --gui-only  Restart only the GUI and keep the existing daemon/shells alive.
              Use for src/ui and src/terminal-only changes.
  --full      Stop the daemon before replacement. This ends every tty7 shell.
              Use for src/daemon, PTY, environment, or protocol changes.

Environment overrides:
  TTY7_APP_PATH      Installed app (default: /Applications/tty7.app)
  RUST_TOOLCHAIN     Rust toolchain (default: 1.97.1)
  TTY7_BACKUP_DIR    Binary backup directory
EOF
}

MODE="${1:-}"
case "$MODE" in
    --gui-only|--full) ;;
    -h|--help) usage; exit 0 ;;
    *) usage >&2; exit 2 ;;
esac

if [[ "$(uname -s)" != "Darwin" ]]; then
    echo "error: this installer only supports macOS" >&2
    exit 1
fi

case "$(uname -m)" in
    arm64) TARGET="aarch64-apple-darwin" ;;
    x86_64) TARGET="x86_64-apple-darwin" ;;
    *) echo "error: unsupported architecture: $(uname -m)" >&2; exit 1 ;;
esac

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="${TTY7_APP_PATH:-/Applications/tty7.app}"
APP_BIN="$APP/Contents/MacOS/tty7"
TOOLCHAIN="${RUST_TOOLCHAIN:-1.97.1}"
BACKUP_DIR="${TTY7_BACKUP_DIR:-$HOME/Library/Application Support/tty7-local-build-backups}"
BUILD_BIN="$ROOT/target/$TARGET/release/tty7"

if [[ ! -x "$APP_BIN" ]]; then
    echo "error: installed tty7 executable not found: $APP_BIN" >&2
    exit 1
fi
for tool in cargo codesign osascript open pgrep; do
    command -v "$tool" >/dev/null || {
        echo "error: required command not found: $tool" >&2
        exit 1
    }
done

printf '[1/6] Building release binary (%s, Rust %s)\n' "$TARGET" "$TOOLCHAIN"
cd "$ROOT"
cargo "+$TOOLCHAIN" build --release --locked --target "$TARGET"
[[ -x "$BUILD_BIN" ]] || {
    echo "error: build completed without expected binary: $BUILD_BIN" >&2
    exit 1
}

printf '[2/6] Closing the tty7 GUI\n'
osascript -e 'if application id "com.github.tty7" is running then tell application id "com.github.tty7" to quit' >/dev/null
for _ in {1..50}; do
    pgrep -f "^${APP_BIN}$" >/dev/null || break
    sleep 0.1
done
if pgrep -f "^${APP_BIN}$" >/dev/null; then
    echo "error: tty7 GUI did not quit; close it manually and retry" >&2
    exit 1
fi

if [[ "$MODE" == "--full" ]]; then
    printf '[3/6] Stopping daemon (all tty7 shells will end)\n'
    "$APP_BIN" --stop-daemon
else
    printf '[3/6] Keeping the existing daemon and shell sessions alive\n'
fi

STAMP="$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP_DIR/$STAMP"
printf '[4/6] Backing up and replacing the installed executable\n'
cp -p "$APP_BIN" "$BACKUP_DIR/$STAMP/tty7"
cp "$BUILD_BIN" "$APP_BIN"
chmod 755 "$APP_BIN"

printf '[5/6] Applying an ad-hoc signature\n'
codesign --force --deep --sign - "$APP"
codesign --verify --deep --strict --verbose=2 "$APP"

touch "$APP"
printf '[6/6] Launching %s\n' "$APP"
open "$APP"

printf 'OK: installed %s\n' "$(shasum -a 256 "$APP_BIN" | awk '{print $1}')"
printf 'Backup: %s\n' "$BACKUP_DIR/$STAMP/tty7"
printf 'Mode: %s\n' "$MODE"
