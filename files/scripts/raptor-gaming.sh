#!/bin/bash
set -oue pipefail

# ═══════════════════════════════════════════════════════════════════════════════
# Raptor OS — Gaming & System Optimization  v2.0
# Covers: Lutris, Steam, ulimits, browser hardening (Firefox + Brave),
#         background process trimmer, ZRAM setup, and I/O scheduler tuning.
# ═══════════════════════════════════════════════════════════════════════════════

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
# Prefer mq-deadline for NVMe (low latency), bfq for rotational (better fairness)
cat << 'EOF' > /usr/lib/udev/rules.d/60-raptor-iosched.rules
# Raptor OS I/O scheduler rules
# NVMe / SSD: mq-deadline for lowest latency
ACTION=="add|change", KERNEL=="nvme[0-9]*", ATTR{queue/scheduler}="mq-deadline"
ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/rotational}=="0", ATTR{queue/scheduler}="mq-deadline"
# HDD: bfq gives best interactivity under load
ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/rotational}=="1", ATTR{queue/scheduler}="bfq"
# Large queue depth for NVMe
ACTION=="add|change", KERNEL=="nvme[0-9]*", ATTR{queue/nr_requests}="2048"
# Read-ahead: larger for HDD, smaller for SSD
ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/rotational}=="1", ATTR{queue/read_ahead_kb}="2048"
ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/rotational}=="0", ATTR{queue/read_ahead_kb}="256"
EOF
udevadm control --reload-rules 2>/dev/null || true

# ── ZRAM swap setup ────────────────────────────────────────────────────────────
# ZRAM compresses RAM into itself — much faster than disk swap, great for gaming
TOTAL_RAM_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
TOTAL_RAM_GB=$(( TOTAL_RAM_KB / 1024 / 1024 ))
# ZRAM size = half of physical RAM, capped at 8 GB
ZRAM_SIZE_GB=$(( TOTAL_RAM_GB / 2 ))
[ "$ZRAM_SIZE_GB" -lt 1 ] && ZRAM_SIZE_GB=1
[ "$ZRAM_SIZE_GB" -gt 8 ] && ZRAM_SIZE_GB=8

cat << ZRAMEOF > /etc/systemd/system/raptor-zram.service
[Unit]
Description=Raptor OS ZRAM Swap
After=local-fs.target
DefaultDependencies=no

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/bin/raptor-zram-setup.sh
ExecStop=/usr/bin/raptor-zram-teardown.sh

[Install]
WantedBy=multi-user.target
ZRAMEOF

cat << ZRAMSCRIPT > /usr/bin/raptor-zram-setup.sh
#!/bin/bash
modprobe zram 2>/dev/null || true
sleep 0.2
ZDEV=\$(zramctl --find --size ${ZRAM_SIZE_GB}G --algorithm zstd 2>/dev/null || \
        zramctl --find --size ${ZRAM_SIZE_GB}G --algorithm lz4 2>/dev/null)
if [ -n "\$ZDEV" ]; then
    mkswap "\$ZDEV"
    swapon -p 100 "\$ZDEV"
    echo "ZRAM swap on \$ZDEV (${ZRAM_SIZE_GB}G)"
fi
ZRAMSCRIPT
chmod +x /usr/bin/raptor-zram-setup.sh

cat << 'TEARDOWN' > /usr/bin/raptor-zram-teardown.sh
#!/bin/bash
for dev in $(zramctl --noheadings --output NAME 2>/dev/null); do
    swapoff "$dev" 2>/dev/null || true
    zramctl --reset "$dev" 2>/dev/null || true
done
TEARDOWN
chmod +x /usr/bin/raptor-zram-teardown.sh
systemctl enable raptor-zram.service 2>/dev/null || true

