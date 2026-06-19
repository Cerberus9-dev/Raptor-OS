#!/bin/bash
set -oue pipefail

# ═══════════════════════════════════════════════════════════════════════════════
# Raptor OS — Gaming & System Optimization  v2.6
# Covers: app launcher configs (Lutris, Steam), browser hardening (Firefox,
#         Brave), background process trimmer, I/O scheduler tuning, MangoHud
#         theme, gamemode.ini, input udev rules, fastfetch config, network
#         sysctl, DNS, journald caps, ModemManager masking, and systemd
#         cgroup memory caps for background services.
# ═══════════════════════════════════════════════════════════════════════════════

# ── Ensure required directories exist ─────────────────────────────────────────
mkdir -p /usr/local/bin \
         /etc/raptor \
         /usr/lib/raptor \
         /usr/lib/systemd/system

# ── Lutris ─────────────────────────────────────────────────────────────────────
mkdir -p /etc/skel/.config/lutris
cat << 'EOF' > /etc/skel/.config/lutris/lutris.conf
[lutris]
prefer-system-libraries=true
reset-desktop-on-quit=false
game-show-logs=false
disable-runtime=false
library-view-sorting=name
library-view-sorting-ascending=true
EOF

# ── Steam ──────────────────────────────────────────────────────────────────────
mkdir -p /etc/skel/.steam/steam
cat << 'EOF' > /etc/skel/.steam/steam/steam_dev.cfg
# Disable HTTP/2 (causes stalled downloads on many routers)
@nClientDownloadEnableHTTP2PlatformLinux 0
# More aggressive multi-connection download
@fDownloadRateImprovementToAddAnotherConnection 1.0
# Larger disk write buffer
@cMaxFileSystemWriteBufferSizeBytes 4194304
# Disable Steam overlay shader pre-caching (reduces background CPU)
@bEnableShaderPreCaching 0
EOF

# ── ulimits ────────────────────────────────────────────────────────────────────
cat << 'EOF' > /etc/security/limits.d/raptor-gaming.conf
# Raptor OS gaming ulimits
# Large open-file limit (Unity asset streaming, shader caches)
*    soft    nofile    1048576
*    hard    nofile    1048576
# memlock: high but bounded — unlimited breaks Flatpak sandboxing
*    soft    memlock   16777216
*    hard    memlock   16777216
# Real-time scheduling for audio (pipewire/pulse latency)
@audio soft rtprio 95
@audio hard rtprio 95
*     soft rtprio 5
*     hard rtprio 5
# Stack size — some large Unity games overflow the default 8MB
*    soft    stack     65536
*    hard    stack     65536
EOF

# ── I/O Scheduler tuning ───────────────────────────────────────────────────────
cat << 'EOF' > /usr/lib/udev/rules.d/60-raptor-iosched.rules
# Raptor OS I/O scheduler rules
ACTION=="add|change", KERNEL=="nvme[0-9]*", ATTR{queue/scheduler}="mq-deadline"
ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/rotational}=="0", ATTR{queue/scheduler}="mq-deadline"
ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/rotational}=="1", ATTR{queue/scheduler}="bfq"
ACTION=="add|change", KERNEL=="nvme[0-9]*", ATTR{queue/nr_requests}="2048"
ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/rotational}=="1", ATTR{queue/read_ahead_kb}="2048"
ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/rotational}=="0", ATTR{queue/read_ahead_kb}="256"
EOF
udevadm control --reload-rules 2>/dev/null || true

# ── ZRAM swap ─────────────────────────────────────────────────────────────────
# ZRAM is configured via /etc/systemd/zram-generator.conf (installed by the
# files module in recipe.yml). systemd-zram-generator handles device creation
# automatically at boot — no separate service or script is needed here.
# A manual teardown helper is kept for Cortex / emergency use.
cat << 'TEARDOWN' > /usr/bin/raptor-zram-teardown.sh
#!/bin/bash
for dev in $(zramctl --noheadings --output NAME 2>/dev/null); do
    swapoff "$dev" 2>/dev/null || true
    zramctl --reset "$dev" 2>/dev/null || true
