#!/bin/bash
set -oue pipefail

# ── DNS ──────────────────────────────────────────────────────────────────────
mkdir -p /etc/systemd/resolved.conf.d
cat << 'EOF' > /etc/systemd/resolved.conf.d/dns.conf
[Resolve]
DNS=1.1.1.1 1.0.0.1
FallbackDNS=8.8.8.8 8.8.4.4
EOF

# ── WiFi power management ─────────────────────────────────────────────────────
mkdir -p /etc/NetworkManager/conf.d
cat << 'EOF' > /etc/NetworkManager/conf.d/raptor-wifi.conf
[connection]
wifi.powersave=2
[device]
wifi.scan-rand-mac-address=no
EOF

# ── Firefox memory optimization ───────────────────────────────────────────────
mkdir -p /usr/lib/firefox/defaults/pref
mkdir -p /usr/lib64/firefox/defaults/pref

for FIREFOX_DIR in /usr/lib/firefox /usr/lib64/firefox; do
    cat << 'EOF' > "$FIREFOX_DIR/mozilla.cfg"
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
EOF
    cat << 'EOF' > "$FIREFOX_DIR/defaults/pref/autoconfig.js"
pref("general.config.filename", "mozilla.cfg");
pref("general.config.obscure_value", 0);
EOF
done

# ── Dynamic zram ──────────────────────────────────────────────────────────────
TOTAL_RAM_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
TOTAL_RAM_GB=$((TOTAL_RAM_KB / 1024 / 1024))

# zram at ~75% RAM for ≤8 GB, ~60% for ≤16 GB, hard cap 10 GB above that.
# A larger zram pool lets Unity/Unturned spill compressed pages instead of OOMing.
if [ "$TOTAL_RAM_GB" -le 4 ]; then
    ZRAM_SIZE="ram * 3 / 4"      # ≤4 GB: 75% — maximise headroom
elif [ "$TOTAL_RAM_GB" -le 8 ]; then
    ZRAM_SIZE="ram * 3 / 4"      # ≤8 GB: still 75%
elif [ "$TOTAL_RAM_GB" -le 16 ]; then
    ZRAM_SIZE="ram * 5 / 8"      # ≤16 GB: 62.5%
else
    ZRAM_SIZE="10240"             # >16 GB: cap at 10 GB
fi

cat << EOF > /etc/systemd/zram-generator.conf
[zram0]
zram-size = $ZRAM_SIZE
compression-algorithm = zstd
# zstd gives the best speed/ratio balance for Unity heap pages
EOF

# ── Memory / VM tunables ──────────────────────────────────────────────────────
# NOTE: vm.swappiness is intentionally HIGH here because our swap is zram
# (in-RAM compressed). Swapping to zram is ~10x faster than a spinning disk
# and avoids the OOM killer triggering on Unturned's Unity heap spikes.
# raptor-gaming.conf (script 2) no longer touches swappiness — this file owns it.
cat << 'EOF' > /etc/sysctl.d/raptor-memory.conf
# ── Overcommit: heuristic mode (default 0) ───────────────────────────────────
# Mode 1 ("always overcommit") is what causes Unity games to silently allocate
# past physical RAM and then hard-crash. Mode 0 lets the kernel reject clearly
# impossible allocations before they become OOM events.
vm.overcommit_memory=0

# ── Keep a meaningful free pool ──────────────────────────────────────────────
# 128 MB reserved so the kernel never has to reclaim under extreme pressure.
vm.min_free_kbytes=131072

# ── Watermarks: reclaim early, don't boost ──────────────────────────────────
vm.watermark_boost_factor=0
vm.watermark_scale_factor=200

# ── Swappiness: high because zram is fast ────────────────────────────────────
# 80 means "prefer compressing cold pages to zram" over dropping page cache.
# Lower values (10-20) cause the OOM killer to fire on RAM spikes instead of
# gracefully compressing pages to zram.
vm.swappiness=80

# ── page-cluster=0: CRITICAL for zram ───────────────────────────────────────
# Default cluster=3 reads 8 pages ahead on swap access — fine for spinning
# disks, wasteful and slow on zram. 0 = single-page reads.
vm.page-cluster=0

# ── Compaction: let the kernel compact proactively ──────────────────────────
vm.compaction_proactiveness=20

# ── Dirty page writeback ─────────────────────────────────────────────────────
vm.dirty_expire_centisecs=3000
vm.dirty_writeback_centisecs=500
vm.dirty_ratio=10
vm.dirty_background_ratio=5

# ── OOM behaviour ────────────────────────────────────────────────────────────
# Kill the task that triggered the OOM (e.g. Unturned leaking memory) rather
# than hunting for the "largest" victim, which often kills the wrong process.
vm.oom_kill_allocating_task=1
EOF

# ── KDE app menu rebuild on login ────────────────────────────────────────────
cat << 'EOF' > /etc/profile.d/raptor-appmenu.sh
#!/bin/bash
kbuildsycoca6 --noincremental 2>/dev/null || true
EOF

echo "PERFORMANCE_READY"
