#!/bin/bash
set -oue pipefail

# Apply Neon Green Visuals system-wide
mkdir -p /etc/skel/.config
cat << 'EOF' > /etc/skel/.config/kdeglobals
[General]
ColorScheme=BreezeDark
AccentColor=51,255,51
accentColorFromWallpaper=false
EOF

# Also apply to existing users
for dir in /root /home/*; do
    if [ -d "$dir" ]; then
        mkdir -p "$dir/.config"
        cat << 'EOF' > "$dir/.config/kdeglobals"
[General]
ColorScheme=BreezeDark
AccentColor=51,255,51
accentColorFromWallpaper=false
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
kwriteconfig6 --file kdeglobals --group General --key AccentColor "51,255,51"
kwriteconfig6 --file kdeglobals --group General --key accentColorFromWallpaper "false"
kwriteconfig6 --file kdeglobals --group General --key ColorScheme "BreezeDark"
plasma-apply-colorscheme BreezeDark 2>/dev/null || true
qdbus6 org.kde.KWin /KWin reconfigure 2>/dev/null || true
kbuildsycoca6 --noincremental 2>/dev/null || true
EOF
chmod +x /usr/local/bin/raptor-theme.sh

# Copy autostart to existing users
for dir in /root /home/*; do
    if [ -d "$dir" ]; then
        mkdir -p "$dir/.config/autostart"
        cp /etc/skel/.config/autostart/raptor-theme.desktop "$dir/.config/autostart/" 2>/dev/null || true
    fi
done

# Create performance mode toggle script
cat << 'EOF' > /usr/local/bin/raptor-toggle-performance.sh
#!/bin/bash
CHOICE=$(zenity --list \
  --title="Raptor OS Performance Mode" \
  --text="Choose your performance profile:" \
  --radiolist \
  --column="" --column="Profile" \
  TRUE "Auto (Recommended)" \
  FALSE "Max Performance" \
  FALSE "Power Saving" \
  --width=350 --height=250)

if [ "$CHOICE" = "Max Performance" ]; then
    sudo touch /etc/raptor-force-performance
    sudo rm -f /etc/raptor-force-powersave
    zenity --info --text="Max Performance mode enabled. Please reboot."
elif [ "$CHOICE" = "Power Saving" ]; then
    sudo touch /etc/raptor-force-powersave
    sudo rm -f /etc/raptor-force-performance
    zenity --info --text="Power Saving mode enabled. Please reboot."
else
    sudo rm -f /etc/raptor-force-performance
    sudo rm -f /etc/raptor-force-powersave
    zenity --info --text="Auto mode enabled. Please reboot."
fi
EOF
chmod +x /usr/local/bin/raptor-toggle-performance.sh

# Add desktop shortcut
mkdir -p /etc/skel/Desktop
cat << 'EOF' > /etc/skel/Desktop/raptor-performance.desktop
[Desktop Entry]
Type=Application
Name=Raptor Performance Mode
Comment=Switch between performance profiles
Exec=/usr/local/bin/raptor-toggle-performance.sh
Icon=preferences-system
Terminal=false
Categories=System;
EOF
chmod +x /etc/skel/Desktop/raptor-performance.desktop

# Copy desktop shortcut to existing users
for dir in /root /home/*; do
    if [ -d "$dir" ]; then
        mkdir -p "$dir/Desktop"
        cp /etc/skel/Desktop/raptor-performance.desktop "$dir/Desktop/" 2>/dev/null || true
    fi
done

# Make browser choice script executable
chmod +x /usr/local/bin/raptor-browser-choice.sh 2>/dev/null || true

echo "HUD_READY"
