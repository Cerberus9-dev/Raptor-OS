# Changelog
## [Unreleased]
- Custom GRUB bootloader theme
- Custom KDE splash screen
- Custom Raptor OS logo
- KDE theme fix (ongoing)

## [v2.2] - 2026-05-07 (Major Fix)
### Fixed
- **Critical:** `vm.overcommit_memory` corrected from mode 1 (always overcommit) to mode 0
  (heuristic) — mode 1 allowed Unity/Unturned to silently allocate past physical RAM,
  causing hard crashes at the RAM ceiling
- **Critical:** Conflicting `vm.swappiness` values between `raptor-memory.conf` and
  `raptor-gaming.conf` resolved — duplicate entries caused unpredictable boot-order
  races; swappiness is now owned exclusively by `raptor-memory.conf`
- `vm.page-cluster` set to 0 — default value of 3 caused 8-page read-ahead on every
  zram fault, wasting memory and adding latency on compressed swap
- `vm.min_free_kbytes` raised from 64 MB to 128 MB to prevent page allocator stalls
  under heavy RAM pressure
- `vm.watermark_scale_factor` raised from 125 to 200 so the kernel begins reclaiming
  pages earlier, before hitting the RAM ceiling
- `vm.compaction_proactiveness` re-enabled (set to 20) — was incorrectly set to 0,
  which disabled proactive memory compaction
- `vm.oom_kill_allocating_task` enabled — kernel now kills the process that triggered
  the OOM event (e.g. Unturned leaking memory) instead of hunting an unrelated victim

### Added
- `WINE_LARGE_ADDRESS_AWARE=1` and `PROTON_FORCE_LARGE_ADDRESS_AWARE=1` added to all
  GPU profiles — allows 32-bit Unity builds (including Unturned) to address more than
  2 GB of RAM under Proton/Wine
- `STAGING_SHARED_MEMORY=1` added to all GPU profiles for more efficient cross-process
  memory sharing under Wine/Proton
- System-wide `ulimits` raised for all users: `nofile` to 1,048,576 and `memlock` to
  unlimited — Unity asset streaming silently fails at the default 1024 file descriptor
  limit on large maps
- Hint file written to `/etc/raptor/unturned-launch-options.txt` with recommended Steam
  launch options including `-gc.maxreserved 128` to cap the mono GC heap reservation,
  the single largest source of Unturned RAM bloat
- `vm.swappiness` raised from 60 to 80 — zram is in-RAM compressed swap (~10× faster
  than disk), so a higher swappiness aggressively compresses cold pages instead of
  triggering the OOM killer on spikes

## [v2.1] - 2026-05-07
### Fixed
- GPU detection now correctly identifies AMD/ATI cards including iGPUs like Cezanne
- Firefox RAM usage significantly reduced via aggressive memory limits in defaults/pref
- Firefox telemetry and background tasks disabled to reduce memory overhead
- Hardware video decoding enabled in Firefox for lower CPU usage

## [v2.0] - 2026-05-04 (Major Update)
### Added
- Automatic GPU vendor detection (AMD/NVIDIA/Intel/iGPU)
- Per-vendor GPU optimization profiles
- Performance Mode toggle with GUI — choose Auto or Max Performance
- RAM spike protection for large game maps and memory intensive apps
- WiFi stability fix — disables power saving to prevent random disconnections
- Split build scripts into raptor-hud, raptor-performance, raptor-gaming and raptor-gpu-profile
- Raptor Profile Switcher app — switch between Auto and Max Performance GPU profiles from the app menu
- Shotcut video editor
- Made ZRAM dynamic based on available RAM for better performance
### Fixed
- WiFi randomly disconnecting and not reconnecting
- RAM ceiling hits during large map loading in games like Unturned
- GPU settings now correctly differentiate between iGPU and dGPU

## [v1.2] - 2026-05-04
### Added
- Betterbird as default email client
- Calibre ebook manager
- Joplin note taking app
- Pods GUI for Podman containers
- MarkText Markdown editor
- Mission Center task manager
- ProtonUp-Qt for managing Proton versions
- Blender 3D modeling
- Flatseal Flatpak permission manager
- Bottles Windows app compatibility layer (returned by popular demand)
- KCalc calculator
- Kamoso webcam app
- BleachBit system cleaner
- Darktable photo editor
- Audacity audio editor
- Boatswain stream deck controller
### Removed
- Thunderbird (replaced by Betterbird)
### Fixed
- KDE theme accent color now uses kwriteconfig6 for Plasma 6 compatibility
- App menu refresh via kbuildsycoca6
- Steam dev config path not existing during build
- raptor-theme.sh not being created during build

## [v1.1] - 2026-05-02
### Added
- Inkscape and Krita for graphics work
- VLC media player
- OBS Studio for streaming and recording
- Variety wallpaper changer
- Wine and Winetricks for Windows app compatibility
- Development tools: Git, GitHub CLI, Node.js, Python 3, GCC, Make
- Additional dev tools: CMake, Ninja, Meson, Neovim, htop, Podman, jq, ripgrep, fzf, tmux
- Podman and Podman Compose for containerization
- Gamemode and GOverlay for gaming performance
- Filelight disk usage analyzer
- Gwenview image viewer
- Automatic Cloudflare DNS (1.1.1.1) for better internet performance
- First boot browser choice dialog (Firefox or Brave)
- Neon green KDE theme now applies system-wide
- Steam and Lutris gaming optimizations (async shaders, shader caching, DXVK)
- zram enabled by default for better memory management
- KDE theme now force reloads on boot
### Fixed
- DNS sluggishness via systemd-resolved configuration
- Firefox RAM usage via performance tweaks and memory hard limits
- KDE theme not applying to existing users
- Steam and Firefox high idle memory usage via zram and config tweaks

## [v1.0] - 2026-05-01
### Added
- Initial release based on Bazzite
- Neon green KDE theme (Breeze Dark with green accents)
- Firefox with performance tweaks
- Fastfetch system info display
- Brave Browser option via first boot browser choice dialog
- Discord, VSCodium, Heroic Games Launcher as Flatpaks
- LibreOffice, Thunderbird, Kdenlive, GIMP
- First boot service that automatically rebases to Raptor OS from stock Bazzite
