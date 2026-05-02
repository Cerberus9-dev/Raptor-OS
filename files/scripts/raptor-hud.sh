#!/bin/bash
set -oue pipefail

# Create Neon Green Visuals
mkdir -p /etc/skel/.config
cat << 'EOF' > /etc/skel/.config/kdeglobals
[General]
ColorScheme=BreezeDark
AccentColor=51,255,51
EOF

# Set up autostart for browser choice dialog
mkdir -p /etc/skel/.config/autostart
cat << 'EOF' > /etc/skel/.config/autostart/raptor-browser-choice.desktop
[Desktop Entry]
Type=Application
Name=Raptor Browser Choice
Exec=/usr/local/bin/raptor-browser-choice.sh
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
EOF

# Make browser choice script executable
chmod +x /usr/local/bin/raptor-browser-choice.sh 2>/dev/null || true

echo "HUD_READY"