done
TEARDOWN
chmod +x /usr/bin/raptor-zram-teardown.sh

# ── Firefox system-wide defaults (policies.json) ──────────────────────────────
# policies.json is read before any user profile — the cleanest way to set
# memory-management defaults without overwriting user settings permanently.
mkdir -p /etc/firefox/policies
cat << 'POLICIES' > /etc/firefox/policies/policies.json
{
  "policies": {
    "Preferences": {
      "browser.cache.memory.capacity": {
        "Value": 65536,
        "Status": "user"
      },
      "browser.sessionhistory.max_total_viewers": {
        "Value": 2,
        "Status": "user"
      },
      "dom.ipc.processCount": {
        "Value": 4,
        "Status": "user"
      },
      "dom.ipc.processCount.webIsolated": {
        "Value": 2,
        "Status": "user"
      },
      "browser.tabs.unloadOnLowMemory": {
        "Value": true,
        "Status": "user"
      },
      "media.memory_cache_max_size": {
        "Value": 32768,
        "Status": "user"
      },
      "browser.sessionstore.interval": {
        "Value": 45000,
        "Status": "user"
      },
      "browser.sessionstore.max_serialize_back": {
        "Value": 5,
        "Status": "user"
      },
      "browser.sessionstore.max_serialize_forward": {
        "Value": 3,
        "Status": "user"
      },
      "config.trim_on_minimize": {
        "Value": true,
        "Status": "user"
      }
    },
    "DisableTelemetry": true,
    "DisableFirefoxStudies": true,
    "OverrideFirstRunPage": "",
    "DontCheckDefaultBrowser": true
  }
}
POLICIES

# ── Firefox user.js (rendering + privacy; written to skel for new users) ───────
setup_firefox_optimizations() {
    local PROFILE_DIR="$1"
    mkdir -p "$PROFILE_DIR"
    cat << 'FFJS' > "$PROFILE_DIR/user.js"
// ── Raptor OS: Firefox Rendering, Privacy & Memory Hardening ─────────────────
// Memory defaults are managed via /etc/firefox/policies/policies.json.
// This file handles GPU compositing, rendering quality, and privacy.

// ── GPU / WebRender ───────────────────────────────────────────────────────────
user_pref("layers.acceleration.enabled", true);
user_pref("gfx.webrender.all", true);
user_pref("gfx.webrender.compositor", true);
user_pref("gfx.webrender.compositor.force-enabled", true);
user_pref("gfx.webrender.program-binary-disk", true);
user_pref("media.hardware-video-decoding.enabled", true);
user_pref("media.hardware-video-decoding.force-enabled", true);
user_pref("media.ffmpeg.vaapi.enabled", true);
user_pref("layers.offmainthreadcomposition.enabled", true);
user_pref("dom.webgpu.enabled", true);

// ── JavaScript GC tuning ──────────────────────────────────────────────────────
// Shorter GC slices: reduces janky pauses while maintaining low heap
user_pref("javascript.options.mem.gc_incremental_slice_ms", 10);
user_pref("javascript.options.mem.high_water_mark", 48);
user_pref("javascript.options.mem.gc_high_frequency_time_limit_ms", 500);

// ── Disk cache (use disk, not memory, for media/page content) ─────────────────
user_pref("browser.cache.disk.enable", true);
user_pref("browser.cache.disk.capacity", 524288);
user_pref("browser.cache.memory.enable", true);
// browser.cache.memory.capacity set in policies.json (64 MB)

// ── Network ───────────────────────────────────────────────────────────────────
// HTTP/2 + QUIC (HTTP/3) — pipelining was removed in Firefox 83, do not set it
user_pref("network.http.max-connections", 900);
user_pref("network.http.max-connections-per-server", 32);
user_pref("network.http.max-persistent-connections-per-server", 10);
user_pref("network.http.http2.enabled", true);
user_pref("network.http.http3.enable", true);
user_pref("network.prefetch-next", true);
user_pref("network.dns.disablePrefetch", false);
user_pref("network.predictor.enabled", true);
// DNS-over-HTTPS via Cloudflare (mode 2 = preferred, falls back to system)
user_pref("network.trr.mode", 2);
user_pref("network.trr.uri", "https://cloudflare-dns.com/dns-query");

// ── Telemetry & bloat OFF ─────────────────────────────────────────────────────
user_pref("toolkit.telemetry.enabled", false);
user_pref("toolkit.telemetry.unified", false);
user_pref("toolkit.telemetry.server", "");
user_pref("datareporting.healthreport.uploadEnabled", false);
user_pref("datareporting.policy.dataSubmissionEnabled", false);
user_pref("app.shield.optoutstudies.enabled", false);
user_pref("extensions.shield-recipe-client.enabled", false);
user_pref("browser.newtabpage.activity-stream.feeds.telemetry", false);
user_pref("browser.newtabpage.activity-stream.telemetry", false);
user_pref("extensions.pocket.enabled", false);
user_pref("browser.newtabpage.activity-stream.showSponsored", false);
user_pref("browser.newtabpage.activity-stream.showSponsoredTopSites", false);
user_pref("breakpad.reportURL", "");
user_pref("browser.tabs.crashReporting.sendReport", false);

// ── Scroll smoothness ─────────────────────────────────────────────────────────
user_pref("apz.allow_zooming", true);
user_pref("general.smoothScroll", true);
user_pref("general.smoothScroll.mouseWheel.durationMinMS", 80);
user_pref("general.smoothScroll.mouseWheel.durationMaxMS", 200);
user_pref("mousewheel.system_scroll_override.enabled", true);
FFJS
}

