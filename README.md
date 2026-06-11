# Raptor OS
A custom Bazzite-based Linux distribution built for gaming performance — F-22 HUD-inspired KDE theme, automatic GPU optimisation, low-latency audio, and a clean firstboot setup experience.

> ⚠️ **HEAVY W.I.P — Feedback is appreciated!**
> ℹ️ **This is NOT a live OS.** It requires a separate drive, replacing your current OS, or dual booting. For dual booting, make sure you have 40–50 GB available. If you don't have space or time, it can be run in a VM for testing first.

---

## System Requirements

| | Minimum | Recommended |
|---|---|---|
| **CPU** | 64-bit x86_64 (Intel or AMD) | AMD Ryzen / Intel 10th gen+ |
| **RAM** | 8 GB | 16 GB |
| **Storage** | 40 GB (SSD) | 60 GB NVMe |
| **GPU** | AMD, NVIDIA, or Intel | AMD RDNA2+ or NVIDIA RTX |
| **Boot** | UEFI required | — |

---

## Installation

Download the latest ISO from [Internet Archive](https://archive.org/details/raptor-os_202605), then flash it to a USB drive using one of the following:

- [Rufus](https://rufus.ie/en/) — when prompted, select **DD image mode** and **GPT** partition scheme
- [Ventoy](https://www.ventoy.net)
- [Fedora Media Writer](https://github.com/FedoraQt/MediaWriter) — guaranteed to work if others fail

### Rebasing from Bazzite (no reinstall)

If you already have Bazzite installed and want to switch without reinstalling:

**Step 1:**
```
rpm-ostree rebase ostree-unverified-registry:ghcr.io/cerberus9-dev/raptor-os:latest
```
**Step 2:**
```
systemctl reboot
```
**Step 3:**
```
rpm-ostree rebase ostree-image-signed:docker://ghcr.io/cerberus9-dev/raptor-os:latest
```
**Step 4:**
```
systemctl reboot
```

> If you already have Raptor OS installed, open **Raptor Update Manager** and click **Update & Reboot** to get the latest version — both system and Flatpak updates are handled in one step.

---

## First Boot

On first login, two setup dialogs appear in sequence:

1. **Browser choice** — Firefox (pre-installed) or Brave (downloaded from Flathub)
2. **App picker** — choose from 20 optional apps across Communication, Productivity, Creative, Development, and Gaming categories; pre-ticked apps are recommended but everything is optional

Per-user optimisations are applied automatically during this step regardless of what you select: Vesktop memory flags, Firefox profile tuning, and Flatpak remote setup.

---

## What's Included

### Pre-installed (always present)

**Communication & Gaming**
- Vesktop — lightweight Discord client (native Wayland, V8 heap capped at 256 MB)
- Heroic Games Launcher — Epic, GOG, and Amazon games
- ProtonUp-Qt — manage GE-Proton and other Proton builds
- Bottles — run Windows apps and games via Wine/DXVK

**Browsers**
- Firefox — with system-wide memory policy: 64 MB cache cap, 4 content processes, tab unloading on low memory

**System & Gaming Tools**
- MangoHud — in-game performance overlay with Raptor OS F-22 themed colours and JetBrains Mono font; toggle Shift+F12
- GOverlay — MangoHud profile editor
- Gamemode — auto-applies CPU/GPU performance settings on game launch (AMD GPU power level raised to high, processes reniced, screensaver inhibited)
- MangoHud + Gamemode integrate automatically with Steam, Heroic, Lutris, and Bottles
- Protontricks — install DirectX, Visual C++ runtimes, and other Windows components into Proton game prefixes
- Wine + Winetricks

**Creative**
- GIMP, Inkscape, Krita, Darktable — image editing and photo management
- Kdenlive, OBS Studio, Audacity — video and audio production

**Productivity & Office**
- LibreOffice — full office suite
- Thunderbird — email client

**Media & Downloads**
- VLC, mpv — video playback
- Gwenview — image viewer
- qBittorrent — torrent client

**Development**
- Git, GitHub CLI
- Node.js, Python 3, GCC, CMake
- Neovim
- Podman (container runtime)

**System Utilities**
- Fastfetch — themed system info (green/cyan Raptor OS palette)
- Mission Center — GPU/CPU/RAM/process monitor
- Flatseal — Flatpak permission manager
- KDE Partition Manager — disk management
- BleachBit, Filelight — storage cleanup
- Variety — wallpaper manager
- Raptor Update Manager — GUI for system + Flatpak updates with live log output

---

### Choose at First Boot (optional)

| Category | Apps |
|---|---|
| **Communication** | Telegram, Signal, Slack, Zoom |
| **Productivity** | VSCodium, ONLYOFFICE, Bitwarden, Joplin, MarkText, Calibre |
| **Creative** | Blender, Shotcut, Boatswain (Elgato Stream Deck) |
| **Development** | Godot Engine, GitHub Desktop, Pods (Docker/Podman GUI) |
| **Gaming & Media** | Lutris, Protontricks, Spotify, Plex |
| **Audio** | EasyEffects (headset EQ, noise reduction) |
| **System** | Warehouse (Flatpak manager), Impression (USB flasher), CoreCtrl (AMD GPU control) |

All optional apps can also be installed later from Discover or via `flatpak install flathub <id>`.

---

## Performance

### GPU & CPU
- **Automatic GPU detection** at boot — AMD, NVIDIA, Intel, and hybrid iGPU configurations; applies environment variables, Vulkan ICD, shader cache settings, and CPU governor per profile
- **Raptor Cortex** — GTK4/libadwaita performance manager with three modes: Power Saving, Balanced, and Performance; applies kernel tuning (CPU governor, PCIe ASPM, NVMe, SATA, USB, audio power) instantly; mode persists across launches
- **Game Mode** — Cortex auto-suspends background services (Baloo, Akonadi, KDE Connect, packagekitd, and more) when a game is detected; resumes everything on exit
- **Gamemode daemon** — `gamemoded` runs as a user service; use `ENABLE_GAMEMODE=1 %command%` in Steam launch options or enable per-game in Heroic/Lutris
- **Kernel arguments** — `split_lock_detect=off` prevents split-lock serialisation penalties in Proton games; `transparent_hugepage=madvise` lets games request 2 MB hugepages; watchdog NMI timer disabled to reduce frametime outliers

### Audio
- **PipeWire low-latency** — default quantum reduced from 1024 to 256 samples (~21 ms → ~5 ms round-trip at 48 kHz); stable on all modern hardware; increase in `/etc/pipewire/pipewire.conf.d/99-raptor-lowlatency.conf` if needed
- **Device auto-suspend disabled** — prevents the pop/click and ~150–300 ms glitch when audio wakes from power-gating between game sounds
- **PipeWire and WirePlumber auto-restart** — crash recovery after suspend/resume without needing to log out

### Network
- **BBR congestion control + CAKE qdisc** — replaces CUBIC; maintains lower queue depth under load, preventing ping spikes when a download runs alongside a game session
- **128 MB TCP socket buffers** — allows full 1 Gbit throughput for patch downloads without affecting gaming latency
- **TCP fast-open** — saves one RTT on reconnects to known game servers
- **Cloudflare DoT** — DNS-over-TLS via `systemd-resolved`; ~10 ms global lookup latency vs ~40–80 ms for typical ISP resolvers

### Memory
- **ZRAM swap** — compressed swap in RAM with priority 100 (always preferred over disk); zstd algorithm; sized at `min(RAM/2, 8 GB)`
- **Baseline sysctl** — `vm.swappiness=10`, `vm.vfs_cache_pressure=50` (holds filesystem caches longer for games reloading the same assets), `vm.max_map_count=2147483642` (fixes silent crashes in games that exhaust the default 65530 memory map limit)
- **Background service memory caps** — cgroup limits on Baloo (128 MB), Akonadi (256 MB), KDE Connect (96 MB), Evolution Data Server (128 MB), and GNOME file tracker (96 MB) via systemd user drop-ins
- **Unity/Proton memory fixes** — 32-bit address space expansion and shared memory for games like Unturned; OOM kill tuning targets the leaking process instead of unrelated victims

### Input
- **USB autosuspend disabled** for all HID input devices — prevents 16–500 ms input latency spikes when a mouse or keyboard wakes from power-gating
- **Controller permissions** — DualSense, Steam Controller, Valve Index, and Xbox controllers get `uaccess` via udev; tools like Chiaki and DS4Windows work without root

---

## Built With
- [BlueBuild](https://blue-build.org) — custom image build system
- [Bazzite](https://bazzite.gg) — base image

## Changelog
See [changelog.md](https://github.com/Cerberus9-dev/Raptor-OS/blob/main/changelog.md)
