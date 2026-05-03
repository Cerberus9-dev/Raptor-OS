#!/bin/bash
set -oue pipefail

# Apply Neon Green Visuals system-wide
mkdir -p /etc/skel/.config
cat << 'EOF' > /etc/skel/.config/kdeglobals
[General]
ColorScheme=BreezeDark
AccentColor=51,255,51
EOF

# Also apply to root and any existing users
for dir in /root /home/*; do
    if [ -d "$dir" ]; then
        mkdir -p "$dir/.config"
        cat << 'EOF' > "$dir/.config/kdeglobals"
[General]
ColorScheme=BreezeDark
AccentColor=51,255,51
EOF
    fi
done

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

# Steam and Lutris gaming optimizations
mkdir -p /etc/environment.d
cat << 'EOF' > /etc/environment.d/raptor-gaming.conf
RADV_PERFTEST=gpl
PROTON_ENABLE_NVAPI=1
DXVK_ASYNC=1
mesa_glthread=true
__GL_SHADER_DISK_CACHE=1
__GL_SHADER_DISK_CACHE_SKIP_CLEANUP=1
EOF

# Lutris runtime optimizations
mkdir -p /etc/skel/.config/lutris
cat << 'EOF' > /etc/skel/.config/lutris/lutris.conf
[lutris]
prefer-system-libraries=true
reset-desktop-on-quit=false
game-show-logs=false
EOF

# Make browser choice script executable
chmod +x /usr/local/bin/raptor-browser-choice.sh 2>/dev/null || true

echo "HUD_READY"