# ── Firefox optimization profile ───────────────────────────────────────────────
# Writes a user.js to every existing Firefox profile on the system.
# Also creates /etc/skel default so new users get it automatically.
setup_firefox_optimizations() {
    local PROFILE_DIR="$1"
    cat << 'FFJS' > "$PROFILE_DIR/user.js"
// ── Raptor OS: Firefox Performance & Privacy Hardening ─────────────────────
// Applied automatically — do not edit (will be overwritten on updates).

// ── Rendering / GPU ──────────────────────────────────────────────────────────
user_pref("layers.acceleration.enabled", true);
user_pref("gfx.webrender.all", true);
user_pref("gfx.webrender.compositor", true);
user_pref("gfx.webrender.compositor.force-enabled", true);
user_pref("media.hardware-video-decoding.enabled", true);
user_pref("media.hardware-video-decoding.force-enabled", true);
// Offload compositing to GPU thread
user_pref("layers.offmainthreadcomposition.enabled", true);
user_pref("dom.webgpu.enabled", true);

// ── Process & memory ─────────────────────────────────────────────────────────
// Use more content processes (better tab isolation + perf)
user_pref("dom.ipc.processCount", 8);
user_pref("dom.ipc.processCount.webIsolated", 4);
// Trim RAM aggressively when minimized
user_pref("config.trim_on_minimize", true);
// Limit back-forward cache to save RAM
user_pref("browser.sessionhistory.max_total_viewers", 4);
// Reduce memory cache size (in KB) — 256 MB
user_pref("browser.cache.memory.capacity", 262144);
// Disk cache: 512 MB max
user_pref("browser.cache.disk.capacity", 524288);
// Garbage collect more aggressively
user_pref("javascript.options.mem.gc_incremental_slice_ms", 5);
user_pref("javascript.options.mem.gc_min_number_of_chunks", 16);

// ── Network ──────────────────────────────────────────────────────────────────
user_pref("network.http.max-connections", 900);
user_pref("network.http.max-connections-per-server", 32);
user_pref("network.http.max-persistent-connections-per-server", 10);
user_pref("network.http.pipelining", true);
user_pref("network.http.pipelining.maxrequests", 8);
user_pref("network.http.proxy.pipelining", true);
user_pref("network.prefetch-next", true);
user_pref("network.dns.disablePrefetch", false);
user_pref("network.predictor.enabled", true);
// DoH via Cloudflare (fast, private) — remove if you prefer system DNS
user_pref("network.trr.mode", 2);
user_pref("network.trr.uri", "https://cloudflare-dns.com/dns-query");

// ── Telemetry & bloat OFF ────────────────────────────────────────────────────
user_pref("toolkit.telemetry.enabled", false);
user_pref("toolkit.telemetry.unified", false);
user_pref("toolkit.telemetry.server", "");
user_pref("datareporting.healthreport.uploadEnabled", false);
user_pref("datareporting.policy.dataSubmissionEnabled", false);
user_pref("browser.ping-centre.telemetry", false);
user_pref("app.shield.optoutstudies.enabled", false);
user_pref("extensions.shield-recipe-client.enabled", false);
user_pref("browser.newtabpage.activity-stream.feeds.telemetry", false);
user_pref("browser.newtabpage.activity-stream.telemetry", false);
// Disable Pocket
user_pref("extensions.pocket.enabled", false);
// Disable sponsored content on new tab
user_pref("browser.newtabpage.activity-stream.showSponsored", false);
user_pref("browser.newtabpage.activity-stream.showSponsoredTopSites", false);
// Disable crash reporter
user_pref("breakpad.reportURL", "");
user_pref("browser.tabs.crashReporting.sendReport", false);

// ── Startup ──────────────────────────────────────────────────────────────────
// Don't restore previous session crash dialogs
user_pref("browser.sessionstore.resume_from_crash", false);
// Reduce startup I/O
user_pref("browser.shell.checkDefaultBrowser", false);
user_pref("browser.rights.3.shown", true);

// ── Scroll / animation smoothness ────────────────────────────────────────────
user_pref("apz.allow_zooming", true);
user_pref("general.smoothScroll", true);
user_pref("general.smoothScroll.mouseWheel.durationMinMS", 80);
user_pref("general.smoothScroll.mouseWheel.durationMaxMS", 200);
user_pref("mousewheel.system_scroll_override.enabled", true);
FFJS
}

