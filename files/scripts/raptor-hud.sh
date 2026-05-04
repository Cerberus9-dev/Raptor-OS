#!/bin/bash
set -oue pipefail

mkdir -p /etc/skel/.config
cat << 'EOF' > /etc/skel/.config/kdeglobals
[General]
ColorScheme=BreezeDark
AccentColor=51,255,51
accentColorFromWallpaper=false
EOF

for dir in /root /home/*; do
    if [ -d "$dir" ]; then
        mkdir -p "$dir/.config"
        cp /etc/skel/.config/kdeglobals "$dir/.config/kdeglobals"
        chown $(stat -c "%U:%G" "$dir") "$dir/.config/kdeglobals"
    fi
done

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

mkdir -p /usr/local/bin
cat << 'EOF' > /usr/local/bin/raptor-theme.sh
#!/bin/bash
qdbus org.kde.KWin /KWin reconfigure 2>/dev/null || true
plasma-apply-colorscheme BreezeDark 2>/dev/null || true
kwriteconfig6 --file kdeglobals --group General --key AccentColor "51,255,51" 2>/dev/null || true
EOF
chmod +x /usr/local/bin/raptor-theme.sh

if [ -f /usr/local/bin/raptor-browser-choice.sh ]; then
    chmod +x /usr/local/bin/raptor-browser-choice.sh
fi

echo "HUD_READY"
