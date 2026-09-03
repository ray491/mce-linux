#!/usr/bin/env bash
# One-time root setup for Minecraft Education (Waydroid) — step 1 of 2.
# Run via pkexec/sudo:  bash waydroid-setup.sh <DATA_DIR>
#
# Does (all idempotent):
#   1. load the binder kernel module (+ persist across reboots, mount binderfs)
#   2. install Waydroid from the official repo if missing
#   3. redirect /var/lib/waydroid into <DATA_DIR>/waydroid (isolation)
#   4. download the Android image with Google apps (first run only, ~2 GB)
#   5. enable + start the waydroid-container systemd service
#
# NOTE: this does NOT boot Android. The container only boots when a Waydroid
# session attaches (step 2 of 2, run by the launcher as the normal user).
set -uo pipefail

DATA_DIR="${1:?data dir required}"
WAYDROID_ROOT="/var/lib/waydroid"

log() { echo "[setup] $*"; }
die() { log "FATAL: $*"; exit 1; }

# --- 1. Kernel binder ---------------------------------------------------------
if [ ! -e /dev/binder ] && [ ! -e /dev/binderfs ]; then
  log "Loading binder kernel module..."
  modprobe binder_linux || die "failed to load the binder_linux module (unsupported kernel?)"
fi
mkdir -p /etc/modules-load.d
grep -qxF binder_linux /etc/modules-load.d/waydroid.conf 2>/dev/null || \
  echo "binder_linux" >> /etc/modules-load.d/waydroid.conf
mkdir -p /dev/binderfs
mount -t binder binder /dev/binderfs >/dev/null 2>&1 || true

# --- 2. Waydroid --------------------------------------------------------------
if ! command -v waydroid >/dev/null 2>&1; then
  log "Adding the official Waydroid apt repository..."
  command -v curl >/dev/null 2>&1 || \
    DEBIAN_FRONTEND=noninteractive apt-get install -y curl ca-certificates
  bash <(curl --proto '=https' --tlsv1.2 -Sf https://repo.waydro.id) || \
    die "failed to add the Waydroid repository"
  log "Installing Waydroid..."
  DEBIAN_FRONTEND=noninteractive apt-get install -y waydroid || \
    die "failed to install Waydroid"
fi

# adb is needed to install the game into Android
command -v adb >/dev/null 2>&1 || \
  DEBIAN_FRONTEND=noninteractive apt-get install -y adb

# --- 3. Isolated data dir ------------------------------------------------------
# Keep the Android image + user data inside the app's data folder so that
# deleting ~/.local/share/mc-education removes everything Waydroid owns.
if [ ! -e "$WAYDROID_ROOT" ]; then
  log "Redirecting Waydroid data into $DATA_DIR/waydroid ..."
  mkdir -p "$DATA_DIR/waydroid"
  ln -s "$DATA_DIR/waydroid" "$WAYDROID_ROOT" || die "could not create $WAYDROID_ROOT symlink"
fi

# --- 4. Android image (first run only) -----------------------------------------
if [ ! -f "$WAYDROID_ROOT/images/system.img" ]; then
  log "Downloading the Android image with Google apps (~2 GB, one time only)..."
  waydroid init -s GAPPS || die "waydroid init failed"
fi

# --- 5. Container service (hosts the root DBus service; auto-starts at boot) ----
# The waydroid deb can auto-start this service during install, BEFORE the Android
# images exist, leaving a stale process holding the service. Stop it and start
# fresh now that the images are in place. The actual Android boot happens when
# the launcher starts a session (it calls the DBus Start method of this service).
systemctl stop waydroid-container >/dev/null 2>&1 || true
systemctl enable waydroid-container >/dev/null 2>&1 || true
systemctl restart waydroid-container || die "failed to start waydroid-container"

log "Setup complete."