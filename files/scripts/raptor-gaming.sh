#!/bin/bash
set -oue pipefail

# Lutris runtime optimizations
mkdir -p /etc/skel/.config/lutris
cat << 'EOF' > /etc/skel/.config/lutris/lutris.conf
[lutris]
prefer-system-libraries=true
reset-desktop-on-quit=false
game-show-logs=false
EOF

# Steam memory tweaks
mkdir -p /etc/skel/.steam/steam
cat << 'EOF' > /etc/skel/.steam/steam/steam_dev.cfg
@nClientDownloadEnableHTTP2PlatformLinux 0
@fDownloadRateImprovementToAddAnotherConnection 1.0
EOF

echo "GAMING_READY"
