#!/usr/bin/env bash
# Installs a menu entry and the icon of TimeLog for the current user (Linux).
# Needed on Wayland, where the window / taskbar icon comes from the .desktop file.
# Usage: linux/install-desktop-entry.sh [path/to/bundle]   (default: release build)
set -euo pipefail
cd "$(dirname "$0")/.."
BUNDLE="$(realpath "${1:-build/linux/x64/release/bundle}")"
APP_ID="ch.lukas.timelog"
[ -x "$BUNDLE/timelog" ] || { echo "Build first: flutter build linux --release" >&2; exit 1; }

ICON_DIR="$HOME/.local/share/icons/hicolor/512x512/apps"
mkdir -p "$ICON_DIR" "$HOME/.local/share/applications"
cp assets/logo.png "$ICON_DIR/$APP_ID.png"

cat > "$HOME/.local/share/applications/$APP_ID.desktop" <<DESKTOP
[Desktop Entry]
Type=Application
Name=TimeLog
Comment=Heures, journal de travail et notes
Exec="$BUNDLE/timelog"
Path=$BUNDLE
Icon=$APP_ID
Terminal=false
Categories=Office;Utility;
StartupWMClass=$APP_ID
DESKTOP

update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true
gtk-update-icon-cache -q "$HOME/.local/share/icons/hicolor" 2>/dev/null || true
echo "Installed $APP_ID.desktop -> $BUNDLE/timelog"