for profdir in /home/*/.mozilla/firefox/*.default* \
               /home/*/.mozilla/firefox/*.default-release \
               /root/.mozilla/firefox/*.default*; do
    if [ -d "$profdir" ]; then
        setup_firefox_optimizations "$profdir"
        echo "Firefox optimizations applied: $profdir"
    fi
done

mkdir -p /etc/skel/.mozilla/firefox/raptor-default
setup_firefox_optimizations "/etc/skel/.mozilla/firefox/raptor-default"

# ── Brave optimization ─────────────────────────────────────────────────────────
setup_brave_optimizations() {
    local BRAVE_CONFIG_DIR="$1"
    mkdir -p "$BRAVE_CONFIG_DIR"

    cat << 'BRAVEFLAGS' > "$BRAVE_CONFIG_DIR/raptor-brave-flags.conf"
# Raptor OS: Brave / Chromium performance flags
# Note: --use-gl=desktop is intentionally absent — it conflicts with
# --enable-features=UseOzonePlatform on Wayland and causes rendering issues.
--enable-features=VaapiVideoDecoder,VaapiVideoEncoder,CanvasOopRasterization,UseOzonePlatform,WebRTCPipeWireCapturer,Vulkan,DefaultANGLEVulkan,VulkanFromANGLE,ParallelDownloading,OverlayScrollbar,BackForwardCache,LightweightNoStatePrefetch
--disable-features=UseChromeOSDirectVideoDecoder
--enable-accelerated-video-decode
--enable-accelerated-video-encode
--enable-gpu-rasterization
--enable-zero-copy
--enable-oop-rasterization
--enable-raw-draw
--enable-hardware-overlays=single-fullscreen
--num-raster-threads=4
--renderer-process-limit=6
--disk-cache-size=536870912
--memory-model=low
--enable-quic
--enable-tcp-fast-open
--reduce-user-agent-minor-version
BRAVEFLAGS

    if [ ! -f "$BRAVE_CONFIG_DIR/Preferences" ]; then
        cat << 'BRAVEPREFS' > "$BRAVE_CONFIG_DIR/Preferences"
{
  "hardware_acceleration_mode": {"enabled": true},
  "browser": {
    "clear_data": {"cache": false, "cookies_on_exit": false},
    "smooth_scrolling": true,
    "enable_spellchecking": false
  },
  "profile": {
    "managed_user_id": "",
    "background_apps": false
  },
  "brave": {
    "stats": {"enabled": false},
    "p3a": {"enabled": false},
    "crash_reports_daily_limit": 0
  }
}
BRAVEPREFS
    fi
}

for bravedir in /home/*/.config/BraveSoftware/Brave-Browser/Default \
                /root/.config/BraveSoftware/Brave-Browser/Default; do
    if [ -d "$(dirname "$bravedir")" ]; then
        setup_brave_optimizations "$bravedir"
        echo "Brave optimizations applied: $bravedir"
    fi
