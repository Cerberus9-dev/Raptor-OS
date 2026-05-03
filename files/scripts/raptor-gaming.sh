#!/bin/bash
set -oue pipefail

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

# Steam memory tweaks
mkdir -p /etc/skel/.local/share/Steam
cat << 'EOF' > /etc/skel/.steam/steam/steam_dev.cfg
@nClientDownloadEnableHTTP2PlatformLinux 0
@fDownloadRateImprovementToAddAnotherConnection 1.0
EOF

# Lutris runtime optimizations
mkdir -p /etc/skel/.config/lutris
cat << 'EOF' > /etc/skel/.config/lutris/lutris.conf
[lutris]
prefer-system-libraries=true
reset-desktop-on-quit=false
game-show-logs=false
EOF

echo "GAMING_READY"
