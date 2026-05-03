#!/bin/bash
set -oue pipefail

# Fix DNS
mkdir -p /etc/systemd/resolved.conf.d
cat << 'EOF' > /etc/systemd/resolved.conf.d/dns.conf
[Resolve]
DNS=1.1.1.1 1.0.0.1
FallbackDNS=8.8.8.8 8.8.4.4
EOF

# Firefox performance tweaks
mkdir -p /usr/lib/firefox/defaults/pref
cat << 'EOF' > /usr/lib/firefox/defaults/pref/raptor.js
pref("browser.cache.memory.capacity", 65536);
pref("browser.sessionhistory.max_total_viewers", 2);
pref("browser.tabs.unloadOnLowMemory", true);
pref("browser.low_commit_space_threshold_mb", 500);
pref("gfx.webrender.all", true);
EOF

# Firefox memory hard limit
mkdir -p /etc/skel/.mozilla/firefox
cat << 'EOF' > /etc/skel/.mozilla/firefox/user.js
user_pref("browser.cache.memory.capacity", 32768);
user_pref("browser.cache.memory.max_entry_size", 512);
user_pref("browser.sessionhistory.max_entries", 5);
user_pref("browser.sessionhistory.max_total_viewers", 1);
user_pref("browser.tabs.unloadOnLowMemory", true);
user_pref("javascript.options.mem.max", 512);
user_pref("javascript.options.mem.gc_incremental_slice_ms", 5);
EOF

# Enable zram for better memory management
cat << 'EOF' > /etc/systemd/zram-generator.conf
[zram0]
zram-size = ram / 2
compression-algorithm = zstd
EOF

echo "PERFORMANCE_READY"
