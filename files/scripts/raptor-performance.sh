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

# Firefox aggressive memory optimization
mkdir -p /usr/lib/firefox/defaults/pref
cat << 'EOF' > /usr/lib/firefox/defaults/pref/raptor.js
// Memory limits
pref("browser.cache.memory.capacity", 16384);
pref("browser.cache.memory.max_entry_size", 256);
pref("browser.sessionhistory.max_entries", 3);
pref("browser.sessionhistory.max_total_viewers", 0);
pref("browser.tabs.unloadOnLowMemory", true);
pref("browser.low_commit_space_threshold_mb", 256);

// JavaScript memory
pref("javascript.options.mem.max", 256);
pref("javascript.options.mem.gc_incremental_slice_ms", 5);
pref("javascript.options.mem.high_water_mark", 128);
pref("javascript.options.mem.gc_high_frequency_time_limit_ms", 500);

// Disable memory hungry features
pref("browser.tabs.firefox-view", false);
pref("browser.newtabpage.activity-stream.feeds.telemetry", false);
pref("browser.newtabpage.activity-stream.telemetry", false);
pref("browser.ping-centre.telemetry", false);
pref("toolkit.telemetry.enabled", false);
pref("toolkit.telemetry.unified", false);
pref("toolkit.telemetry.archive.enabled", false);

// GPU acceleration
pref("gfx.webrender.all", true);
pref("media.hardware-video-decoding.enabled", true);
pref("media.ffmpeg.vaapi.enabled", true);

// Reduce background activity
pref("browser.backgroundtasks.enabled", false);
pref("dom.serviceWorkers.enabled", false);
pref("browser.send_pings", false);
pref("network.prefetch-next", false);
pref("network.dns.disablePrefetch", true);
pref("network.predictor.enabled", false);
EOF

# Enable zram for better memory management
cat << 'EOF' > /etc/systemd/zram-generator.conf
[zram0]
zram-size = ram / 2
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
EOF

# Rebuild app menu database on boot
cat << 'EOF' > /etc/profile.d/raptor-appmenu.sh
#!/bin/bash
kbuildsycoca6 --noincremental 2>/dev/null || true
EOF

echo "PERFORMANCE_READY"
