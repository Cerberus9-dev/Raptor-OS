# Changelog

## [Unreleased]
- Custom GRUB bootloader theme
- Custom KDE splash screen
- Custom Raptor OS logo
- Better seamless fully custom wallpaper system like windows

## [v2.6] - 2026-06-11 (Full System Overhaul — Gaming, Audio, Network & Bug Sweep)

### Fixed

#### Critical — Firstboot & Services (were silently broken on all Wayland installs)
- **`raptor-firstboot.service` never ran on Wayland** — `ConditionEnvironment=DISPLAY`
  evaluates false on every Bazzite Wayland boot since `DISPLAY` is never set; replaced
  with `ConditionEnvironment=XDG_RUNTIME_DIR` which is present in both Wayland and X11
  sessions
- **`raptor-firstboot.service` was a system service trying to show a GUI** — installed
  to `/usr/lib/systemd/system/` and enabled as a system unit; system services have no
  display session, no D-Bus session bus, and no Plasma shell — dialogs cannot appear;
  converted to a user service at `/usr/lib/systemd/user/` and moved to `user.enabled`
  in recipe.yml
- **`raptor-app-choice.sh` installed nothing** — `FLATPAK_INSTALLS` array declared without
  `declare -A`; bash silently treated it as an indexed array, so every associative key
  lookup returned empty and no Flatpak was ever installed regardless of what the user selected
- **`raptor-app-choice.sh` dialog looped every boot** — Skip path exited without writing
  the stamp file; app selection dialog re-appeared on every login until an app was installed
- **Stamp files required root** — both firstboot scripts wrote stamps to `/var/lib/raptor/`
  which is not writable from a user service; moved to `~/.local/share/raptor/`

#### Critical — Cortex Profile Switching (buttons appeared broken)
- **Profile mode always showed "Balanced" active on launch** — `_current_mode` was
  hardcoded to `"balanced"` at startup with no system detection; if the actual mode
  differed, the wrong button was disabled and clicking the correct mode appeared to
  do nothing; mode is now read from `~/.config/raptor-cortex-mode` on launch
- **Mode selection did not persist** — switching to Performance and reopening Cortex
  reverted to Balanced every time; selection now written to disk immediately on switch
- **`set_use_markup(True)` on `Adw.ActionRow`** — unreliable in libadwaita; removed
  in favour of sensitivity and opacity changes that are guaranteed to work

#### Critical — Taskbar / HUD theme never applied on Plasma 6
- **All `kwriteconfig5` calls in `apply-plasma-panel.sh` do nothing on Plasma 6** —
  KDE 6 ignores kwriteconfig5 writes entirely; replaced with a `kwc()` shim that
  calls `kwriteconfig6` first with `kwriteconfig5` as a fallback
- **`plasma-changeicons` does not exist in Plasma 6** — command was removed upstream;
  replaced with `plasma-apply-icon-theme`
- **`DISPLAY=:0 plasmashell --replace` crashes on Wayland** — explicitly forcing `:0`
  tells plasmashell to start in X11 mode, which fails on a live Wayland session;
  removed the `DISPLAY=:0` prefix so plasmashell inherits the correct session environment

#### Performance Regressions
- **`RADV_DEBUG=nocompute` was in the Extreme GPU profile** — this flag disables the ACE
  (Async Compute Engine) on AMD RDNA hardware, which DX12, Vulkan, and modern Proton titles
  depend on for async reprojection, shadow rendering, and post-processing; removing it
  recovers 10–25% performance in affected titles
- **`echo 1 > /proc/sys/vm/drop_caches`** — value `1` only evicts page caches; corrected
  to `3` to also drop dentries and inodes, maximising free RAM before gaming
- **`raptor-zram.service` raced against `zram-generator.conf`** — both tried to claim
  `/dev/zram0` at boot; removed the manual service and its setup script; ZRAM is now
  managed exclusively by `systemd-zram-generator` via `zram-generator.conf`
- **`brave-optimized` was written to `/usr/local/bin/`** — `/usr/local` is reset to
  empty on every OSTree layer deployment; launcher disappeared after every system update;
  moved to `/usr/bin/` alongside all other Raptor scripts
- **`--use-gl=desktop` in Brave flags conflicts with Wayland** — this flag forces the
  GLX/EGL desktop backend which is incompatible with `UseOzonePlatform`; on Wayland
  sessions Brave either silently fell back to XWayland or failed to start the GPU
  process; removed with an explanatory comment

