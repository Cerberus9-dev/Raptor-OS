#!/bin/bash
set -oue pipefail

# Set Neon Green Tactical HUD
mkdir -p /etc/skel/.config
cat << 'EOF' > /etc/skel/.config/kdeglobals
[General]
ColorScheme=BreezeDark
AccentColor=51,255,51
EOF

# Set Taskbar to Top
cat << 'EOF' > /etc/skel/.config/plasmarc
[Panels]
PanelPosition=Top
EOF

systemctl enable firewalld
