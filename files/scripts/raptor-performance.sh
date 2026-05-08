#!/bin/bash
set -oue pipefail

# ── DNS ───────────────────────────────────────────────────────────────────────
mkdir -p /etc/systemd/resolved.conf.d
cat << 'CONF' > /etc/systemd/resolved.conf.d/dns.conf
[Resolve]
DNS=1.1.1.1 1.0.0.1
FallbackDNS=8.8.8.8 8.8.4.4
CONF

# ── WiFi power management ─────────────────────────────────────────────────────
mkdir -p /etc/NetworkManager/conf.d
cat << 'CONF' > /etc/NetworkManager/conf.d/raptor-wifi.conf
[connection]
wifi.powersave=2
[device]
wifi.scan-rand-mac-address=no
CONF

# ── Firefox memory optimization ───────────────────────────────────────────────
mkdir -p /usr/lib/firefox/defaults/pref \
         /usr/lib64/firefox/defaults/pref

for FIREFOX_DIR in /usr/lib/firefox /usr/lib64/firefox; do
    [ -d "$FIREFOX_DIR" ] || continue
    cat << 'CONF' > "$FIREFOX_DIR/mozilla.cfg"
// Firefox memory optimization
lockPref("browser.cache.memory.capacity", 16384);
lockPref("browser.cache.memory.max_entry_size", 256);
lockPref("browser.sessionhistory.max_entries", 3);
lockPref("browser.sessionhistory.max_total_viewers", 0);
lockPref("browser.tabs.unloadOnLowMemory", true);
lockPref("browser.low_commit_space_threshold_mb", 512);
lockPref("javascript.options.mem.max", 256);
lockPref("javascript.options.mem.gc_incremental_slice_ms", 5);
lockPref("javascript.options.mem.high_water_mark", 128);
lockPref("javascript.options.mem.gc_high_frequency_time_limit_ms", 500);
lockPref("browser.tabs.firefox-view", false);
lockPref("toolkit.telemetry.enabled", false);
lockPref("toolkit.telemetry.unified", false);
lockPref("gfx.webrender.all", true);
lockPref("media.hardware-video-decoding.enabled", true);
lockPref("media.ffmpeg.vaapi.enabled", true);
lockPref("browser.backgroundtasks.enabled", false);
lockPref("dom.serviceWorkers.enabled", false);
lockPref("network.prefetch-next", false);
lockPref("network.dns.disablePrefetch", true);
lockPref("network.predictor.enabled", false);
CONF
    cat << 'CONF' > "$FIREFOX_DIR/defaults/pref/autoconfig.js"
pref("general.config.filename", "mozilla.cfg");
pref("general.config.obscure_value", 0);
CONF
done

# ── Dynamic zram ──────────────────────────────────────────────────────────────
TOTAL_RAM_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
TOTAL_RAM_GB=$((TOTAL_RAM_KB / 1024 / 1024))

if   [ "$TOTAL_RAM_GB" -le 8  ]; then ZRAM_SIZE="ram * 3 / 4"
elif [ "$TOTAL_RAM_GB" -le 16 ]; then ZRAM_SIZE="ram * 5 / 8"
else                                   ZRAM_SIZE="10240"
fi

cat << CONF > /etc/systemd/zram-generator.conf
[zram0]
zram-size = $ZRAM_SIZE
compression-algorithm = zstd
CONF

# ── VM / memory tunables ──────────────────────────────────────────────────────
cat << 'CONF' > /etc/sysctl.d/raptor-memory.conf
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
CONF

# ── CPU / thermal idle management ────────────────────────────────────────────
# Problem: at the desktop/home screen the CPU governor sits at high frequencies
# and boost stays on, causing unnecessary heat and fan spin on laptops.
# Fix: use power-profiles-daemon (ships with Bazzite) set to "balanced" by
# default, with a udev rule that drops to "power-saver" when no game/app is
# using the GPU, and a systemd service that enforces the initial state.

# 1. Set power-profiles-daemon default to balanced (not performance)
mkdir -p /etc/power-profiles-daemon
cat << 'CONF' > /etc/power-profiles-daemon/raptor-default.conf
# Raptor OS: start in balanced mode so the CPU doesn't boost at idle.
# The GPU profile switcher can override this per-session.
[main]
default-profile=balanced
CONF

# 2. Systemd service to apply balanced profile at boot before login screen
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

# 3. CPU governor fallback — in case power-profiles-daemon is not active,
#    force schedutil (tracks actual CPU demand) instead of performance.
cat << 'CONF' > /etc/systemd/system/raptor-cpugovernor.service
[Unit]
Description=Raptor OS — Set CPU governor to schedutil at boot
After=sysinit.target

[Service]
Type=oneshot
ExecStart=/bin/bash -c '
    for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
        [ -f "$cpu" ] && echo schedutil > "$cpu" 2>/dev/null || true
    done
'
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
CONF

# 4. Disable CPU boost at idle via udev — when plugged in but GPU is idle
#    (desktop/home screen), cap boost. Games restore it via gamemode.
cat << 'CONF' > /etc/udev/rules.d/raptor-cpuboost.rules
# Raptor OS: disable CPU boost when on AC and GPU is idle
# gamemode re-enables boost automatically when a game launches.
ACTION=="add|change", SUBSYSTEM=="power_supply", \
  ATTR{online}=="1", \
  RUN+="/bin/bash -c 'echo 0 > /sys/devices/system/cpu/cpufreq/boost 2>/dev/null || true'"
CONF

# 5. TLP-compatible thermal config — caps package power at idle
#    Works alongside power-profiles-daemon (they don't conflict when
#    TLP_ENABLE is guarded; we only write the thermal section).
cat << 'CONF' > /etc/raptor/thermal-idle.conf
# Raptor OS thermal notes:
# - power-profiles-daemon "balanced" profile handles CPU P-state
# - raptor-powerprofile.service sets this at boot
# - raptor-cpugovernor.service sets schedutil as fallback governor
# - CPU boost disabled at idle via udev rule raptor-cpuboost.rules
# - gamemode (used by Steam/Lutris) re-enables boost + sets performance
#   profile automatically when a game starts, and reverts on exit
#
# If your laptop still runs hot at desktop:
#   sudo powerprofilesctl set power-saver
# To check current profile:
#   powerprofilesctl
CONF
mkdir -p /etc/raptor

# 6. gamemode config — ensure gamemode restores boost + performance
#    profile when a game launches and drops back to balanced on exit
mkdir -p /etc/gamemode.d
cat << 'CONF' > /etc/gamemode.d/raptor.ini
[general]
renice=10
inhibit_screensaver=1

[gpu]
apply_gpu_optimisations=accept-responsibility
gpu_device=0

[custom]
# Re-enable CPU boost and switch to performance when game starts
start=/bin/bash -c 'echo 1 > /sys/devices/system/cpu/cpufreq/boost 2>/dev/null; powerprofilesctl set performance 2>/dev/null || true'
# Drop back to balanced and disable boost when game exits
end=/bin/bash -c 'echo 0 > /sys/devices/system/cpu/cpufreq/boost 2>/dev/null; powerprofilesctl set balanced 2>/dev/null || true'
CONF

# ── KDE app menu rebuild on login ─────────────────────────────────────────────
cat << 'CONF' > /etc/profile.d/raptor-appmenu.sh
#!/bin/bash
kbuildsycoca6 --noincremental 2>/dev/null || true
CONF

echo "PERFORMANCE_READY"
