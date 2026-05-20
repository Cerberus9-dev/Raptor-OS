#!/bin/bash
set -oue pipefail

# =============================================================================
# Raptor OS — Performance Script v2
# DNS · WiFi · I/O scheduler · sysctl · zram · CPU governor · gamemode
# Firefox heavy optimization · Brave heavy optimization · bg-process masking
# =============================================================================

# ── DNS ───────────────────────────────────────────────────────────────────────
mkdir -p /etc/systemd/resolved.conf.d
cat << 'CONF' > /etc/systemd/resolved.conf.d/dns.conf
[Resolve]
DNS=1.1.1.1 1.0.0.1 2606:4700:4700::1111 2606:4700:4700::1001
FallbackDNS=8.8.8.8 8.8.4.4 2001:4860:4860::8888
DNSSEC=allow-downgrade
DNSOverTLS=opportunistic
Cache=yes
CacheFromLocalhost=no
CONF

# ── WiFi power management ─────────────────────────────────────────────────────
mkdir -p /etc/NetworkManager/conf.d
cat << 'CONF' > /etc/NetworkManager/conf.d/raptor-wifi.conf
[connection]
wifi.powersave=2
[device]
wifi.scan-rand-mac-address=no
CONF

# ── I/O scheduler ─────────────────────────────────────────────────────────────
# NVMe → none (has its own internal queue management)
# SSD  → mq-deadline (low latency, no seek penalty)
# HDD  → bfq (budget fair queueing, best for rotational)
cat << 'CONF' > /etc/udev/rules.d/raptor-io-scheduler.rules
# NVMe — internal queuing is best, no extra scheduler needed
ACTION=="add|change", KERNEL=="nvme[0-9]*", ATTR{queue/scheduler}="none"
# SSD — mq-deadline for minimal latency
ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/rotational}=="0", ATTR{queue/scheduler}="mq-deadline"
# HDD — BFQ for fairness & responsiveness under heavy I/O
ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/rotational}=="1", ATTR{queue/scheduler}="bfq"
# NVMe queue depth
ACTION=="add|change", KERNEL=="nvme[0-9]*", ATTR{queue/nr_requests}="2048"
# Raise SSD read-ahead slightly for large sequential reads
ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/rotational}=="0", ATTR{queue/read_ahead_kb}="256"
CONF

# ── Firefox heavy optimization ────────────────────────────────────────────────
mkdir -p /usr/lib/firefox/defaults/pref \
         /usr/lib64/firefox/defaults/pref

for FIREFOX_DIR in /usr/lib/firefox /usr/lib64/firefox; do
    [ -d "$FIREFOX_DIR" ] || continue

    cat << 'CONF' > "$FIREFOX_DIR/mozilla.cfg"
// ── Raptor OS: Firefox Heavy Optimization ──────────────────────────────────

// --- Hardware acceleration & GPU compositing ---
lockPref("gfx.webrender.all", true);
lockPref("gfx.webrender.compositor", true);
lockPref("gfx.webrender.compositor.force-enabled", true);
lockPref("gfx.webrender.software.opengl", false);
lockPref("layers.acceleration.force-enabled", true);
lockPref("media.hardware-video-decoding.enabled", true);
lockPref("media.hardware-video-decoding.force-enabled", true);
lockPref("media.ffmpeg.vaapi.enabled", true);
lockPref("media.av1.enabled", true);
lockPref("media.gpu-process-decoder", true);
lockPref("media.rdd-process.enabled", true);
lockPref("dom.webgpu.enabled", true);

// --- Memory limits ---
lockPref("browser.cache.memory.capacity", 131072);
lockPref("browser.cache.memory.max_entry_size", 51200);
lockPref("browser.sessionhistory.max_entries", 5);
lockPref("browser.sessionhistory.max_total_viewers", 1);
lockPref("browser.tabs.unloadOnLowMemory", true);
lockPref("browser.low_commit_space_threshold_mb", 256);
lockPref("javascript.options.mem.max", 512);
lockPref("javascript.options.mem.gc_incremental_slice_ms", 5);
lockPref("javascript.options.mem.high_water_mark", 256);
lockPref("javascript.options.mem.gc_high_frequency_time_limit_ms", 1000);
lockPref("javascript.options.mem.gc_dynamic_heap_growth", true);
lockPref("javascript.options.mem.gc_dynamic_mark_slice", true);

// --- Process count (balance memory vs. isolation) ---
lockPref("dom.ipc.processCount", 4);
lockPref("dom.ipc.processCount.webIsolated", 1);

