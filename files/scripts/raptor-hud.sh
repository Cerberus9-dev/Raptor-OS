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

# Add desktop shortcut for performance toggle
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

# Create GPU profile script that runs at boot
cat << 'EOF' > /usr/local/bin/raptor-gpu-profile.sh
#!/bin/bash
if lspci | grep -i "VGA\|3D\|Display" | grep -qi "nvidia"; then
    GPU_VENDOR="nvidia"
elif lspci | grep -i "VGA\|3D\|Display" | grep -qi "amd\|radeon\|ati"; then
    GPU_VENDOR="amd"
elif lspci | grep -i "VGA\|3D\|Display" | grep -qi "intel"; then
    GPU_VENDOR="intel"
else
    GPU_VENDOR="unknown"
fi

IS_IGPU=false
if lspci | grep -i "VGA\|3D\|Display" | grep -qi "intel"; then
    IS_IGPU=true
fi
if lspci -v | grep -i "VGA\|3D\|Display" -A5 | grep -qi "cezanne\|renoir\|lucienne\|rembrandt\|mendocino\|integrated\|apu"; then
    IS_IGPU=true
fi

mkdir -p /etc/environment.d

if [ -f /etc/raptor-force-performance ]; then
    cat << 'ENVEOF' > /etc/environment.d/raptor-gpu.conf
RADV_PERFTEST=gpl
AMD_VULKAN_ICD=RADV
mesa_glthread=true
MESA_SHADER_CACHE_DISABLE=false
__GL_SHADER_DISK_CACHE=1
__GL_SHADER_DISK_CACHE_SKIP_CLEANUP=1
PROTON_ENABLE_NVAPI=1
ENVEOF

elif [ -f /etc/raptor-force-powersave ]; then
    cat << 'ENVEOF' > /etc/environment.d/raptor-gpu.conf
mesa_glthread=false
MESA_SHADER_CACHE_DISABLE=true
ENVEOF

elif [ "$GPU_VENDOR" = "nvidia" ]; then
    cat << 'ENVEOF' > /etc/environment.d/raptor-gpu.conf
__GL_SHADER_DISK_CACHE=1
__GL_SHADER_DISK_CACHE_SKIP_CLEANUP=1
PROTON_ENABLE_NVAPI=1
__NV_PRIME_RENDER_OFFLOAD=1
ENVEOF

elif [ "$GPU_VENDOR" = "amd" ] && [ "$IS_IGPU" = true ]; then
    cat << 'ENVEOF' > /etc/environment.d/raptor-gpu.conf
AMD_VULKAN_ICD=RADV
mesa_glthread=true
MESA_SHADER_CACHE_DISABLE=false
ENVEOF

elif [ "$GPU_VENDOR" = "amd" ]; then
    cat << 'ENVEOF' > /etc/environment.d/raptor-gpu.conf
RADV_PERFTEST=gpl
AMD_VULKAN_ICD=RADV
mesa_glthread=true
MESA_SHADER_CACHE_DISABLE=false
ENVEOF

elif [ "$GPU_VENDOR" = "intel" ]; then
    cat << 'ENVEOF' > /etc/environment.d/raptor-gpu.conf
MESA_LOADER_DRIVER_OVERRIDE=iris
LIBGL_DRI3_DISABLE=0
vblank_mode=0
mesa_glthread=true
ENVEOF

else
    cat << 'ENVEOF' > /etc/environment.d/raptor-gpu.conf
mesa_glthread=true
MESA_SHADER_CACHE_DISABLE=false
ENVEOF
fi
EOF
chmod +x /usr/local/bin/raptor-gpu-profile.sh

# Create systemd service for GPU detection at boot
cat << 'EOF' > /usr/lib/systemd/system/raptor-gpu-profile.service
[Unit]
Description=Raptor OS GPU Profile Detection
After=sysinit.target
Before=display-manager.service

[Service]
Type=oneshot
ExecStart=/usr/local/bin/raptor-gpu-profile.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

# Make browser choice script executable
chmod +x /usr/local/bin/raptor-browser-choice.sh 2>/dev/null || true

echo "HUD_READY"
