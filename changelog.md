# Changelog

## [Unreleased]
- Custom GRUB bootloader theme
- Custom KDE splash screen
- Custom Raptor OS logo
- Better seamless fully custom wallpaper system like windows

## [v2.5] - 2026-05-21 (Script Consolidation, Build Fix & Radar HUD)

### Fixed
- **KDE Theme FINALLY fixed!**

### Added
- `org.raptoros.radararc` Plasma plasmoid — cockpit radar arc widget with rotating sweep
  line, fade trail, concentric range rings, crosshair grid, and monospace clock overlay;
  configurable arc colour, sweep colour, sweep speed, opacity, and ring count via
  Plasma widget settings

### Changed
- `raptor-performance.sh` and `raptor-ram-optimizer.sh` consolidated into unified `raptor-cortex.sh`
  — single script now handles CPU throttling, thermal management, memory compression (zram),
  gaming mode service suspension, and RAM optimization GUI; eliminates script duplication and
  simplifies maintenance
- `recipe.yml` script module updated to reflect consolidation — now lists only the six active
  scripts: `raptor-hud.sh`, `raptor-cortex.sh`, `raptor-gpu-profile.sh`, `raptor-gaming.sh`,
  and `raptor-update.sh`
- Comments in `recipe.yml` updated to note that zram sizing is now handled by
  `zram-generator.conf` at runtime rather than `raptor-performance.sh` at build time

## [v2.4] - 2026-05-20 (Full Script Overhaul)

### Fixed
- **Critical:** `raptor-firstboot.service` targeted `graphical.target` (system-level) instead
  of `graphical-session.target` (per-user session) — GUI dialog would fail to display on
  desktops where the session bus isn't available at the system target
- **Critical:** `raptor-firstboot.service` `ExecStart` path pointed to `/usr/local/bin/` —
  corrected to `/usr/bin/` to match the path `recipe.yml` installs the script to
- **Critical:** `raptor-firstboot.service` had a redundant `ExecStartPost=touch` writing the
  stamp file independently of the script — caused a race where the stamp could be written
  even if the browser dialog was cancelled, permanently suppressing the dialog; stamp
  management is now owned exclusively by `raptor-browser-choice.sh`
- **Critical:** `raptor-ensure-services.service` only guarded `raptor-gpu-profile.service` —
  `raptor-powerprofile.service` and `raptor-cpugovernor.service` were silently never
  re-enabled if accidentally disabled
- **Critical:** `raptor-browser-choice.sh` had no prerequisite check for `zenity` — on
  minimal or headless boots the script would crash with an unhelpful "command not found"
  rather than logging and exiting cleanly
- **Critical:** `raptor-browser-choice.sh` "Decide Later" / dialog close wrote the stamp file,
  permanently suppressing the browser choice dialog even though the user never made a
  selection — cancellation now exits without writing the stamp so the dialog re-appears
  next session
- **Critical:** `raptor-update.sh` Python GUI — `_run_update` always called `_on_update_success`
  regardless of `rpm-ostree` exit code; a failed update would incorrectly trigger the
  reboot countdown — now checks `returncode` and routes to `_on_update_error` on non-zero
- `raptor-browser-choice.sh` stamp file location moved from `/var/lib/` root to
  `/var/lib/raptor/` — consolidates all Raptor OS runtime state under one directory
- `raptor-ensure-services.service` did not start newly-enabled units immediately — `--now`
  added so units come up in the current boot rather than waiting for the next reboot
- `raptor-update.sh` icon colour changed from `#33ff33` (harsh neon green) to `#4a9eff`
  (blue) to align with standard GNOME/KDE accent colour conventions and reduce visual clash

### Added
- `btop` added to RPM packages as a modern, full-featured alternative to `htop`
- `raptor-ensure-services.service` now included in the `files` module of `recipe.yml`
  and added to the `systemd` enabled list — it was referenced but never actually deployed
- `raptor-firstboot.service` now sets `SuccessExitStatus=0 1` so a headless boot or
  user cancellation does not mark the unit as failed in `journalctl`
- `raptor-browser-choice.sh` shows a user-facing error dialog if the Brave Flatpak
  installation fails, with Firefox kept as the fallback default