#### Update Manager
- **`check_for_updates()` treated exit code 77 as "no updates"** — `77` is not a
  documented rpm-ostree exit code; the check was misclassifying genuine errors as
  "system is up to date"
- **`fetch_changelog()` silently disabled TLS verification on first failure** — the
  `ssl.CERT_NONE` fallback loop sent requests over an unverified connection without
  any indication to the user
- **ANSI escape regex was incomplete** — missed ESC+single-character sequences
  (`ESC M`, `ESC c`, etc.) and OSC sequences terminated by `\x1b\\` (string terminator)
  rather than `\x07`; raw escape characters leaked into the update log
- **`Adw.MessageDialog` deprecated in libadwaita 1.5+** — Bazzite ships 1.6; every
  dialog open flooded the journal with GObject deprecation warnings; replaced with
  `Adw.AlertDialog` with a fallback to `MessageDialog` for older versions
- **`_countdown` lambda recreated a closure every second** — `lambda: (self._countdown
  (secs-1), False)[1]` was opaque and allocated a new object each tick; replaced with
  a named `_tick_countdown` method that returns `False` directly
- **`_do_reboot` discarded the Popen object** — if `pkexec` was cancelled or the
  helper failed, the error was swallowed silently; now waits for the process and
  surfaces failures as a warning in the status row
- **`raptor-update-launcher` set `DBUS_SESSION_BUS_ADDRESS` explicitly** — overriding
  the session bus with a uid-formula string breaks portal D-Bus calls when the actual
  socket path doesn't match; removed the override, relying on the session manager's
  correct value
- **`raptor-cpugovernor.service` failed to load** — unit file had `[[Unit]` (double
  bracket) making it syntactically invalid; also called `/usr/bin/raptor-cpugovernor.sh`
  which does not exist in the repo; service failed silently at every boot
- **`raptor-powerprofile.service` did nothing** — `Type=oneshot` with no `ExecStart`
  was a placeholder that completed immediately; now sets `balanced` as the boot default
  power profile via `powerprofilesctl`
- **`raptor-ensure-services.service` called `systemctl enable` at runtime** — on an
  immutable OSTree image the symlink target is read-only; the call either silently
  no-ops or fails; replaced with a health-check using `systemctl is-active` that
  attempts `systemctl start --no-block` for any failed services
- **`systemctl --user import-environment KEY=VALUE` was wrong** — `import-environment`
  accepts variable names already in the calling process's environment, not `KEY=VALUE`
  strings; GPU environment variables were silently never propagated to user sessions;
  switched to `set-environment` which accepts `KEY=VALUE` pairs directly
- **`raptor-powerprofile.service` not enabled** — was installed but never listed in
  recipe.yml `system.enabled`; now enabled after getting a real `ExecStart`
- **ZRAM swap-priority not set** — without an explicit priority ZRAM was ranked at
  the kernel default of `-2`, below any disk-based swap partition; set to `100`

---

### Added

#### Raptor Update Manager — Flatpak Support
- Flatpak apps now checked and updated alongside the system image — previously only
  `rpm-ostree` was handled; apps installed via the firstboot picker (Spotify, Godot, etc.)
  were never updated through the GUI
- Second status row in the UI shows Flatpak update state independently of the system row
- Update button adapts its label: "Update & Reboot" when an OSTree update is pending,
  "Update Flatpaks" when only Flatpak updates exist (no reboot triggered for apps-only updates)
- New `flatpak-update-helper` script with polkit policy and sudoers entry

#### Firstboot App Picker (Complete Rewrite)
- **20 optional Flatpak apps** across five categories: Communication (Telegram, Signal,
  Slack, Zoom), Productivity (VSCodium, ONLYOFFICE, Bitwarden, Joplin, MarkText, Calibre),
  Creative (Blender, Shotcut, Boatswain), Development (Godot Engine, GitHub Desktop, Pods),
  Gaming & Media (Lutris, Protontricks, Spotify, Plex)
- **Per-user app configuration runs before the dialog** — Vesktop memory flags, Firefox
  profile sync, and Flatpak user remote setup now apply unconditionally even when the
  user clicks Skip; previously these were in a separate `raptor-appconfig.sh` that
  required its own service and stamp file; merged and eliminated the extra files

