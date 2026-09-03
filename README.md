# Minecraft Education for Linux

> A self-contained **AppImage** that installs and runs **Minecraft Education Edition** on x86_64 Linux by booting Android inside [Waydroid](https://waydro.id/) — fully isolated, with no Google account required and no manual configuration.

[![Platform: Linux x86_64](https://img.shields.io/badge/platform-Linux%20x86__64-blue)](#requirements)
[![Session: Wayland](https://img.shields.io/badge/session-Wayland-4c1)](#requirements)
[![Runtime: AppImage](https://img.shields.io/badge/runtime-AppImage-orange)](#quick-start)
[![Android: Waydroid (LineageOS 20)](https://img.shields.io/badge/Android-Waydroid%20%2F%20LineageOS%2020-3ddc84)](#architecture)
[![Shell: Bash](https://img.shields.io/badge/implemented%20in-Bash-4eaa25)](#repository-layout)

---

## Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Architecture](#architecture)
- [Requirements](#requirements)
- [Quick Start](#quick-start)
- [First Run](#first-run)
- [Usage](#usage)
- [Session Lifecycle & Performance](#session-lifecycle--performance)
- [Data Isolation & System Footprint](#data-isolation--system-footprint)
- [Security & Permissions Model](#security--permissions-model)
- [Troubleshooting](#troubleshooting)
- [FAQ](#faq)
- [Repository Layout](#repository-layout)
- [Building from Source](#building-from-source)
- [Contributing](#contributing)
- [Disclaimer & Legal](#disclaimer--legal)
- [License](#license)

---

## Overview

Minecraft Education Edition ships for Windows, macOS, ChromeOS, and Android — but not Linux. This project closes that gap with a **single portable AppImage** that:

1. Sets up [Waydroid](https://waydro.id/) (Android-in-a-container) automatically on first run,
2. Installs the official Minecraft Education Android app (split APK bundle) into it,
3. Launches the game **in its own window** on your Linux desktop.

The entire Android environment lives inside the app's own data directory, so the host system stays clean: uninstalling is a single command. No Google account, no Play Store registration, no manual Waydroid configuration.

---

## Features

| Capability | Detail |
|---|---|
| **Single-file distribution** | One ~200 KB AppImage; the Android image (~2 GB) and game package (~413 MB) are fetched on first run only. |
| **Fully isolated** | All Android data (image, user data, installed apps) lives under `~/.local/share/mc-education`; `/var/lib/waydroid` is redirected there via symlink. |
| **No Google account required** | The game is installed with `adb install-multiple` — the same mechanism the Play Store uses — straight from the APK bundle. |
| **Windowed or fullscreen** | Defaults to a dedicated game window; `--fullscreen` switches to the full Android UI. |
| **Fast relaunch** | A healthy Android session is **reused** instead of rebooted: repeat launches complete in ~1 second (see [Session Lifecycle](#session-lifecycle--performance)). |
| **Self-healing cleanup** | Every launch validates the session and cleans up stale containers, dead-session tracking, and leftover processes before booting. |
| **Robust adb integration** | Host-side key provisioning (Android's proprietary key format via `adb keygen`) — **no root access required** for install or launch. |
| **Diagnostics built in** | `--check` performs a full environment audit; detailed logs are written to `~/.local/share/mc-education/logs/`. |
| **Idempotent setup** | All system-level steps are safe to re-run; setup never repeats completed work. |

---

## Architecture

```
┌──────────────────────────────────────────────────────────────────────┐
│  AppImage (portable, ~200 KB)                                        │
│  ┌────────────────────────────────────────────────────────────────┐  │
│  │  AppRun → mc-education (orchestrator, runs as the user)        │  │
│  │                                                                │  │
│  │  ┌──────────────┐   ┌───────────────┐   ┌───────────────────┐  │  │
│  │  │ download_apk │   │ prepare_adb_key│  │ start_session     │  │  │
│  │  │ (APKPure,    │   │ (adb keygen → │  │ (reuse healthy    │  │  │
│  │  │ ~413 MB,     │   │  host-side    │  │  session, or cold │  │  │
│  │  │ split APKs)  │   │  key write)   │  │  boot via setsid) │  │  │
│  │  └──────┬───────┘   └──────┬────────┘  └─────────┬─────────┘  │  │
│  │         │                  │                     │            │  │
│  │         ▼                  ▼                     ▼            │  │
│  │  ┌──────────────────────────────────────────────────────┐      │  │
│  │  │  waydroid session (boots Android 13 / LineageOS 20)  │      │  │
│  │  │  ├─ adb install-multiple  (5 APK parts, as user)     │      │  │
│  │  │  └─ waydroid app launch  (creates the visible window)│      │  │
│  │  └──────────────────────────────────────────────────────┘      │  │
│  └────────────────────────────────────────────────────────────────┘  │
│                                                                      │
│  First run only (one admin prompt via pkexec/sudo):                  │
│   waydroid-setup.sh → binder module · Waydroid apt install ·         │
│   waydroid init -s GAPPS (~2 GB) · waydroid-container service        │
└──────────────────────────────────────────────────────────────────────┘
```

**Key design decisions:**

- **adb for install, platform service for launch.** The game is installed over `adb` (`install-multiple` handles split APKs natively). It is *launched* with `waydroid app launch`, which routes through Waydroid's platform service — the only path that actually creates a visible window on the host desktop. A raw `adb am start` runs the activity but produces **no window**, so it is deliberately avoided for launching.
- **Key provisioning before boot.** Android's adbd reads `/data/misc/adb/adb_keys` exactly once, at boot, and only accepts keys in **Android's proprietary pubkey format** (`ANDROID_PUBKEY_ENCODED_SIZE`). The launcher generates the key with `adb keygen` and writes it host-side (into the user's own data directory) *before* the session starts — no root, no restart race.
- **The Android image ships native x86_64 binaries**, so no ARM translation layer is needed.

---

## Requirements

| Requirement | Detail |
|---|---|
| **CPU / Arch** | x86_64 (AMD64) |
| **OS** | Ubuntu 22.04+ / Debian 12+ (tested on Ubuntu 26.04) |
| **Display server** | **Wayland** (Ubuntu default). On X11, run inside [Weston](https://gitlab.freedesktop.org/wayland/weston) or pass `--force-x11` at your own risk. |
| **Disk** | ~6 GB free (Android image ~2 GB + game ~1 GB + working space) |
| **RAM** | ~4 GB |
| **Kernel** | Must ship the `binder_linux` module (present in stock Ubuntu/Debian kernels). Verify with `--check`. |
| **Credentials** | Your admin password **once**, on first run (setup). |
| **Network** | Internet on first launch (~2.4 GB total download). |
| **Build prerequisites** | `curl` + `python3` (only needed to build the AppImage yourself). |

> Run `./Minecraft-Education-Linux-x86_64.AppImage --check` to audit your machine against all of the above without changing anything.

---

## Quick Start

```bash
# Build it
./build-appimage.sh

# Run it (or double-click the AppImage in your file manager)
./Minecraft-Education-Linux-x86_64.AppImage
```

That's it. The first launch performs one-time setup (below); every launch after that is automatic.

---

## First Run

The first launch takes ~5–10 minutes and happens in this order:

1. **Downloads the game package** (~413 MB) from APKPure and extracts the 5 APK parts.
2. **Asks for your admin password once** (graphical `pkexec` dialog; `--sudo` for terminal environments) and runs one-time setup:
   - loads the `binder_linux` kernel module and persists it across reboots,
   - installs Waydroid from the official `repo.waydro.id` repository,
   - downloads the Android image with Google apps (~2 GB),
   - enables the `waydroid-container` systemd service.
3. **Boots the Android session** and waits until Android reports fully booted.
4. **Installs Minecraft Education** via `adb install-multiple` (no Google account, no further password prompts).
5. **Launches the game** in its own window.

Sign in inside the app with your Microsoft 365 Education account as usual.

---

## Usage

```bash
./Minecraft-Education-Linux-x86_64.AppImage [options]
```

| Flag | Description |
|---|---|
| *(no flags)* | Install (if needed) and launch the game. |
| `--help`, `-h` | Show the built-in help. |
| `--check` | Audit the environment (OS, Wayland, binder module, Waydroid, images, disk space) without changing anything. |
| `--repair` | Re-download the game package and reinstall it into Android. |
| `--fullscreen` | Run inside the fullscreen Android UI instead of a dedicated window. |
| `--reset` | Delete **all** app data (`~/.local/share/mc-education`) and exit. |
| `--sudo` | Use `sudo` instead of `pkexec` for the admin step (e.g., terminal-only environments). |
| `--force-x11` | Skip the Wayland check (Waydroid requires Wayland; only use with Weston). |

To fully shut down the background Android session after playing:

```bash
waydroid session stop
```

---

## Session Lifecycle & Performance

Launch speed is handled by a **health check + reuse** strategy:

```
launch ──► is Android already running AND answering over adb?
              │
              ├─ yes ──► reuse the session        (~1 second)
              │
              └─ no ───► stop stale session/container (if any)
                         boot a fresh session      (~10–15 seconds warm,
                          first ever boot: several minutes)
```

- The session is started with `setsid`, so it **keeps running in the background after the launcher exits** — the next launch finds it and reuses it.
- A session is considered *healthy* only if Waydroid reports it `RUNNING` **and** Android answers `sys.boot_completed=1` over adb. Anything less triggers the clean-boot path.
- Android's screen-off is disabled after install (`screen_off_timeout` max + `stay_on_while_plugged_in`), so the container **never suspends or freezes** — eliminating the class of bugs that plagued earlier iterations (see [Troubleshooting](#troubleshooting)).
- The background session consumes RAM until you stop it (`waydroid session stop`) or reboot — the deliberate trade-off for instant relaunch.

---

## Data Isolation & System Footprint

Everything the app owns lives in one directory:

| Path | Contents |
|---|---|
| `~/.local/share/mc-education/apk/` | Downloaded game package + extracted APK parts + install state markers |
| `~/.local/share/mc-education/waydroid/` | Android image, user data, installed apps |
| `~/.local/share/mc-education/adbkey*` | adb keypair (Android-format) used for installs |
| `~/.local/share/mc-education/logs/` | `setup.log`, `session.log`, `install.log` |

`/var/lib/waydroid` is a **symlink** into `~/.local/share/mc-education/waydroid/`, so **deleting `~/.local/share/mc-education` removes everything Waydroid owns**.

The only system-level changes (made by the one-time root setup, all reversible):

| Change | Reversible via |
|---|---|
| `binder_linux` kernel module auto-load (`/etc/modules-load.d/waydroid.conf`) | `--reset` handles the symlink; remove the conf file manually if desired |
| `waydroid` apt package + `repo.waydro.id` apt source | `sudo apt remove waydroid` + delete the apt source file |
| `waydroid-container` systemd service (enabled at boot) | `sudo systemctl disable --now waydroid-container` |

**Uninstall (complete):**

```bash
./Minecraft-Education-Linux-x86_64.AppImage --reset    # removes all app data
rm Minecraft-Education-Linux-x86_64.AppImage            # removes the launcher
```

---

## Security & Permissions Model

| Concern | Approach |
|---|---|
| **Least privilege** | The launcher itself runs entirely as the **normal user**. Root (`pkexec`/`sudo`) is invoked only for one-time system setup and emergency container cleanup — never for game install, launch, or adb operations. |
| **adb key handling** | A dedicated keypair is generated with `adb keygen` and stored in the app's private data dir (not your personal `~/.android`). The container only ever sees the public half, written with shell-readable permissions (mode `0640`, group `shell`) that adbd can actually read. |
| **No Google account data** | Install happens via adb from the downloaded APK bundle — no Play Store login, no GSF registration on your host. |
| **Network surface** | The app downloads from APKPure (game package) and `repo.waydro.id` / SourceForge (Waydroid + Android image) only. In-game sign-in talks to Microsoft's official services, as on any platform. |
| **Isolation** | Android runs in an LXC container whose data root is confined to your home directory; removing it removes the entire Android environment. |
| **Auditability** | Every setup step logs to `~/.local/share/mc-education/logs/`; `--check` reports exact environment state at any time. |

---

## Troubleshooting

> Logs for every component live in `~/.local/share/mc-education/logs/` (`setup.log`, `session.log`, `install.log`). When in doubt, run the AppImage from a terminal and read the output.

| Symptom | Cause & Resolution |
|---|---|
| **Nothing happens when double-clicking** | Run from a terminal to see output: `./Minecraft-Education-Linux-x86_64.AppImage`. Check the logs under `~/.local/share/mc-education/logs/`. |
| **"No Wayland session detected"** | You're on X11. Waydroid requires Wayland — start Weston and launch the AppImage from inside it, or pass `--force-x11` at your own risk. |
| **"failed to load the binder_linux module"** | Your kernel lacks the Android binder driver. Run `--check` to confirm. Stock Ubuntu/Debian kernels include it; custom or older kernels may not. |
| **Game runs but no window appears** | Ensure you're launching with the current build. `waydroid app launch` (used by the launcher) creates the window; a raw `adb am start` does **not**. If the window still doesn't appear, check your compositor/taskbar and the session log. |
| **"adb: device unauthorized"** | adbd only accepts keys in **Android's proprietary pubkey format** (`adb keygen`, not `ssh-keygen`), and it reads them **once at boot**. The launcher handles both. If it ever happens anyway: delete `~/.local/share/mc-education/adbkey*` and re-run — the key is re-provisioned before the next boot. |
| **"Couldn't get LXC status. Assuming STOPPED" in waydroid.log** | A known Waydroid quirk on some kernels: after Android suspends (~70 s idle) the container is frozen, and `lxc-info` then fails to report state — making `waydroid status`/`shell`/`app launch` believe the container is STOPPED while it is actually healthy. The launcher prevents the freeze outright by disabling Android's screen-off, and never relies on `lxc-info` for the install path (it uses adb). |
| **"RuntimeError: Already tracking a session"** | A previous session died uncleanly but the container service still tracks it. The launcher detects and clears this by restarting the container service and killing any leftover container directly (`lxc-stop -k`), which also survives the service's rare "Too many open files" failure mode after very long uptimes. |
| **Slow launches (>1 min)** | This is the **cold-boot** path (no healthy session exists). Repeat launches should reuse the session in ~1 s. If every launch cold-boots, the session is dying between launches — check `session.log`. |
| **On-screen keyboard pops up** | Inside Android (Waydroid shell → Settings → System → Languages & input → Physical keyboard), disable "Use on-screen keyboard". |
| **Sign-in problems in-game** | Minecraft Education requires a valid **Microsoft 365 Education** account. |
| **Sluggish gameplay** | Games run best in fullscreen: `--fullscreen`. |

---

## FAQ

**Do I need a Google account?**
No. The game is installed from the APK bundle over adb, without touching Google Play.

**Does Minecraft Education run natively?**
The Android build ships x86_64 binaries, so there is no ARM translation overhead. Performance depends on your GPU/Wayland compositor; fullscreen mode generally performs best.

**Where is the game downloaded from?**
APKPure, a third-party mirror of the free Play Store app (see [Disclaimer](#disclaimer--legal)). In-game sign-in still uses your official Microsoft Education account.

**Does this touch my personal adb keys?**
No. The launcher generates a dedicated keypair inside `~/.local/share/mc-education/` and registers it for the Waydroid session only.

**Why does the app need admin rights at all?**
Exactly three one-time operations require root: loading a kernel module (`binder_linux`), installing the Waydroid apt package, and enabling its systemd service. Everything else — install, launch, updates — runs as your user.

**How do I update the game?**
Minecraft Education updates itself inside Android. To force a clean reinstall: `./Minecraft-Education-Linux-x86_64.AppImage --repair`.

**Can I move the AppImage around?**
Yes — it is fully portable. App data stays in `~/.local/share/mc-education`, independent of where the AppImage file lives.

---

## Repository Layout

```
├── src/                        # Everything that ships inside the AppImage
│   ├── AppRun                  # AppImage entry point (sets APPDIR, execs launcher)
│   ├── mc-education            # Orchestrator: download, adb key, session, install, launch
│   ├── waydroid-setup.sh       # One-time root setup (binder, Waydroid, image, service)
│   ├── minecraft-education.desktop
│   └── minecraft-education.png # App icon (512×512)
├── build-appimage.sh           # Assembles AppDir and builds the AppImage
├── vendor/                     # (gitignored) game package — icon extraction only
├── tools/                      # (gitignored) downloaded appimagetool
└── README.md
```

---

## Building from Source

```bash
./build-appimage.sh
```

The build script:

1. Downloads `appimagetool` (once, into `tools/`),
2. Assembles `AppDir/` from `src/`,
3. Produces `Minecraft-Education-Linux-x86_64.AppImage` (~200 KB).

**Prerequisites:** `curl` and `python3` on the build machine. No build-time network access beyond the appimagetool download — the game package and Android image are fetched at **runtime**, on first launch.

> Note: if the output file is still mounted (an instance is running), the build fails with "Text file busy" — close any running instance first.

---

## Contributing

Contributions are welcome. Please keep changes consistent with the existing design:

- **Isolation first** — everything user-facing stays under `~/.local/share/mc-education`; no new global state without strong justification.
- **No new root paths** — prefer user-space mechanisms (adb, host-side key writes) over escalated ones.
- **Session reuse stays** — healthy sessions should be reused, not rebooted.
- **Verify end-to-end** — the failure modes here are subtle (key format, window creation, stale-session tracking). Test the full flow: fresh setup → install → launch → relaunch (reuse path).
- Shell scripts follow the existing style: `set -uo pipefail`, POSIX-friendly bash, `log`/`die` helpers, `--check`-visible state.

Before submitting, run:

```bash
bash -n src/mc-education src/waydroid-setup.sh src/AppRun   # syntax check
./build-appimage.sh                                          # must build clean
```

---

## Disclaimer & Legal

- **Minecraft Education** is a trademark of Microsoft Corporation. This project is an independent, community-made launcher and is **not affiliated with, endorsed by, or sponsored by Microsoft or Mojang Studios**.
- The game package is fetched from **APKPure**, a third-party mirror of the free Google Play app. Downloading and running it is at your own discretion; verify the checksum/source if you require supply-chain guarantees.
- A valid **Microsoft 365 Education** account is required to sign in and play, and is subject to Microsoft's terms of service.
- Waydroid is an independent open-source project; see [waydro.id](https://waydro.id/) for its licensing and documentation.

---

## License

This repository is provided as open source for the community. The launcher code and build scripts are distributed under the terms of the license file in this repository (if present); the game itself, Android image, and third-party tooling remain property of their respective owners. If no `LICENSE` file is present, contact the maintainer before redistributing.

---

## Support

- **Bugs & issues:** open a GitHub issue and attach the relevant log from `~/.local/share/mc-education/logs/` plus the output of `./Minecraft-Education-Linux-x86_64.AppImage --check`.
- **Diagnostics:** the `--check` flag plus the three log files cover ~all failure modes; include them for fastest triage.