// --- Network performance ---
lockPref("network.http.max-connections", 900);
lockPref("network.http.max-persistent-connections-per-server", 10);
lockPref("network.http.pipelining", true);
lockPref("network.http.pipelining.maxrequests", 8);
lockPref("network.http.pipelining.ssl", true);
lockPref("network.http.proxy.pipelining", true);
lockPref("network.prefetch-next", false);
lockPref("network.dns.disablePrefetch", true);
lockPref("network.predictor.enabled", false);
lockPref("network.http.speculative-parallel-limit", 0);

// --- Background & telemetry OFF ---
lockPref("toolkit.telemetry.enabled", false);
lockPref("toolkit.telemetry.unified", false);
lockPref("toolkit.telemetry.archive.enabled", false);
lockPref("datareporting.policy.dataSubmissionEnabled", false);
lockPref("datareporting.healthreport.uploadEnabled", false);
lockPref("browser.ping-centre.telemetry", false);
lockPref("browser.newtabpage.activity-stream.feeds.telemetry", false);
lockPref("browser.newtabpage.activity-stream.telemetry", false);
lockPref("app.shield.optoutstudies.enabled", false);
lockPref("app.normandy.enabled", false);
lockPref("browser.backgroundtasks.enabled", false);
lockPref("dom.serviceWorkers.enabled", true);

// --- UI / startup ---
lockPref("browser.tabs.firefox-view", false);
lockPref("browser.startup.preXulSkeletonUI", false);
lockPref("browser.shell.checkDefaultBrowser", false);
lockPref("browser.newtabpage.activity-stream.showSponsored", false);
lockPref("browser.newtabpage.activity-stream.showSponsoredTopSites", false);
lockPref("browser.urlbar.suggest.quicksuggest.sponsored", false);

// --- Rendering ---
lockPref("layout.frame_rate", 0);
lockPref("gfx.canvas.accelerated", true);
lockPref("image.mem.decode_bytes_at_a_time", 65536);
CONF

    cat << 'CONF' > "$FIREFOX_DIR/defaults/pref/autoconfig.js"
pref("general.config.filename", "mozilla.cfg");
pref("general.config.obscure_value", 0);
CONF
done

# ── Brave browser heavy optimization ─────────────────────────────────────────
# Brave uses Chromium flags — write a system-wide default flags file.
# This file is read by all users on first launch before their own flags.
mkdir -p /etc/brave/policies/managed \
         /etc/brave/policies/recommended

# Managed (locked) policy — admin enforced
cat << 'CONF' > /etc/brave/policies/managed/raptor-performance.json
{
  "HardwareAccelerationModeEnabled": true,
  "MediaRouterEnabled": false,
  "BackgroundModeEnabled": false,
  "BrowserGuestModeEnabled": false,
  "AutofillCreditCardEnabled": false,
  "PasswordManagerEnabled": false,
  "MetricsReportingEnabled": false,
  "CloudReportingEnabled": false,
  "SafeBrowsingExtendedReportingEnabled": false,
  "UserFeedbackAllowed": false,
  "SpellcheckEnabled": true,
  "RendererCodeIntegrityEnabled": false,
  "ExtensionInstallBlocklist": []
}
CONF

# Recommended (user can override)
cat << 'CONF' > /etc/brave/policies/recommended/raptor-performance.json
{
  "ShowHomeButton": false,
  "BookmarkBarEnabled": false,
  "BraveRewardsDisabled": true,
  "BraveVPNDisabled": true,
  "BraveSyncEnabled": false,
  "DefaultSearchProviderEnabled": true,
  "HttpsUpgradesEnabled": true,
  "DnsOverHttpsMode": "automatic"
}
CONF

# System-wide Brave launch flags (applied before per-user flags)
# Written to /etc/brave-flags.conf which raptor-browser-choice.sh symlinks.
cat << 'CONF' > /etc/raptor/brave-flags.conf
# Raptor OS — Brave performance flags
# These are appended to the command line for all users.
--enable-gpu-rasterization
--enable-zero-copy
--ignore-gpu-blocklist
--enable-features=VaapiVideoDecodeLinuxGL,VaapiVideoEncoder,Vulkan,UseOzonePlatform,WaylandWindowDecorations
--ozone-platform-hint=auto
--disable-gpu-driver-bug-workarounds
--disable-features=UseChromeOSDirectVideoDecoder
--use-gl=egl
--enable-accelerated-video-decode
--disable-background-networking=false
--disable-background-timer-throttling
--disable-renderer-backgrounding
--disable-backgrounding-occluded-windows
--memory-pressure-thresholds-mb=256:512
--process-per-site
--renderer-process-limit=4
--disable-extensions-http-throttling
--aggressive-cache-discard
--no-pings
--disable-logging
CONF