# Apply to any existing user Firefox profiles
for profdir in /home/*/.mozilla/firefox/*.default* \
               /home/*/.mozilla/firefox/*.default-release \
               /root/.mozilla/firefox/*.default*; do
    if [ -d "$profdir" ]; then
        setup_firefox_optimizations "$profdir"
        echo "Firefox optimizations applied: $profdir"
    fi
done

# Skeleton for new users
mkdir -p /etc/skel/.mozilla/firefox/raptor-default
setup_firefox_optimizations "/etc/skel/.mozilla/firefox/raptor-default"

# ── Brave optimization ─────────────────────────────────────────────────────────
# Brave uses Chromium flags — write to the Preferences JSON and a flags file
setup_brave_optimizations() {
    local BRAVE_CONFIG_DIR="$1"
    mkdir -p "$BRAVE_CONFIG_DIR"

    # Command-line flags via the "Local State" or flags file
    cat << 'BRAVEFLAGS' > "$BRAVE_CONFIG_DIR/raptor-brave-flags.conf"
# Raptor OS: Brave / Chromium performance flags
# Source this file or copy flags to brave-flags.conf or the Brave launcher.
--enable-features=VaapiVideoDecoder,VaapiVideoEncoder,CanvasOopRasterization,UseOzonePlatform,WebRTCPipeWireCapturer,Vulkan,DefaultANGLEVulkan,VulkanFromANGLE,ParallelDownloading,OverlayScrollbar,BackForwardCache,LightweightNoStatePrefetch
--disable-features=UseChromeOSDirectVideoDecoder
--enable-accelerated-video-decode
--enable-accelerated-video-encode
--enable-gpu-rasterization
--enable-zero-copy
--enable-oop-rasterization
--enable-raw-draw
--use-gl=desktop
--enable-hardware-overlays=single-fullscreen
--num-raster-threads=4
--renderer-process-limit=6
--disk-cache-size=536870912
--memory-model=low
--enable-quic
--enable-tcp-fast-open
--reduce-user-agent-minor-version
BRAVEFLAGS

    # Brave-specific preferences for performance
    # Only write if Preferences doesn't already exist (new profile)
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

# Apply to existing Brave profiles
for bravedir in /home/*/.config/BraveSoftware/Brave-Browser/Default \
                /root/.config/BraveSoftware/Brave-Browser/Default; do
    if [ -d "$(dirname $bravedir)" ]; then
        setup_brave_optimizations "$bravedir"
        echo "Brave optimizations applied: $bravedir"
    fi
done
mkdir -p /etc/skel/.config/BraveSoftware/Brave-Browser/Default
setup_brave_optimizations "/etc/skel/.config/BraveSoftware/Brave-Browser/Default"

# Brave launcher wrapper — injects flags automatically
cat << 'BRAVELAUNCHER' > /usr/local/bin/brave-optimized
#!/bin/bash
# Raptor OS: Brave with performance flags
FLAGS_FILE="$HOME/.config/BraveSoftware/Brave-Browser/Default/raptor-brave-flags.conf"
EXTRA_FLAGS=""
if [ -f "$FLAGS_FILE" ]; then
    EXTRA_FLAGS=$(grep -v '^#' "$FLAGS_FILE" | grep -v '^$' | tr '\n' ' ')
fi
exec brave-browser $EXTRA_FLAGS "$@"
BRAVELAUNCHER
chmod +x /usr/local/bin/brave-optimized

# ── Background process trimmer ─────────────────────────────────────────────────
cat << 'TRIMMER' > /usr/bin/raptor-trim-background.sh
#!/bin/bash
# Raptor OS: Background Process Optimizer
# Reduces CPU/RAM usage of non-game background services.
# Safe to run before gaming; services are only degraded, not killed.

echo "=== Raptor Background Trimmer ==="

# 1. Sync & drop page caches (safe — kernel will repopulate on demand)
sync
echo 1 > /proc/sys/vm/drop_caches
echo "✔ Dropped page caches"

# 2. Compact memory (reduces fragmentation)
echo 1 > /proc/sys/vm/compact_memory 2>/dev/null || true
echo "✔ Compacted memory"