done
mkdir -p /etc/skel/.config/BraveSoftware/Brave-Browser/Default
setup_brave_optimizations "/etc/skel/.config/BraveSoftware/Brave-Browser/Default"

# Brave launcher wrapper — must live in /usr/bin, not /usr/local/bin
# (/usr/local is reset on OSTree layer deployments)
cat << 'BRAVELAUNCHER' > /usr/bin/brave-optimized
#!/bin/bash
FLAGS_FILE="$HOME/.config/BraveSoftware/Brave-Browser/Default/raptor-brave-flags.conf"
EXTRA_FLAGS=""
if [ -f "$FLAGS_FILE" ]; then
    EXTRA_FLAGS=$(grep -v '^#' "$FLAGS_FILE" | grep -v '^$' | tr '\n' ' ')
fi
exec brave-browser $EXTRA_FLAGS "$@"
BRAVELAUNCHER
chmod +x /usr/bin/brave-optimized

# ── Background process trimmer ─────────────────────────────────────────────────
cat << 'TRIMMER' > /usr/bin/raptor-trim-background.sh
#!/bin/bash
echo "=== Raptor Background Trimmer ==="
sync
# 3 = drop page caches + dentries + inodes (1 = page only, 2 = dentry/inode only)
echo 3 > /proc/sys/vm/drop_caches
echo "✔ Dropped page/dentry/inode caches"
echo 1 > /proc/sys/vm/compact_memory 2>/dev/null || true
echo "✔ Compacted memory"

BACKGROUND_PROCS=(
    "tracker-miner" "tracker-store" "tracker3"
    "baloo_file" "baloo_file_extractor" "akonadi"
    "kded" "kdeconnectd" "gvfs" "zeitgeist"
    "tumblerd" "packagekitd" "apt-get" "dpkg"
    "updatedb" "mlocate" "snapd" "unattended-upgrade"
    "evolution" "gnome-software"
)
for proc in "${BACKGROUND_PROCS[@]}"; do
    pkill -STOP "$proc" 2>/dev/null || true
done
echo "✔ Paused background indexers"

for proc in baloo tracker zeitgeist; do
    for pid in $(pgrep -x "$proc" 2>/dev/null); do
        ionice -c 3 -p "$pid" 2>/dev/null || true
        renice +15 -p "$pid" 2>/dev/null || true
    done
done
echo "✔ IO-niced & re-niced indexers"

if systemctl is-active snapd &>/dev/null; then
    systemctl stop snapd.service 2>/dev/null || true
    echo "✔ Stopped snapd"
fi

kbuildsycoca6 --invalidate 2>/dev/null || true
balooctl6 suspend 2>/dev/null || balooctl suspend 2>/dev/null || true
echo "✔ Suspended Baloo indexer"

systemctl stop fstrim.service 2>/dev/null || true
echo 6000 > /proc/sys/vm/dirty_writeback_centisecs
echo "interactive" > /sys/kernel/debug/sched/tunable 2>/dev/null || true

echo ""
echo "=== Background trim complete. Start your game now. ==="
echo "Run 'raptor-restore-background.sh' after gaming to resume services."
TRIMMER
chmod +x /usr/bin/raptor-trim-background.sh

cat << 'RESTORE' > /usr/bin/raptor-restore-background.sh
#!/bin/bash
echo "=== Raptor: Restoring background services ==="
for proc in tracker-miner tracker-store tracker3 baloo_file baloo_file_extractor \
            akonadi kded kdeconnectd gvfs zeitgeist tumblerd; do
    pkill -CONT "$proc" 2>/dev/null || true
