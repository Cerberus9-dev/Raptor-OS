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

# KDE theme autostart fix
mkdir -p /etc/skel/.config/autostart
cat << 'EOF' > /etc/skel/.config/autostart/raptor-theme.desktop
[Desktop Entry]
Type=Application
Name=Raptor Theme
Exec=/usr/local/bin/raptor-theme.sh
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
EOF

# Create theme apply script
mkdir -p /usr/local/bin
cat << 'EOF' > /usr/local/bin/raptor-theme.sh
#!/bin/bash
qdbus org.kde.KWin /KWin reconfigure
plasma-apply-colorscheme BreezeDark
kwriteconfig5 --file kdeglobals --group General --key AccentColor "51,255,51"
qdbus org.kde.KWin /KWin reconfigure
EOF
chmod +x /usr/local/bin/raptor-theme.sh

# Make browser choice script executable
chmod +x /usr/local/bin/raptor-browser-choice.sh 2>/dev/null || true

echo "HUD_READY"