# 3. Reduce nice priority of known background hogs
BACKGROUND_PROCS=(
    "tracker-miner"
    "tracker-store"
    "tracker3"
    "baloo_file"
    "baloo_file_extractor"
    "akonadi"
    "kded"
    "kdeconnectd"
    "gvfs"
    "zeitgeist"
    "tumblerd"
    "packagekitd"
    "apt-get"
    "dpkg"
    "updatedb"
    "mlocate"
    "snapd"
    "unattended-upgrade"
    "evolution"
    "gnome-software"
)
for proc in "${BACKGROUND_PROCS[@]}"; do
    pkill -STOP "$proc" 2>/dev/null || true   # pause indexers
done
echo "✔ Paused background indexers (Baloo, Tracker, Zeitgeist)"

# 4. Freeze KDE/GNOME indexers via ionice too
for proc in baloo tracker zeitgeist; do
    for pid in $(pgrep -x "$proc" 2>/dev/null); do
        ionice -c 3 -p "$pid" 2>/dev/null || true
        renice +15 -p "$pid"  2>/dev/null || true
    done
done
echo "✔ IO-niced & re-niced indexers"

# 5. Throttle snap daemon if present
if systemctl is-active snapd &>/dev/null; then
    systemctl stop snapd.service 2>/dev/null || true
    echo "✔ Stopped snapd (re-enable after gaming with: systemctl start snapd)"
fi

# 6. Suspend KDE's file indexer
kbuildsycoca6 --invalidate 2>/dev/null || true
balooctl6 suspend 2>/dev/null || \
    balooctl  suspend 2>/dev/null || true
echo "✔ Suspended Baloo indexer"

# 7. Reduce preload/fstrim service impact
systemctl stop fstrim.service 2>/dev/null || true

# 8. Set dirty writeback to 60s (fewer I/O interruptions during gaming)
echo 6000 > /proc/sys/vm/dirty_writeback_centisecs

# 9. Set CPU scheduler to prefer interactive (game) tasks
echo "interactive" > /sys/kernel/debug/sched/tunable 2>/dev/null || true

echo ""
echo "=== Background trim complete. Start your game now. ==="
echo "Run 'raptor-restore-background.sh' after gaming to resume services."
TRIMMER
chmod +x /usr/bin/raptor-trim-background.sh

# Companion restore script
cat << 'RESTORE' > /usr/bin/raptor-restore-background.sh
#!/bin/bash
echo "=== Raptor: Restoring background services ==="

# Resume paused processes
for proc in tracker-miner tracker-store tracker3 baloo_file baloo_file_extractor \
            akonadi kded kdeconnectd gvfs zeitgeist tumblerd; do
    pkill -CONT "$proc" 2>/dev/null || true
done
echo "✔ Resumed background processes"

# Resume Baloo
balooctl6 resume 2>/dev/null || \
    balooctl  resume 2>/dev/null || true
echo "✔ Resumed Baloo"

# Restore snapd
systemctl start snapd.service 2>/dev/null || true

# Restore dirty writeback to default (5s)
echo 500 > /proc/sys/vm/dirty_writeback_centisecs

echo "=== Background services restored ==="
RESTORE
chmod +x /usr/bin/raptor-restore-background.sh

# sudoers: allow passwordless background trim/restore
cat << 'SUDOERS' >> /etc/sudoers.d/raptor-gpu
ALL ALL=(root) NOPASSWD: /usr/bin/raptor-trim-background.sh
ALL ALL=(root) NOPASSWD: /usr/bin/raptor-restore-background.sh
ALL ALL=(root) NOPASSWD: /usr/bin/raptor-zram-setup.sh
ALL ALL=(root) NOPASSWD: /usr/bin/raptor-zram-teardown.sh
SUDOERS

# ── Unturned / Unity launch options ────────────────────────────────────────────
mkdir -p /etc/raptor
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
  -force-gfx-jobs native  Native threads for graphics jobs (less fragmentation)
  -disable-gpu-skinning   Moves skinning to CPU (frees iGPU VRAM)
  -no-sandbox             Removes Chromium sandbox (~40 MB address space savings)
  -force-vulkan           Use Vulkan renderer (better performance on Mesa/RADV)
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
  -Xms512m      Start JVM heap small (avoids over-allocation at launch)
  -XX:+UseG1GC  G1 GC — fewer long pauses vs default collector
EOF

echo "Hint files written to /etc/raptor/"
echo "GAMING_READY"