- `raptor-browser-choice.sh` dialog enriched with a Notes column describing each browser
  ("pre-installed" / "will be downloaded from Flathub") to inform the user before choosing
- Per-unit `logger` calls in `raptor-ensure-services.service` — each service enable/fail
  is individually reported to the journal under the `raptor-ensure-services` identifier
- `build.yml` now triggers on pull requests to `main` so CI validates changes before merge
- `build.yml` weekly scheduled rebuild (Sundays 04:00 UTC) to automatically pick up
  upstream Bazzite base image updates
- `build.yml` `concurrency` block cancels stale in-progress runs on new pushes
- `build.yml` ISO artifact upload now includes the `.sha256` checksum file alongside
  the ISO for integrity verification
- `Containerfile` now includes full OCI standard `LABEL` block (title, description,
  URL, source, vendor, license)
- `raptor-update.sh` icon symlinks now include `128x128` in addition to `48x48` and
  `256x256` for better icon theme coverage
- `raptor-update.sh` `.desktop` entry `Categories` field expanded with `System;Settings;`
  for correct placement in KDE and GNOME app menus

### Changed
- All scripts overhauled with `set -euo pipefail` and structured `logger` logging —
  errors now surface in `journalctl` with identifiable tags rather than silently swallowing failures
- `recipe.yml` `image-version` changed from `latest` to `stable` for safer, reproducible builds
- `recipe.yml` RPM package list reorganised into labelled sections (Browser, System Utilities,
  KDE Extras, Power Management, Multimedia, Creative, Gaming, Development, etc.) for readability
- `raptor-ensure-services.service` `ExecStart` rewritten from a single hardcoded `systemctl`
  call to a loop over all three Raptor services with existence checks before enabling
- `raptor-update.sh` Python GUI refactored — all methods renamed to `_private` convention,
  `_strip_ansi()` extracted as a named top-level function, `check_for_updates()` and
  `fetch_changelog()` separated as standalone testable functions
- `build.yml` `registry_token` corrected from deprecated `${{ github.token }}` shorthand
  to `${{ secrets.GITHUB_TOKEN }}`
- `build.yml` ISO job now skips on pull request events — ISOs are only built on merges to main
- `build.yml` artifact `retention-days` extended from 5 to 14 days
- `build.yml` disk cleanup step added to the ISO job (was previously only in the build job)

## [v2.3] - 2026-05-08 (Build System & App Fixes)

### Fixed
- **Critical:** `recipe.yml` YAML parse failure — `- type: rpm-ostree` module entry was
  at column 1 instead of indented under `modules:`, causing the entire build to fail
  validation before any package installation
- **Critical:** `raptor-performance.sh` line 153 crash — `cat` attempted to write
  `/etc/raptor/thermal-idle.conf` before `mkdir -p /etc/raptor` was called; directory
  creation moved above the write
- **Critical:** `raptor-cpugovernor.service` systemd unit parse failure — multiline
  bash inside `ExecStart=` was being interpreted as invalid section headers; collapsed
  to a single-line command
- **Critical:** Heredoc EOF error in `raptor-performance.sh` — `cat << 'CONF'` block
  containing single quotes in `ExecStart=` caused the shell to never find the closing
  delimiter; fixed by switching to unquoted `<< CONF` with `\$` escaping for the
  affected block
- **Critical:** `raptor-performance.sh` file truncation during copy — script was being
  cut off mid-line at the Firefox prefs block, causing `unexpected EOF` errors at
  build time
- **Critical:** `raptor-ram-optimizer.sh` build failure — `chmod 440` on sudoers file
  and missing `mkdir -p /etc/sudoers.d` caused silent non-zero exit under `set -e`;
  fixed with `|| true` guards and `visudo -cf` validation
- **Critical:** Steam (Flatpak) silently failing to launch — `memlock unlimited` in
  `/etc/security/limits.d/raptor-gaming.conf` conflicted with Flatpak sandbox fd
  limits; replaced with a bounded value of 8 GB (8388608 KB)
- **zram Compression** status in Raptor RAM Optimizer incorrectly reported "zram not
  active" despite zram being correctly configured and mounted — fixed detection to
  read `/sys/block/zram0/disksize` for existence check and distinguish between idle
  (nothing swapped yet) and truly inactive