done
echo "✔ Resumed background processes"
balooctl6 resume 2>/dev/null || balooctl resume 2>/dev/null || true
echo "✔ Resumed Baloo"
systemctl start snapd.service 2>/dev/null || true
echo 500 > /proc/sys/vm/dirty_writeback_centisecs
echo "=== Background services restored ==="
RESTORE
chmod +x /usr/bin/raptor-restore-background.sh

# sudoers: allow passwordless background trim/restore
cat << 'SUDOERS' >> /etc/sudoers.d/raptor-gpu
ALL ALL=(root) NOPASSWD: /usr/bin/raptor-trim-background.sh
ALL ALL=(root) NOPASSWD: /usr/bin/raptor-restore-background.sh
ALL ALL=(root) NOPASSWD: /usr/bin/raptor-zram-teardown.sh
SUDOERS

# ── Vesktop: system-level Flatpak overrides ────────────────────────────────────
# Run on the build image so every user gets Wayland-native Vesktop out of the box.
# Per-user memory flags (V8 heap cap, renderer limit) are written by
# raptor-appconfig.sh on first login, since flatpak override --user is per-user.
if command -v flatpak &>/dev/null; then
    flatpak override --system dev.vencord.Vesktop \
        --env=OZONE_PLATFORM=wayland \
        --env=ELECTRON_OZONE_PLATFORM_HINT=auto \
        2>/dev/null || true
    echo "Vesktop: system-level Flatpak overrides applied (Wayland-native)"
fi

# ── Baseline sysctl: sane memory defaults shipped in the image ────────────────
# These are overridden at runtime by raptor-cortex (per-mode tuning).
# Goal: reduce kernel's eagerness to keep stale pages, keep swap minimal.
cat << 'SYSCTL' > /etc/sysctl.d/90-raptor-memory.conf
# Raptor OS: baseline memory tuning
# These values are conservative defaults; raptor-cortex applies profile-specific
# overrides at runtime (e.g., swappiness=180 in performance mode).

# Prefer keeping processes in RAM over evicting to swap
vm.swappiness = 10

# VFS inode/dentry cache: default=100 (aggressively reclaims caches).
# 50 = hold caches 2× longer — benefits games that reload the same assets.
vm.vfs_cache_pressure = 50

# Dirty page writeback: flush at 10% RAM dirty, background flush at 3%.
vm.dirty_ratio = 10
vm.dirty_background_ratio = 3

# Writeback interval: 15 s (batches I/O, reduces storage wake-ups).
vm.dirty_writeback_centisecs = 1500
vm.dirty_expire_centisecs = 3000

# OOM killer: be more decisive (kills one process rather than thrashing).
vm.oom_kill_allocating_task = 0
vm.panic_on_oom = 0

# Prevent address space exhaustion from many small anonymous mappings.
vm.max_map_count = 2147483642

# Keep a larger pool of free pages on hand so allocations under memory
# pressure (a game requesting a large texture buffer, etc.) don't stall
# waiting for synchronous reclaim. 128 MB is generous for 8GB+ systems;
# the kernel default (usually ~4-16 MB on desktop) is too thin for
# bursty allocation patterns common in games.
vm.min_free_kbytes = 131072

# Disable watermark boost — the default (250%) causes sudden large reclaim
# bursts that show up as gaming stutters. 0 = reclaim gradually instead.
vm.watermark_boost_factor = 0

# Group related processes for scheduling (games + their threads vs background).
# Improves responsiveness of the foreground game vs background daemons.
kernel.sched_autogroup_enabled = 1
SYSCTL

# ── Systemd user drop-ins: cap RAM on the heaviest background services ─────────
# These sit in the user service manager cgroup and prevent baloo / akonadi
# from quietly consuming hundreds of MB while a game is running.
# Users who need more headroom for mail/search can raise these in their own
# ~/.config/systemd/user/ overrides.

for svc_dir in \
    "baloo_file.service.d" \
    "akonadiserver.service.d" \
    "kdeconnectd.service.d" \
    "evolution-data-server.service.d" \
    "tracker-miner-fs-3.service.d" \
    "kactivitymanagerd.service.d"
do
    mkdir -p "/etc/systemd/user/${svc_dir}"
done

