
#!/bin/bash
set -oue pipefail

# 1. Set Neon Green Tactical HUD
mkdir -p /etc/skel/.config
cat << 'EOF' > /etc/skel/.config/kdeglobals
[General]
ColorScheme=BreezeDark
AccentColor=51,255,51
EOF

# 2. Set Taskbar to Top
cat << 'EOF' > /etc/skel/.config/plasmarc
[Panels]
PanelPosition=Top
EOF

# 3. Enable System Firewall
systemctl enable firewalld

echo "RAPTOR HUD INITIALIZED"
