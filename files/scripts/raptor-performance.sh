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

# Firefox performance tweaks system-wide
mkdir -p /usr/lib/firefox/defaults/pref
cat << 'EOF' > /usr/lib/firefox/defaults/pref/raptor.js
pref("browser.cache.memory.capacity", 32768);
pref("browser.cache.memory.max_entry_size", 512);
pref("browser.sessionhistory.max_entries", 5);
pref("browser.sessionhistory.max_total_viewers", 1);
pref("browser.tabs.unloadOnLowMemory", true);
pref("javascript.options.mem.max", 512);
pref("javascript.options.mem.gc_incremental_slice_ms", 5);
pref("gfx.webrender.all", true);
pref("browser.low_commit_space_threshold_mb", 500);
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