cat << 'DROP' > /etc/systemd/user/baloo_file.service.d/raptor-memcap.conf
# Raptor OS: hard cap on Baloo file indexer
# Default: unbounded. During peak indexing it can exceed 400 MB.
[Service]
MemoryHigh=64M
MemoryMax=128M
DROP

cat << 'DROP' > /etc/systemd/user/akonadiserver.service.d/raptor-memcap.conf
# Raptor OS: hard cap on Akonadi PIM server
# Most Raptor users don't use KDE PIM; cap prevents runaway growth.
[Service]
MemoryHigh=128M
MemoryMax=256M
DROP

cat << 'DROP' > /etc/systemd/user/kdeconnectd.service.d/raptor-memcap.conf
[Service]
MemoryHigh=48M
MemoryMax=96M
DROP

cat << 'DROP' > /etc/systemd/user/evolution-data-server.service.d/raptor-memcap.conf
[Service]
MemoryHigh=64M
MemoryMax=128M
DROP

cat << 'DROP' > /etc/systemd/user/tracker-miner-fs-3.service.d/raptor-memcap.conf
# tracker-miner-fs-3 (GNOME file tracker) — may not exist on KDE but harmless if so.
[Service]
MemoryHigh=48M
MemoryMax=96M
DROP

cat << 'DROP' > /etc/systemd/user/kactivitymanagerd.service.d/raptor-memcap.conf
# Activity tracking daemon — most users never use KDE Activities, but it
# runs by default and its SQLite usage-tracking DB grows over time.
[Service]
MemoryHigh=48M
MemoryMax=96M
DROP

echo "Memory caps installed for background services."

# ── journald: cap in-memory/disk usage ────────────────────────────────────────
# journald keeps a chunk of recent logs in a tmpfs-backed runtime journal
# (/run/log/journal) — this is RAM. Default limits scale with disk/RAM size
# and can reach several hundred MB. Capping both runtime (RAM) and persistent
# (disk) journals keeps logging from quietly eating into available memory.
mkdir -p /etc/systemd/journald.conf.d
cat << 'JOURNALD' > /etc/systemd/journald.conf.d/raptor-memory.conf
[Journal]
# Runtime journal lives in /run (tmpfs = RAM). Cap it small.
RuntimeMaxUse=64M
# Persistent journal on disk — generous enough for troubleshooting,
# small enough not to matter on any modern SSD.
SystemMaxUse=200M
JOURNALD

# ── Mask ModemManager ──────────────────────────────────────────────────────────
# ModemManager probes for cellular/WWAN hardware on every boot and stays
# resident. Desktop and laptop gaming systems essentially never have a modem.
# Masking (symlink to /dev/null) fully prevents it from starting; users with
# a WWAN card can re-enable with: sudo systemctl unmask ModemManager.service
mkdir -p /etc/systemd/system
ln -sf /dev/null /etc/systemd/system/ModemManager.service

# ── Game launch option hints ───────────────────────────────────────────────────
cat << 'EOF' > /etc/raptor/unturned-launch-options.txt
Recommended Steam launch options for Unturned (Unity / low-RAM systems):

  PROTON_FORCE_LARGE_ADDRESS_AWARE=1 STAGING_SHARED_MEMORY=1 \
  WINE_LARGE_ADDRESS_AWARE=1 DXVK_ASYNC=1 %command% \
    -gc.maxreserved 128 \
    -force-gfx-jobs native \
    -disable-gpu-skinning \
    -no-sandbox \
    -force-vulkan

Notes:
  -gc.maxreserved 128     Cap Unity's reserved GC heap to 128 MB
  -force-gfx-jobs native  Native threads for graphics jobs
  -disable-gpu-skinning   Moves skinning to CPU (frees iGPU VRAM)
  -no-sandbox             Removes Chromium sandbox (~40 MB address space savings)
  -force-vulkan           Use Vulkan renderer (better on Mesa/RADV)
  DXVK_ASYNC=1            Async shader compilation (reduces stutter)
EOF

