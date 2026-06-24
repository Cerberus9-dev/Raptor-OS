# Raptor OS
**Current version: v2.6.6**

A custom Bazzite-based Linux distribution built for gaming performance — F-22 HUD-inspired KDE theme, automatic GPU optimisation, low-latency audio, and a zero-terminal firstboot experience.

>  **HEAVY W.I.P — Feedback appreciated!**
>  **This is NOT a live OS.** Requires a separate drive, replacing your current OS, or dual booting. Minimum 40–50 GB free for dual boot. Can be run in a VM first for testing.

---

## System Requirements

| | Minimum | Recommended |
|---|---|---|
| **CPU** | 64-bit x86_64 | AMD Ryzen / Intel 10th gen+ |
| **RAM** | 8 GB | 16 GB |
| **Storage** | 40 GB SSD | 60 GB NVMe |
| **GPU** | AMD, NVIDIA, or Intel | AMD RDNA2+ or NVIDIA RTX |
| **Boot** | UEFI required | — |

---

## Installation

Download the latest ISO from [Internet Archive](https://archive.org/details/raptor-os_202605), then flash it to a USB drive:

- **[Rufus](https://rufus.ie/en/)** — select **DD image mode** + **GPT** partition scheme
- **[Ventoy](https://www.ventoy.net)**
- **[Fedora Media Writer](https://github.com/FedoraQt/MediaWriter)** — most reliable option

### Rebase from Bazzite (no reinstall needed)

```bash
# Step 1 — add the unverified image
rpm-ostree rebase ostree-unverified-registry:ghcr.io/cerberus9-dev/raptor-os:latest
systemctl reboot

# Step 2 — switch to the signed image
rpm-ostree rebase ostree-image-signed:docker://ghcr.io/cerberus9-dev/raptor-os:latest
systemctl reboot
```

> **Already on Raptor OS?** Open **Raptor Update Manager** → click **Update & Reboot**. Handles system image and Flatpak updates in one step.

---

## First Boot

Two dialogs appear on first login:

1. **Browser choice** — Firefox (pre-installed) or Brave (downloads ~100 MB from Flathub). Closing the dialog keeps Firefox.
2. **App picker** — 40+ optional apps across Communication, Productivity, Office, Creative, Development, Gaming, Privacy, and more. Everything can also be installed later from Discover.

---

## What's Included

### Pre-installed

| Category | Apps |
|---|---|
| **Communication** | Vesktop (Discord, native Wayland) |
| **Gaming** | Heroic Games Launcher, ProtonUp-Qt, Bottles, MangoHud, Gamemode, Protontricks, Wine, Winetricks |
| **Browser** | Firefox (memory-optimised policy: 64 MB cache, 4 processes, tab unloading) |
| **Media** | mpv |
| **System** | htop, Mission Center (Flatpak), Flatseal, KDE Partition Manager, BleachBit, Filelight |
| **Development** | Git, Node.js, Python 3, GCC, Make, CMake |

---

### Choose at First Boot

| Category | Apps |
|---|---|
| **Communication** | Telegram, Signal, Slack, Zoom, Thunderbird |
| **Productivity** | VSCodium ✓, ONLYOFFICE, Bitwarden, Joplin, MarkText, Calibre, Obsidian |
| **Office** | LibreOffice |
| **Creative** | GIMP, Inkscape, Krita, Darktable, Blender, Kdenlive, Shotcut, OBS Studio, Audacity, Boatswain |
| **Development** | Godot Engine, GitHub Desktop, Pods |
| **Gaming** | Lutris, Protontricks (Flatpak), Spotify, Plex, VLC, Cartridges, Ryujinx, RPCS3 |
| **Privacy & Security** | ProtonVPN, KeePassXC |
| **Media & Downloads** | FreeTube, Parabolic, Kooha, Clapper, Amberol |
| **Audio Production** | EasyEffects, Helvum, LMMS, Ardour |
| **System** | Warehouse, Impression, CoreCtrl, btop, Variety, GNOME Boxes, Warp, Flatsweep, Upscayl, Metadata Cleaner |

✓ = pre-ticked

---

## Performance

### GPU & CPU
- **Auto GPU detection** at boot — AMD, NVIDIA, Intel, hybrid; sets env vars, Vulkan ICD, CPU governor
- **Raptor Cortex** — GTK4 performance manager: Power Saving / Balanced / Performance modes with correct per-mode `vm.swappiness` (180/30/5), CPU governor, PCIe ASPM, NVMe power, and more
- **Game Mode** — suspends 17 background services on game launch (Baloo, Akonadi, KDE Connect, speech-dispatcher, etc.); resumes on exit
- **Optimize Memory Now** — reclaims real app memory (Firefox, Vesktop, Steam heap) via cgroup v2 `memory.reclaim`, not just kernel page caches
- **Gamemode daemon** — use `ENABLE_GAMEMODE=1 %command%` in Steam launch options
- **Kernel args** — `split_lock_detect=off`, `transparent_hugepage=madvise`, `nowatchdog`

### Audio
- **PipeWire** — 512-sample quantum (~10.7 ms); no static, resilient under GPU load
- **Auto-suspend disabled** — no pop/click between game sounds
- **Auto-restart** — crash recovery after suspend/resume without logout

### Network
- **BBR + CAKE** — lower ping variance under downloads
- **128 MB TCP buffers**, **socket busy-polling** (50 µs), **TCP fast-open**
- **Cloudflare DoT** — ~10 ms DNS vs ~40–80 ms ISP resolvers

### Memory
- **ZRAM** — zstd compressed swap, priority 100, `min(RAM/2, 8 GB)`
- **Background service caps** — Baloo 128 MB, Akonadi 256 MB, KDE Connect/tracker/kactivitymanagerd capped
- **`vm.min_free_kbytes=131072`**, **`vm.watermark_boost_factor=0`** (no reclaim bursts), **`sched_autogroup`**
- **journald capped** — 64 MB runtime, 200 MB disk
- **ModemManager masked** — zero overhead for unused cellular stack

### Input
- **USB autosuspend disabled** for all HID devices — no input spikes
- **Controller udev rules** — DualSense, Steam Controller, Xbox, Valve Index

---

## Window Management (Windows-style)
- **Buttons** — Minimize, Maximize, Close on the right; App Menu on the left
- **Title bar double-click** — maximises the window
- **Edge snap** — drag a window to a screen edge to snap/tile (Aero Snap equivalent)
- **Click to raise** — clicking anywhere on a window brings it to front

---

## Built With
- [BlueBuild](https://blue-build.org) — custom image build system
- [Bazzite](https://bazzite.gg) — base image (Fedora 42, KDE Plasma 6)

## Changelog
See [changelog.md](https://github.com/Cerberus9-dev/Raptor-OS/blob/main/changelog.md)