#### Vesktop Memory & Wayland Optimisation
- System-level Flatpak override sets `OZONE_PLATFORM=wayland` — Vesktop previously
  ran through XWayland on Wayland sessions, consuming ~30 MB of extra address space
  per launch
- Per-user `flags.txt` caps V8 old-generation heap at 256 MB (Chromium default is ~1.4 GB
  on systems with free RAM and it never shrinks), limits renderer processes to 2
  (~80–120 MB each), enables VA-API hardware video decode for video calls and streams

#### Firefox Memory Overhaul
- New `/etc/firefox/policies/policies.json` system-wide defaults: memory cache capped
  at 64 MB (was 256 MB in user.js — 4× too large), content process count reduced from
  8 to 4, `browser.tabs.unloadOnLowMemory` enabled, media cache capped at 32 MB,
  session save interval raised from 15 s to 45 s
- `user.js` cleaned up: dead HTTP pipelining prefs removed (pipelining was removed from
  Firefox in version 83), GPU compositing and WebRender prefs retained and expanded
  with `media.ffmpeg.vaapi.enabled` and `gfx.webrender.program-binary-disk`

#### PipeWire Low-Latency Gaming Audio
- Default quantum lowered from 1024 to 256 samples — reduces round-trip audio latency
  from ~21 ms to ~5 ms at 48 kHz; stable on all modern hardware
- ALSA device auto-suspend disabled — prevents the ~120–300 ms audio glitch/pop that
  occurs when a game plays the first sound after a 5-second idle (device wake latency)
- PipeWire graph thread set to RT priority 88 via `libpipewire-module-rt`
- PipeWire and WirePlumber configured to auto-restart on failure (common after
  suspend/resume on AMD hardware); previously a crash left audio dead until logout

#### Network Gaming Optimisations
- **BBR congestion control + CAKE qdisc** — replaces CUBIC; BBR models bandwidth
  directly and maintains much lower queue depth, preventing ping spikes when a background
  download is running during a game session
- **128 MB TCP socket buffers** — the previous 256 KB default (a 1990s value) caused
  packet drops on high-bandwidth game server connections
- **TCP fast-open** — saves one RTT on reconnects to known game servers by sending
  data in the SYN packet; noticeable on game server rejoin after disconnect
- **No slow-start after idle** — prevents TCP from reverting to a tiny initial window
  after a brief pause; games have bursty traffic patterns
- **Cloudflare DoT as system resolver** — Cloudflare averages ~10 ms global DNS lookup
  vs ~40–80 ms for ISP resolvers; affects every new game server connection and
  matchmaking endpoint; systemd-resolved configured with Quad9 fallback and
  DNSSEC allow-downgrade

#### Kernel Boot Arguments
- `split_lock_detect=off` — disables kernel serialisation of split-lock memory accesses;
  some older Windows game ports under Proton trigger this frequently, causing measurable
  frametime spikes
- `transparent_hugepage=madvise` — lets games request 2 MB hugepages without forcing
  them globally (avoiding fragmentation on mixed workloads)
- `nowatchdog` + `nmi_watchdog=0` — removes periodic NMI watchdog timer interrupts
  from the CPU; these fire even mid-frame and show up as latency outliers in frametime
  graphs

#### MangoHud Default Theme
- Ships a default `/etc/mangohud/MangoHud.conf` matching the Raptor OS F-22 palette:
  `#020F12` dark background, `#33FF33` CPU, `#00D4FF` GPU, `#F5A623` engine, JetBrains
  Mono font; shows FPS, frametime graph, GPU/CPU stats + temps + clocks, VRAM, and
  Proton/Wine version; FPS colour thresholds at 45 and 60 fps; toggle with Shift+F12

#### Gamemode Full Configuration
- New `/etc/gamemode.ini`: AMD GPU power level raised to `high` while gaming (unlocks
  boost clocks and higher TDP budget); game processes reniced to -10; screensaver/DPMS
  inhibited during gaming; Steam, Heroic, Lutris, and Bottles registered as valid
  supervisors; previously gamemode was installed but ran with defaults, providing only
  a CPU governor switch
- `gamemoded.service` added to `user.enabled` — without this the daemon never started
  at login and `ENABLE_GAMEMODE=1` launch options silently did nothing