cat << 'EOF' > /etc/raptor/zomboid-launch-options.txt
Recommended Steam launch options for Project Zomboid:

  PROTON_FORCE_LARGE_ADDRESS_AWARE=1 STAGING_SHARED_MEMORY=1 \
  WINE_LARGE_ADDRESS_AWARE=1 %command% \
    -Xmx4096m \
    -Xms512m \
    -XX:+UseG1GC \
    -XX:MaxGCPauseMillis=20

Notes:
  -Xmx4096m     Cap Java heap at 4 GB (adjust to your RAM)
  -Xms512m      Start JVM heap small
  -XX:+UseG1GC  G1 GC — fewer long pauses vs default collector
EOF

# ── MangoHud: Raptor OS themed HUD config ─────────────────────────────────────
mkdir -p /etc/mangohud
cat << 'MANGOCFG' > /etc/mangohud/MangoHud.conf
# ── Raptor OS MangoHud default ────────────────────────────────────────────────
toggle_hud=Shift_R+F12
toggle_fps_limit=Shift_R+F1
position=top-left
legacy_layout=false
hud_compact=false
round_corners=6
fps
frametime
frame_timing=1
gpu_stats
gpu_temp
gpu_core_clock
gpu_mem_clock
gpu_power
gpu_load_change
cpu_stats
cpu_temp
cpu_mhz
ram
vram
wine
engine_version
fps_color_change=1
fps_value=45,60
fps_color=FF4040,F5C211,33FF33
background_color=020F12
background_alpha=0.55
text_color=E8F4F8
gpu_color=00D4FF
cpu_color=33FF33
memory_color=A8FF78
engine_color=F5A623
frametime_color=00E5FF
text_outline=true
font_size=20
font_file=/usr/share/fonts/jetbrains-mono/JetBrainsMono-Regular.ttf
fps_limit=0
MANGOCFG

# ── Gamemode: full configuration ──────────────────────────────────────────────
cat << 'GAMEMODE' > /etc/gamemode.ini
[general]
reaper_freq=5
desired_governor=performance
igpu_desiredgov=powersave
gpu_device=auto
defaultgov=powersave
softrealtime=auto
renice=10
inhibit_screensaver=1

[filter]
whitelist=
blacklist=

[gpu]
apply_gpu_optimisations=accept-responsibility
gpu_device=0
amd_performance_level=high

[cpu]
park_cores=no
pin_cores=no

[supervisor]
supervisor_whitelist=steam,heroic,lutris,bottles
GAMEMODE

# ── Input device udev rules ───────────────────────────────────────────────────
cat << 'INPUTRULES' > /usr/lib/udev/rules.d/61-raptor-input.rules
# Disable USB autosuspend for all HID input devices (mice, keyboards, pads).
# Autosuspend saves ~0.5 W but causes 16-500 ms input latency spikes on wake.
ACTION=="add", SUBSYSTEM=="usb", DRIVERS=="usbhid", \
    ATTR{power/autosuspend}="-1"

# uinput: allow user-space to create virtual devices (antimicro, xpadneo, etc.)
KERNEL=="uinput", SUBSYSTEM=="misc", \
    OPTIONS+="static_node=uinput", TAG+="uaccess", TAG+="udev-acl", \
    MODE="0660", GROUP="input"

# Xbox controllers
SUBSYSTEM=="input", ATTRS{name}=="Xbox*", TAG+="uaccess"
SUBSYSTEM=="input", ATTRS{name}=="Microsoft X-Box*", TAG+="uaccess"

# Sony DualSense / DualShock — hidraw access for Chiaki / PS Remote Play
SUBSYSTEM=="hidraw", ATTRS{idVendor}=="054c", TAG+="uaccess"
KERNEL=="hidraw*", ATTRS{idVendor}=="054c", MODE="0660", GROUP="input"

# Steam Controller / Valve Index
SUBSYSTEM=="hidraw", ATTRS{idVendor}=="28de", TAG+="uaccess"
KERNEL=="hidraw*", ATTRS{idVendor}=="28de", MODE="0660", GROUP="input"
INPUTRULES
udevadm control --reload-rules 2>/dev/null || true

