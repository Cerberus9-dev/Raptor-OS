#!/bin/bash
set -oue pipefail

# Fix DNS
mkdir -p /etc/systemd/resolved.conf.d
cat << 'EOF' > /etc/systemd/resolved.conf.d/dns.conf
[Resolve]
DNS=1.1.1.1 1.0.0.1
FallbackDNS=8.8.8.8 8.8.4.4
EOF

# Fix WiFi disconnection issue
mkdir -p /etc/NetworkManager/conf.d
cat << 'EOF' > /etc/NetworkManager/conf.d/raptor-wifi.conf
[connection]
wifi.powersave=2

[device]
wifi.scan-rand-mac-address=no
EOF

# Firefox memory optimization via mozilla.cfg (cannot be ignored)
mkdir -p /usr/lib/firefox
cat << 'EOF' > /usr/lib/firefox/mozilla.cfg
// Firefox memory optimization
lockPref("browser.cache.memory.capacity", 16384);
lockPref("browser.cache.memory.max_entry_size", 256);
lockPref("browser.sessionhistory.max_entries", 3);
lockPref("browser.sessionhistory.max_total_viewers", 0);
lockPref("browser.tabs.unloadOnLowMemory", true);
lockPref("browser.low_commit_space_threshold_mb", 256);
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

# Required config file to point Firefox to mozilla.cfg
mkdir -p /usr/lib/firefox/defaults/pref
cat << 'EOF' > /usr/lib/firefox/defaults/pref/autoconfig.js
pref("general.config.filename", "mozilla.cfg");
pref("general.config.obscure_value", 0);
EOF

# Dynamic zram based on system RAM
TOTAL_RAM_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
TOTAL_RAM_GB=$((TOTAL_RAM_KB / 1024 / 1024))

if [ "$TOTAL_RAM_GB" -le 4 ]; then
    ZRAM_SIZE="ram"
elif [ "$TOTAL_RAM_GB" -le 8 ]; then
    ZRAM_SIZE="ram * 3 / 4"
elif [ "$TOTAL_RAM_GB" -le 16 ]; then
    ZRAM_SIZE="ram * 5 / 8"
else
    ZRAM_SIZE="8192"
fi

cat << EOF > /etc/systemd/zram-generator.conf
[zram0]
zram-size = $ZRAM_SIZE
compression-algorithm = zstd
EOF

# RAM spike protection
cat << 'EOF' > /etc/sysctl.d/raptor-memory.conf
vm.overcommit_memory=1
vm.overcommit_ratio=50
vm.min_free_kbytes=65536
vm.watermark_boost_factor=0
vm.watermark_scale_factor=125
vm.compaction_proactiveness=0
vm.dirty_expire_centisecs=3000
vm.dirty_writeback_centisecs=500
vm.swappiness=60
EOF

# Rebuild app menu database on boot
cat << 'EOF' > /etc/profile.d/raptor-appmenu.sh
#!/bin/bash
kbuildsycoca6 --noincremental 2>/dev/null || true
EOF

echo "PERFORMANCE_READY"
