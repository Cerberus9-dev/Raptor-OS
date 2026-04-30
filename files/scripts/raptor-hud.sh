#!/bin/bash
set -oue pipefail

# 1. Force-Inject Brave and Opera Repositories
cat << 'EOF' > /etc/yum.repos.d/brave.repo
[brave-browser]
name=Brave Browser
baseurl=https://brave-browser-rpm-release.s3.brave.com/x86_64/
enabled=1
gpgcheck=0
EOF

cat << 'EOF' > /etc/yum.repos.d/opera.repo
[opera]
name=Opera
baseurl=https://rpm.opera.com/rpm/
enabled=1
gpgcheck=0
EOF

# 2. Set Neon Green Tactical HUD
mkdir -p /etc/skel/.config
cat << 'EOF' > /etc/skel/.config/kdeglobals
[General]
ColorScheme=BreezeDark
AccentColor=51,255,51
EOF

# 3. Set Taskbar to Top
cat << 'EOF' > /etc/skel/.config/plasmarc
[Panels]
PanelPosition=Top
EOF

echo "HUD DNA INJECTED SUCCESSFULLY"