# Per-user Brave flags file hook (applied at image build for existing home dirs)
for dir in /root /home/*; do
    [ -d "$dir" ] || continue
    local_brave="$dir/.config/BraveSoftware/Brave-Browser"
    mkdir -p "$local_brave"
    # Only write if the user hasn't customised flags yet
    if [ ! -f "$local_brave/brave_flags.conf" ]; then
        cp /etc/raptor/brave-flags.conf "$local_brave/brave_flags.conf"
    fi
done

# ── Dynamic zram ──────────────────────────────────────────────────────────────
TOTAL_RAM_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
TOTAL_RAM_GB=$((TOTAL_RAM_KB / 1024 / 1024))

if   [ "$TOTAL_RAM_GB" -le 4  ]; then ZRAM_SIZE="ram"
elif [ "$TOTAL_RAM_GB" -le 8  ]; then ZRAM_SIZE="ram * 3 / 4"
elif [ "$TOTAL_RAM_GB" -le 16 ]; then ZRAM_SIZE="ram * 1 / 2"
elif [ "$TOTAL_RAM_GB" -le 32 ]; then ZRAM_SIZE="ram / 3"
else                                   ZRAM_SIZE="8192"
fi

cat << CONF > /etc/systemd/zram-generator.conf
[zram0]
zram-size = $ZRAM_SIZE
compression-algorithm = zstd
writeback-device = none
CONF

# ── VM / memory tunables ──────────────────────────────────────────────────────
cat << 'CONF' > /etc/sysctl.d/raptor-memory.conf
# ── Memory ────────────────────────────────────────────────────────────────────
vm.overcommit_memory=0
vm.min_free_kbytes=131072
vm.watermark_boost_factor=0
vm.watermark_scale_factor=200
vm.swappiness=80
vm.page-cluster=0
vm.compaction_proactiveness=20
vm.dirty_expire_centisecs=3000
vm.dirty_writeback_centisecs=500
vm.dirty_ratio=10
vm.dirty_background_ratio=5
vm.oom_kill_allocating_task=1
# Transparent hugepages compaction: less CPU spike
vm.compaction_proactiveness=20
# Allow more inotify watches (needed by VS Code, IDEs, file watchers)
fs.inotify.max_user_watches=524288
fs.inotify.max_user_instances=1024
# Larger pipe capacity improves throughput for shell pipelines
fs.pipe-max-size=33554432
CONF

cat << 'CONF' > /etc/sysctl.d/raptor-network.conf
# ── Network performance ───────────────────────────────────────────────────────
net.core.rmem_default=262144
net.core.rmem_max=67108864
net.core.wmem_default=262144
net.core.wmem_max=67108864
net.core.netdev_max_backlog=16384
net.core.somaxconn=32768
net.ipv4.tcp_rmem=4096 262144 67108864
net.ipv4.tcp_wmem=4096 262144 67108864
net.ipv4.tcp_congestion_control=bbr
net.core.default_qdisc=fq
net.ipv4.tcp_fastopen=3
net.ipv4.tcp_slow_start_after_idle=0
net.ipv4.tcp_mtu_probing=1
net.ipv4.tcp_timestamps=1
net.ipv4.tcp_sack=1
net.ipv4.tcp_tw_reuse=1
CONF

# Load BBR module at boot
cat << 'CONF' > /etc/modules-load.d/raptor-bbr.conf
tcp_bbr
CONF

# ── CPU / thermal idle management ────────────────────────────────────────────
cat << 'CONF' > /usr/lib/systemd/system/raptor-powerprofile.service
[Unit]
Description=Raptor OS — Set balanced power profile at boot
After=power-profiles-daemon.service
Wants=power-profiles-daemon.service

[Service]
Type=oneshot
ExecStart=/usr/bin/powerprofilesctl set balanced
RemainAfterExit=yes

[Install]
WantedBy=graphical.target
CONF

cat << 'CONF' > /etc/systemd/system/raptor-cpugovernor.service
[Unit]
Description=Raptor OS — Set CPU governor to schedutil at boot
After=sysinit.target

[Service]
Type=oneshot
ExecStart=/bin/bash -c 'for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do [ -f "$cpu" ] && echo schedutil > "$cpu" 2>/dev/null || true; done'
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
CONF

# Disable CPU boost at idle; gamemode re-enables it during gaming
cat << 'CONF' > /etc/udev/rules.d/raptor-cpuboost.rules
ACTION=="add|change", SUBSYSTEM=="power_supply", \
  ATTR{online}=="1", \
  RUN+="/bin/bash -c 'echo 0 > /sys/devices/system/cpu/cpufreq/boost 2>/dev/null || true'"
CONF

# ── Transparent hugepages ─────────────────────────────────────────────────────
# madvise: only allocate THP when processes explicitly request them.
# This gives gaming workloads the benefit while not wasting RAM on idle apps.
cat << 'CONF' > /etc/raptor/thp.conf
# Raptor OS: Transparent hugepages set to madvise at boot.
# raptor-cpugovernor.service also applies this via ExecStart.
CONF

# Append THP to cpugovernor service so it runs in the same pass
cat << 'CONF' > /etc/systemd/system/raptor-thp.service
[Unit]
Description=Raptor OS — Set transparent hugepages to madvise
After=sysinit.target

[Service]
Type=oneshot
ExecStart=/bin/bash -c 'echo madvise > /sys/kernel/mm/transparent_hugepage/enabled 2>/dev/null; echo defer+madvise > /sys/kernel/mm/transparent_hugepage/defrag 2>/dev/null || true'
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
CONF

# ── Background service masking ────────────────────────────────────────────────
# Mask high-overhead services not needed on a gaming / desktop rig.
# Using a drop-in override rather than hard masking so the user can unmask.
BLOAT_SERVICES=(
    "ModemManager.service"
    "bluetooth.service"          # re-enable manually if needed
    "avahi-daemon.service"
    "avahi-daemon.socket"
    "cups-browsed.service"
    "geoclue.service"
    "accounts-daemon.service"
    "switcheroo-control.service"
    "udisks2.service"            # re-enabled if needed by file manager
)

mkdir -p /etc/systemd/system
for svc in "${BLOAT_SERVICES[@]}"; do
    # Only create a drop-in, don't hard-mask — user can easily re-enable
    dir="/etc/systemd/system/${svc}.d"
    mkdir -p "$dir"
    cat << EOF > "$dir/raptor-disable.conf"
[Unit]
# Raptor OS: disabled for performance — run 'sudo systemctl enable $svc' to re-enable
ConditionPathExists=/etc/raptor/enable-${svc%%.service}
EOF
done

# Bluetooth is commonly needed; provide a quick re-enable helper
cat << 'EOF' > /usr/bin/raptor-enable-bluetooth
#!/bin/bash
touch /etc/raptor/enable-bluetooth
systemctl enable --now bluetooth.service
echo "Bluetooth enabled."
EOF
chmod +x /usr/bin/raptor-enable-bluetooth

# ── Gamemode config ───────────────────────────────────────────────────────────
mkdir -p /etc/gamemode.d
cat << 'CONF' > /etc/gamemode.d/raptor.ini
[general]
renice=10
inhibit_screensaver=1
softrealtime=auto
reaper_freq=5

[gpu]
apply_gpu_optimisations=accept-responsibility
gpu_device=0
amd_performance_level=high

[custom]
start=/usr/lib/raptor/gamemode-start
end=/usr/lib/raptor/gamemode-end
CONF

# ── Thermal notes ─────────────────────────────────────────────────────────────
mkdir -p /etc/raptor
cat << 'CONF' > /etc/raptor/thermal-idle.conf
# Raptor OS thermal notes:
# - power-profiles-daemon "balanced" handles CPU P-state at desktop
# - raptor-powerprofile.service enforces this at boot
# - raptor-cpugovernor.service sets schedutil governor
# - raptor-thp.service sets THP to madvise
# - CPU boost disabled at idle via udev raptor-cpuboost.rules
# - gamemode re-enables boost + sets performance profile on game start
#
# Manual overrides:
#   sudo powerprofilesctl set power-saver   (quiet/cool)
#   sudo powerprofilesctl set performance   (maximum)
#   sudo raptor-enable-bluetooth            (re-enable BT)
CONF

# ── KDE app menu rebuild on login ─────────────────────────────────────────────
cat << 'CONF' > /etc/profile.d/raptor-appmenu.sh
#!/bin/bash
kbuildsycoca6 --noincremental 2>/dev/null || true
CONF

echo "PERFORMANCE_READY"