# ── Fastfetch: Raptor OS themed config ────────────────────────────────────────
mkdir -p /etc/xdg/fastfetch
cat << 'FFCONF' > /etc/xdg/fastfetch/config.jsonc
{
  "$schema": "https://github.com/fastfetch-cli/fastfetch/raw/dev/doc/json_schema.json",
  "logo": { "source": "small", "color": { "1": "green", "2": "cyan" } },
  "display": {
    "separator": "  ",
    "color": { "keys": "green", "title": "cyan", "output": "white" },
    "brightColor": true
  },
  "modules": [
    { "type": "title",    "format": "{user-name}@{host-name}" },
    "break",
    { "type": "os",       "key": "OS       " },
    { "type": "kernel",   "key": "Kernel   " },
    { "type": "uptime",   "key": "Uptime   " },
    { "type": "packages", "key": "Packages " },
    { "type": "shell",    "key": "Shell    " },
    "break",
    { "type": "de",       "key": "Desktop  " },
    { "type": "wm",       "key": "WM       " },
    { "type": "theme",    "key": "Theme    " },
    "break",
    { "type": "cpu",      "key": "CPU      " },
    { "type": "gpu",      "key": "GPU      ", "detectionMethod": "pci" },
    { "type": "memory",   "key": "RAM      " },
    { "type": "swap",     "key": "Swap     " },
    { "type": "disk",     "key": "Disk     ", "folders": "/" },
    "break",
    { "type": "localip",  "key": "IP       " },
    "break",
    "colors"
  ]
}
FFCONF
mkdir -p /etc/skel/.config/fastfetch
cp /etc/xdg/fastfetch/config.jsonc /etc/skel/.config/fastfetch/config.jsonc


# ── Network gaming sysctl ─────────────────────────────────────────────────────
cat << 'NETSYSCTL' > /etc/sysctl.d/91-raptor-network.conf
# Raptor OS: network gaming optimisation
net.core.rmem_max                  = 134217728
net.core.wmem_max                  = 134217728
net.core.rmem_default              = 262144
net.core.wmem_default              = 262144
net.ipv4.tcp_rmem                  = 4096 262144 134217728
net.ipv4.tcp_wmem                  = 4096 262144 134217728
net.ipv4.udp_rmem_min              = 8192
net.ipv4.udp_wmem_min              = 8192
net.core.default_qdisc             = cake
net.ipv4.tcp_congestion_control    = bbr
net.ipv4.tcp_fastopen              = 3
net.ipv4.tcp_tw_reuse              = 1
net.ipv4.tcp_fin_timeout           = 15
net.ipv4.tcp_max_tw_buckets        = 1440000
net.ipv4.tcp_slow_start_after_idle = 0
net.ipv4.tcp_no_metrics_save       = 1
net.core.netdev_max_backlog        = 50000
net.core.netdev_budget             = 600
net.core.netdev_budget_usecs       = 8000
net.core.somaxconn                 = 65535
net.ipv4.neigh.default.gc_thresh1  = 4096
net.ipv4.neigh.default.gc_thresh2  = 8192
net.ipv4.neigh.default.gc_thresh3  = 16384
net.ipv4.ip_local_port_range       = 1024 65535
NETSYSCTL

# ── BBR / CAKE module preload ─────────────────────────────────────────────────
cat << 'MODULES' > /etc/modules-load.d/raptor-network.conf
# Raptor OS: load BBR + CAKE at initramfs so sysctl can reference them
tcp_bbr
sch_cake
MODULES

# ── DNS-over-TLS ──────────────────────────────────────────────────────────────
mkdir -p /etc/systemd/resolved.conf.d
cat << 'RESOLVED' > /etc/systemd/resolved.conf.d/raptor-dns.conf
# Raptor OS: Cloudflare DoT resolver — faster than ISP default (~10 ms global)
[Resolve]
DNS=1.1.1.1#cloudflare-dns.com 1.0.0.1#cloudflare-dns.com
FallbackDNS=9.9.9.9#dns.quad9.net 8.8.8.8#dns.google
DNSOverTLS=opportunistic
DNSSEC=allow-downgrade
Cache=yes
DNSStubListener=yes
RESOLVED

echo "GAMING_READY"