#### Input Device Improvements
- New udev rules disable USB autosuspend for all HID input devices — autosuspend saves
  ~0.5 W but causes 16–500 ms input latency spikes when the device wakes; unacceptable
  during gaming
- Proper `uaccess` permissions for DualSense (054c), Steam Controller/Valve Index (28de),
  and Xbox controllers via hidraw so tools like Chiaki and DS4Windows work without root
- `uinput` device set to `group=input mode=0660` for user-space virtual device creation
  (antimicro, xpadneo, sc-controller)

#### Baseline Memory Configuration
- New `/etc/sysctl.d/90-raptor-memory.conf`: `vm.swappiness=10`, `vm.vfs_cache_pressure=50`
  (holds VFS caches 2× longer — benefits games reloading assets from the same directories),
  proper dirty ratios, `vm.max_map_count=2147483642` — some 64-bit games (Elden Ring,
  Star Citizen via Proton) exhaust the default 65530 memory map limit and crash silently

#### Background Service Memory Caps
- systemd user drop-ins cap RAM on the five heaviest background services: Baloo file
  indexer (128 MB max — can exceed 400 MB during initial index), Akonadi PIM server
  (256 MB), KDE Connect (96 MB), Evolution Data Server (128 MB), GNOME file tracker
  (96 MB); users can raise individual limits in `~/.config/systemd/user/`

#### Fastfetch Themed Config
- Ships a default `/etc/xdg/fastfetch/config.jsonc` with Raptor OS colouring (green keys,
  cyan title, white values); shows OS, kernel, DE/WM/theme, CPU, GPU (via PCI), RAM,
  disk, and local IP

#### New Packages
- `mangohud` — explicit RPM (was implicitly provided by Bazzite base; now declared)
- `protontricks` — RPM for non-Flatpak use; complements Protontricks Flatpak in the
  optional app picker
- `partitionmanager` — KDE Partition Manager; previously absent from the install list

#### New Optional Apps in Firstboot Picker
- **Protontricks** — configure Steam/Proton game prefixes; install DirectX, Visual C++
  runtimes, .NET, and other Windows components for games that require them
- **EasyEffects** — PipeWire-native audio processing: EQ, bass boost, noise suppression
  for headset microphones
- **Warehouse** — browse, manage, and clean up installed Flatpak apps and accumulated
  runtimes (GNOME and KDE runtimes can accumulate 10+ GB over time)
- **Impression** — USB image flasher
- **CoreCtrl** — AMD GPU and CPU control: overclocking, undervolting, fan curves,
  and power limits without manual sysfs writes

---

### Changed
- Default Flatpak install list trimmed to core-only (Vesktop, Heroic, ProtonUp-Qt,
  Bottles, Flatseal, MissionCenter) — all optional apps moved to the firstboot picker
  so users choose what they actually want instead of getting everything pre-installed
- `raptor-app-choice.sh` now also handles all per-user app configuration inline before
  the dialog; the separate `raptor-appconfig.sh` script and `raptor-appconfig.service`
  unit have been eliminated
- Audio and network optimisations converted from build scripts (`raptor-audio.sh`,
  `raptor-network.sh`) to individual static config files with explicit
  `source → destination` mappings in recipe.yml — each file is now readable directly
  in the repo without running anything
- `raptor-cpugovernor.service` removed from `system.enabled` — CPU governor is handled
  by `raptor-gpu-profile.service` → `gpu-detect.sh`; the service file is retained on
  disk for compatibility but no longer starts at boot

## [v2.5] - 2026-05-21 (Script Consolidation, Build Fix & Radar HUD)

### Fixed
- **KDE Theme FINALLY fixed!**

### Added
- **Custom Radar HUD taskbar** — fully custom KDE Plasma panel replacing the default taskbar
  with an F-22 cockpit-inspired radar theme; features phosphor-green sweep line with
  persistence trail, randomised contact blips that light up as the sweep passes and decay
  between rotations, 8-point crosshair grid with diagonal lines, bearing tick marks around
  the rim, and a HUD status readout (clock, range label, IFF/MODE-S status); configurable
  arc colour, sweep colour, speed, opacity, and grid ring count via widget settings;
  panel corner radar arc decorations (`org.raptoros.radararc`) on both ends of the taskbar
  with live sweep, blip persistence, and HDG/ALT readouts

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
