# Raptor OS
**Current version: v2.6.7**

A custom Bazzite-based Linux distribution built for gaming — F-22 cockpit-inspired KDE theme with neon green HUD panel, automatic GPU optimisation, low-latency audio, and a zero-terminal firstboot experience.

>  **Heavy W.I.P — Feedback appreciated!**
>  This is **not** a live OS. It needs its own drive, replaces your current OS, or runs alongside it as a dual boot. Minimum 40–50 GB free for dual boot. Can be tested in a VM first.

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

Download the latest ISO from the [Releases page](https://github.com/Cerberus9-dev/Raptor-OS/releases), then flash it to a USB drive:

- **[Rufus](https://rufus.ie/en/)** — select **DD image mode** + **GPT** partition scheme
- **[Ventoy](https://www.ventoy.net)** — copy ISO to Ventoy USB, boot and select it
- **[Fedora Media Writer](https://github.com/FedoraQt/MediaWriter)** — most reliable, always works

### Rebase from Bazzite (no reinstall)

If you already have Bazzite installed you can switch without reinstalling:

```bash
# Step 1 — unverified image to start the transition
rpm-ostree rebase ostree-unverified-registry:ghcr.io/cerberus9-dev/raptor-os:latest
systemctl reboot

# Step 2 — switch to the signed image
rpm-ostree rebase ostree-image-signed:docker://ghcr.io/cerberus9-dev/raptor-os:latest
systemctl reboot
```

> **Already on Raptor OS?** Open **Raptor Update Manager** → **Update & Reboot**. Handles system image + Flatpak updates in one click. The app launcher (Kickoff) automatically rebuilds its category index after updates so blank folders never appear.

---

## First Boot

Two dialogs appear on the first login, in sequence:

1. **Browser choice** — Firefox (pre-installed, no download), Brave (~120 MB), or Chrome (~150 MB). Closing the dialog keeps Firefox. Shows a network check, download progress bar, and retry prompt on failure.

2. **App picker** — 40+ optional apps across 10 categories. Nothing is pre-ticked except VSCodium. All apps can also be installed later from Discover or `flatpak install flathub <id>`.

---

## What's Included

### Pre-installed (always present)

| Category | Apps |
|---|---|
| **Communication** | Vesktop (Discord client — native Wayland, no Electron overhead) |
| **Browser** | Firefox (memory-optimised: 64 MB cache, 4 processes, tab unloading enabled) |
| **Gaming** | Heroic Games Launcher (Epic/GOG/Amazon), ProtonUp-Qt, Protontricks, Wine, Winetricks |
| **Creative** | Krita (digital painting and illustration) |
| **Media** | VLC (plays any format), mpv |
| **Development** | VSCodium, Git, Node.js, Python 3, GCC, Make, CMake |
| **System** | htop, KDE Partition Manager, BleachBit, Filelight, Mission Center, Flatseal |
| **Overlays** | MangoHud (F-22 green palette, Shift+F12), GOverlay, Gamemode |

---

### Choose at First Boot

| Category | Apps |
|---|---|
| **Communication** | Telegram, Signal, Slack, Zoom, Thunderbird |
| **Productivity** | ONLYOFFICE, Bitwarden, Joplin, MarkText, Calibre, Obsidian |
| **Office** | LibreOffice |
| **Creative** | GIMP, Inkscape, Darktable, Blender, Kdenlive, Shotcut, OBS Studio, Audacity, Boatswain |
| **Development** | GitHub Desktop, Pods, GCC + Make + CMake, Ninja + Meson, Neovim, GitHub CLI |
| **Gaming** | Bottles, Lutris, Spotify, Plex, Cartridges, Ryujinx, RPCS3, RetroArch, Chiaki |
| **Privacy** | ProtonVPN, KeePassXC |
| **Media & Downloads** | FreeTube, Parabolic, Kooha, Clapper, Amberol |
| **Audio Production** | EasyEffects, Helvum, LMMS, Ardour |
| **System** | Warehouse, Impression, CoreCtrl, btop, Variety, GNOME Boxes, Warp, Flatsweep, Upscayl, Metadata Cleaner |

---

## Performance

### GPU
- **Auto GPU detection** at boot via `raptor-gpu-profile.service` — AMD, NVIDIA, Intel, hybrid; sets Vulkan ICD, env vars, shader cache, CPU governor per profile
- **`RADV_PERFTEST=gpl`** — Vulkan Graphics Pipeline Library cuts in-game shader compile stalls 30–60% on RDNA2+
- **Mesa GL threading** via `/etc/drirc.d/` — offloads GL API calls to a background thread (~10–20% throughput on CPU-bound games)
- **`WINE_FULLSCREEN_FSR` and `DXVK_ASYNC` not set globally** — caused flickering in OpenGL games (Project Zomboid). Set per-game in Steam launch options instead

### CPU
- **Raptor Cortex** — GTK4 performance manager with three modes, correct per-mode `vm.swappiness` (5/30/180), CPU governor, PCIe ASPM, NVMe, and audio power settings
- **`kernel.sched_wakeup_granularity_ns=1000000`** — 1 ms wakeup granularity vs kernel default 3 ms; reduces input and frame latency
- **`kernel.sched_autogroup_enabled=1`** — groups game + threads as one scheduler entity vs background daemons
- **irqbalance** — installed and managed by Cortex; suspended during game sessions, restarted on exit
- **`/dev/cpu_dma_latency=0`** during game mode — keeps CPU in shallow C-state, eliminates 100–300 µs wake latency spikes
- **Gamemode daemon** — use `ENABLE_GAMEMODE=1 %command%` in Steam; suspends 17 background services on launch

### Memory — idle ~2.5–3 GB
- **Akonadi masked** — KDE PIM database server disabled by default (saves 200–500 MB); re-enable with `systemctl --user unmask akonadiserver.service`
- **tracker-miner-fs masked** — GNOME file tracker redundant alongside KDE Baloo (saves ~80 MB)
- **plasma-browser-integration masked** — browser tab sync disabled by default (saves ~80 MB)
- **Baloo: filename-only indexing** — full-text content indexing disabled, 1 thread max; sufficient for search, fraction of the RAM
- **Background service caps** — Baloo 128 MB, KDE Connect 96 MB, kactivitymanagerd 96 MB, kwalletd 96 MB
- **ZRAM** — zstd compression, `min(RAM/2, 8 GB)`, priority 100, `discard` enabled
- **`vm.page-cluster=0`** — single-page reads from ZRAM (avoids decompressing 8 pages when 1 is needed)
- **`vm.watermark_boost_factor=0`** — no sudden reclaim bursts during gameplay
- **`vm.min_free_kbytes=131072`** — 128 MB free-page reserve prevents allocation stalls
- **Optimize Memory Now** in Cortex — reclaims real app memory (Firefox/Vesktop heap) via cgroup v2 `memory.reclaim`
- **journald capped** — 64 MB runtime, 200 MB disk; ModemManager masked

### Audio
- **PipeWire 512-sample quantum** (~10.7 ms at 48 kHz) — stable under gaming GPU load, no static
- **`api.alsa.headroom=0`** for outputs — eliminates the 170 ms buffer mismatch that caused crackling
- **Auto-suspend disabled** on all audio devices — no pop/click between sounds
- **Auto-restart** for PipeWire and WirePlumber with burst limiting (max 5 restarts/min)

### Network
- **BBR congestion control + CAKE qdisc** — lower ping variance under concurrent downloads
- **128 MB TCP socket buffers**, **socket busy-polling** (50 µs spin for low-latency UDP), **TCP fast-open**
- **Cloudflare DoT** — ~10 ms DNS vs ~40–80 ms ISP default
- **`fs.file-max=2097152`** — prevents file descriptor exhaustion on modded games

---

## Window Management (Windows-style)
- **Buttons** — Minimize `_`, Maximize `□`, Close `×` on the right; App Menu on the left
- **Titlebar double-click** — maximises the window (KDE default is shade)
- **Click to raise** — clicking anywhere on a window brings it to front
- **Edge snap** — drag to screen edge to snap/tile (equivalent to Windows Aero Snap)
- **`KWin LatencyPolicy=0`** — submits compositor frames immediately, reducing display latency

---

## HUD Theme
- **Panel** — near-black `#0a0e12` background with a neon green `#33FF33` glow edge
- **Accent colour** — `#33FF33` throughout: selection highlights, window decoration borders, links, active titlebar
- **Font** — JetBrains Mono (monospaced, consistent with cockpit displays)
- **Radar Arc widget** — optional panel widget; add via right-click panel → Add Widgets → search "Radar"

---

## Built With
- [BlueBuild](https://blue-build.org) — custom OCI image build system
- [Bazzite](https://bazzite.gg) — base image (Fedora 42, KDE Plasma 6, Wayland)

## Changelog
See [changelog.md](changelog.md) for full version history.