- **zram sizing** evaluated at image build time using the build container's RAM rather
  than the end user's hardware — noted as a known limitation pending a runtime
  firstboot service fix
- **Update Manager** output was severely buffered — rewritten to use `script -q -c`
  to force a PTY, giving real-time line-by-line output matching terminal speed
- **Update Manager** reboot countdown did not trigger `systemctl reboot` after update
  completed — fixed with dedicated `_reboot_cancelled` flag initialized in `__init__`
  and `getattr` guard in countdown to prevent silent `AttributeError` deaths
- **Update Manager** ANSI escape codes were printed raw into the log view — now
  stripped before display for clean readable output
- **Update Manager** switched from `ujust update` to `rpm-ostree update` — `ujust`
  is not available in all environments and would silently fail with "not found"

### Added
- mpv media player
- qBittorrent torrent client
- Bitwarden password manager (Flatpak)
- Thunderbird email client (re-added)
- Raptor Cortex game mode — per-service toggle in RAM Optimizer GUI; selected services
  auto-suspend on game launch via gamemode hooks and resume on game exit
- No-auth RAM optimization — all privileged actions consolidated into a single
  `NOPASSWD` sudoers helper, eliminating repeated password prompts
- Raptor RAM Optimizer now writes `/etc/raptor/cortex-suspend.conf` to persist
  per-user service suspension preferences across reboots
- Update Manager now shows a Cancel Reboot button during the post-update countdown
  so users can defer the reboot if needed
- Update Manager log view now auto-scrolls to the latest output line

### Changed
- Raptor Update Manager fully rewritten — previous version silently crashed on launch
  due to missing `DBUS_SESSION_BUS_ADDRESS` in the wrapper launcher; new version adds
  automatic update check on launch, live changelog loaded from GitHub, live log output
  during update, and automatic 15-second countdown reboot on success
- Update Manager flow now mirrors Windows Update: check → confirm → update → reboot
  with cancellable countdown
- Raptor RAM Optimizer rewritten — all privileged operations consolidated into a single
  sudo call, Razer Cortex-style per-service game mode toggles added, gamemode hooks
  integrated for automatic suspend/resume on game launch and exit

## [v2.2] - 2026-05-07 (Major Fix)

### Fixed
- **Critical:** `vm.overcommit_memory` corrected from mode 1 (always overcommit) to mode 0
  (heuristic) — mode 1 allowed Unity/Unturned to silently allocate past physical RAM,
  causing hard crashes at the RAM ceiling
- **Critical:** Conflicting `vm.swappiness` values between `raptor-memory.conf` and
  `raptor-gaming.conf` resolved — duplicate entries caused unpredictable boot-order
  races; swappiness is now owned exclusively by `raptor-memory.conf`
- `vm.swappiness` raised from 60 to 80 — zram is in-RAM compressed swap (~10× faster
  than disk), so a higher swappiness aggressively compresses cold pages instead of
  triggering the OOM killer on spikes
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
- `raptor-browser-choice.sh` shebang corrected from `#!/usr/bin/bash` to `#!/bin/bash`
  — would silently fail on systems without the symlink
- `raptor-browser-choice.sh` cancel/close now exits with code 0 instead of 1 — closing
  the dialog was incorrectly treated as an error
- `raptor-gpu-profile.sh` performance override profile was missing `RADV_PERFTEST=gpl`
- Dangerous PID loop removed from `raptor-ram-optimizer.sh` — it attempted to set
  `oom_score_adj` on every running process, which had no practical effect (value of 4
  is near-zero in the -1000 to 1000 range) and risked interfering with system processes;
  kernel-level OOM behaviour is already handled by `vm.oom_kill_allocating_task=1`

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
- Added custom app for updating instead of using cmds

## [v2.1] - 2026-05-04 (Mini Hotfix)

### Fixed
- GPU detection now correctly identifies AMD/ATI cards including iGPUs like Cezanne
- Firefox RAM usage significantly reduced via aggressive memory limits in defaults/pref
- Firefox telemetry and background tasks disabled to reduce memory overhead
- Hardware video decoding enabled in Firefox for lower CPU usage

## [v2.0] - 2026-05-04 (Major Update)

### Added
- (Skipped to v2.0 as this was a major update mainly focusing on performance)
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
