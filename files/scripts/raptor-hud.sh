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
Exec=/usr/bin/raptor-theme.sh
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
EOF

# Create theme apply script
cat << 'EOF' > /usr/bin/raptor-theme.sh
#!/bin/bash
kwriteconfig6 --file kdeglobals --group General --key AccentColor "51,255,51"
kwriteconfig6 --file kdeglobals --group General --key accentColorFromWallpaper "false"
kwriteconfig6 --file kdeglobals --group General --key ColorScheme "BreezeDark"
plasma-apply-colorscheme BreezeDark 2>/dev/null || true
qdbus org.kde.KWin /KWin reconfigure 2>/dev/null || true
kbuildsycoca6 --noincremental 2>/dev/null || true
EOF
chmod +x /usr/bin/raptor-theme.sh

# Copy autostart to existing users
for dir in /root /home/*; do
    if [ -d "$dir" ]; then
        mkdir -p "$dir/.config/autostart"
        cp /etc/skel/.config/autostart/raptor-theme.desktop "$dir/.config/autostart/" 2>/dev/null || true
    fi
done

# Create profile switcher script
cat << 'EOF' > /usr/bin/raptor-profile-switcher.sh
#!/bin/bash

CURRENT_GPU="Auto"
[ -f /etc/raptor-force-performance ] && CURRENT_GPU="Max Performance"
[ -f /etc/raptor-force-powersave ] && CURRENT_GPU="Power Saving"

CHOICE=$(zenity --list \
  --title="Raptor OS Profile Switcher" \
  --text="Current GPU profile: $CURRENT_GPU\n\nSelect a new profile:" \
  --radiolist \
  --column="" --column="Profile" --column="Description" \
  TRUE "Auto" "Automatically detect and optimize for your GPU" \
  FALSE "Max Performance" "Maximum GPU performance, higher power usage" \
  FALSE "Power Saving" "Reduced GPU usage, better battery life" \
  --width=500 --height=300)

if [ "$CHOICE" = "Max Performance" ]; then
    sudo touch /etc/raptor-force-performance
    sudo rm -f /etc/raptor-force-powersave
    /usr/bin/raptor-gpu-profile.sh
    zenity --info --title="Raptor OS" --text="Max Performance profile applied.\nSome changes require a reboot."
elif [ "$CHOICE" = "Power Saving" ]; then
    sudo touch /etc/raptor-force-powersave
    sudo rm -f /etc/raptor-force-performance
    /usr/bin/raptor-gpu-profile.sh
    zenity --info --title="Raptor OS" --text="Power Saving profile applied.\nSome changes require a reboot."
elif [ "$CHOICE" = "Auto" ]; then
    sudo rm -f /etc/raptor-force-performance
    sudo rm -f /etc/raptor-force-powersave
    /usr/bin/raptor-gpu-profile.sh
    zenity --info --title="Raptor OS" --text="Auto profile applied.\nSome changes require a reboot."
fi
EOF
chmod +x /usr/bin/raptor-profile-switcher.sh

# Create app menu entry fo
