#!/bin/bash
set -oue pipefail

# Create Neon Green Visuals
mkdir -p /etc/skel/.config
cat << 'EOF' > /etc/skel/.config/kdeglobals
[General]
ColorScheme=BreezeDark
AccentColor=51,255,51
EOF

echo "HUD_READY"
