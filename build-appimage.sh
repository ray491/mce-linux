#!/usr/bin/env bash
# Builds the Minecraft Education (Waydroid) AppImage.
# Usage: ./build-appimage.sh
set -euo pipefail
cd "$(dirname "$0")"

ARCH="x86_64"
NAME="Minecraft-Education-Linux"
OUT="$NAME-$ARCH.AppImage"
TOOLS="tools"
APPDIR="AppDir"
APPIMAGETOOL_URL="https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-$ARCH.AppImage"

mkdir -p "$TOOLS"

# --- appimagetool -------------------------------------------------------------
if [ ! -x "$TOOLS/appimagetool-$ARCH.AppImage" ]; then
  echo "==> Downloading appimagetool…"
  curl -fL "$APPIMAGETOOL_URL" -o "$TOOLS/appimagetool-$ARCH.AppImage"
  chmod +x "$TOOLS/appimagetool-$ARCH.AppImage"
fi

# --- assemble AppDir ----------------------------------------------------------
echo "==> Assembling AppDir…"
rm -rf "$APPDIR"
mkdir -p \
  "$APPDIR/usr/bin" \
  "$APPDIR/usr/lib/mc-education" \
  "$APPDIR/usr/share/applications" \
  "$APPDIR/usr/share/icons/hicolor/512x512/apps"

install -m 0755 src/AppRun            "$APPDIR/AppRun"
install -m 0755 src/mc-education      "$APPDIR/usr/bin/mc-education"
install -m 0755 src/waydroid-setup.sh  "$APPDIR/usr/lib/mc-education/waydroid-setup.sh"
install -m 0644 src/minecraft-education.desktop \
  "$APPDIR/minecraft-education.desktop"
install -m 0644 src/minecraft-education.desktop \
  "$APPDIR/usr/share/applications/minecraft-education.desktop"
install -m 0644 src/minecraft-education.png \
  "$APPDIR/minecraft-education.png"
install -m 0644 src/minecraft-education.png \
  "$APPDIR/usr/share/icons/hicolor/512x512/apps/minecraft-education.png"

# --- build --------------------------------------------------------------------
echo "==> Building $OUT…"
# --appimage-extract-and-run: works even where FUSE is unavailable
ARCH="$ARCH" "$TOOLS/appimagetool-$ARCH.AppImage" --appimage-extract-and-run "$APPDIR" "$OUT"
echo
echo "Done: $OUT"
echo "Run it (or double-click it). First launch downloads ~2.4 GB and asks for"
echo "your admin password once (setup)."