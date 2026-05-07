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
  --width=600 --height=350)

if [ "$CHOICE" = "Max Performance" ]; then
    sudo touch /etc/raptor-force-performance
    sudo rm -f /etc/raptor-force-powersave
    /usr/bin/raptor-gpu-profile.sh
    zenity --question --title="Raptor OS" --text="Max Performance profile applied.\nLog out now to apply changes?" && qdbus org.kde.ksmserver /KSMServer logout 0 0 0

elif [ "$CHOICE" = "Power Saving" ]; then
    sudo touch /etc/raptor-force-powersave
    sudo rm -f /etc/raptor-force-performance
    /usr/bin/raptor-gpu-profile.sh
    zenity --question --title="Raptor OS" --text="Power Saving profile applied.\nLog out now to apply changes?" && qdbus org.kde.ksmserver /KSMServer logout 0 0 0

elif [ "$CHOICE" = "Auto" ]; then
    sudo rm -f /etc/raptor-force-performance
    sudo rm -f /etc/raptor-force-powersave
    /usr/bin/raptor-gpu-profile.sh
    zenity --question --title="Raptor OS" --text="Auto profile applied.\nLog out now to apply changes?" && qdbus org.kde.ksmserver /KSMServer logout 0 0 0
fi
EOF
chmod +x /usr/bin/raptor-profile-switcher.sh

# Create app menu entry for profile switcher
mkdir -p /usr/share/applications
cat << 'EOF' > /usr/share/applications/raptor-profile-switcher.desktop
[Desktop Entry]
Type=Application
Name=Raptor Profile Switcher
Comment=Switch between GPU performance profiles
Exec=/usr/bin/raptor-profile-switcher.sh
Icon=preferences-system-performance
Terminal=false
Categories=System;Settings;
Keywords=gpu;performance;power;profile;
EOF

# Create RAM optimizer script
cat << 'EOF' > /usr/bin/raptor-ram-optimizer.sh
#!/bin/bash

BEFORE=$(free -h | grep Mem | awk '{print $3}')

zenity --question \
  --title="Raptor RAM Optimizer" \
  --text="Current RAM usage: $BEFORE\n\nThis will:\n• Clear page cache\n• Compact memory\n• Free up inactive RAM\n\nContinue?" \
  --width=350

if [ $? != 0 ]; then exit 0; fi

# Clear page cache
sync
echo 3 | sudo tee /proc/sys/vm/drop_caches > /dev/null

# Compact memory
echo 1 | sudo tee /proc/sys/vm/compact_memory > /dev/null 2>/dev/null || true

zenity --question \
  --title="Raptor RAM Optimizer" \
  --text="Would you like to free up RAM by suspending background apps?" \
  --width=350

if [ $? = 0 ]; then
    pkill -STOP -f "baloo" 2>/dev/null || true
    pkill -STOP -f "tracker" 2>/dev/null || true
fi

AFTER=$(free -h | grep Mem | awk '{print $3}')

zenity --info \
  --title="Raptor RAM Optimizer" \
  --text="Done!\n\nBefore: $BEFORE\nAfter:  $AFTER" \
  --width=300
EOF
chmod +x /usr/bin/raptor-ram-optimizer.sh

# Create app menu entry for RAM optimizer
cat << 'EOF' > /usr/share/applications/raptor-ram-optimizer.desktop
[Desktop Entry]
Type=Application
Name=Raptor RAM Optimizer
Comment=Free up RAM and optimize memory usage
Exec=/usr/bin/raptor-ram-optimizer.sh
Icon=preferences-system-performance
Terminal=false
Categories=System;Settings;
Keywords=ram;memory;optimize;performance;
EOF

# Create GPU profile script
cat << 'EOF' > /usr/bin/raptor-gpu-profile.sh
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
if lspci -v | grep -i "VGA\|3D\|Display" -A5 | grep -qi \
    "cezanne\|renoir\|lucienne\|rembrandt\|mendocino\|integrated\|apu"; then
    IS_IGPU=true
fi

mkdir -p /etc/environment.d

COMMON_UNITY_VARS="WINE_LARGE_ADDRESS_AWARE=1
PROTON_FORCE_LARGE_ADDRESS_AWARE=1
STAGING_SHARED_MEMORY=1"

if [ -f /etc/raptor-force-performance ]; then
    cat << ENVEOF > /etc/environment.d/raptor-gpu.conf
RADV_PERFTEST=gpl
AMD_VULKAN_ICD=RADV
mesa_glthread=true
MESA_SHADER_CACHE_DISABLE=false
__GL_SHADER_DISK_CACHE=1
__GL_SHADER_DISK_CACHE_SKIP_CLEANUP=1
PROTON_ENABLE_NVAPI=1
$COMMON_UNITY_VARS
ENVEOF

elif [ -f /etc/raptor-force-powersave ]; then
    cat << ENVEOF > /etc/environment.d/raptor-gpu.conf
mesa_glthread=false
MESA_SHADER_CACHE_DISABLE=true
$COMMON_UNITY_VARS
ENVEOF

elif [ "$GPU_VENDOR" = "nvidia" ]; then
    cat << ENVEOF > /etc/environment.d/raptor-gpu.conf
__GL_SHADER_DISK_CACHE=1
__GL_SHADER_DISK_CACHE_SKIP_CLEANUP=1
PROTON_ENABLE_NVAPI=1
__NV_PRIME_RENDER_OFFLOAD=1
$COMMON_UNITY_VARS
ENVEOF

elif [ "$GPU_VENDOR" = "amd" ] && [ "$IS_IGPU" = true ]; then
    cat << ENVEOF > /etc/environment.d/raptor-gpu.conf
AMD_VULKAN_ICD=RADV
mesa_glthread=true
MESA_SHADER_CACHE_DISABLE=false
$COMMON_UNITY_VARS
ENVEOF

elif [ "$GPU_VENDOR" = "amd" ]; then
    cat << ENVEOF > /etc/environment.d/raptor-gpu.conf
RADV_PERFTEST=gpl
AMD_VULKAN_ICD=RADV
mesa_glthread=true
MESA_SHADER_CACHE_DISABLE=false
$COMMON_UNITY_VARS
ENVEOF

elif [ "$GPU_VENDOR" = "intel" ]; then
    cat << ENVEOF > /etc/environment.d/raptor-gpu.conf
MESA_LOADER_DRIVER_OVERRIDE=iris
LIBGL_DRI3_DISABLE=0
vblank_mode=0
mesa_glthread=true
$COMMON_UNITY_VARS
ENVEOF

else
    cat << ENVEOF > /etc/environment.d/raptor-gpu.conf
mesa_glthread=true
MESA_SHADER_CACHE_DISABLE=false
$COMMON_UNITY_VARS
ENVEOF
fi
EOF
chmod +x /usr/bin/raptor-gpu-profile.sh

# Create systemd service for GPU detection at boot
cat << 'EOF' > /usr/lib/systemd/system/raptor-gpu-profile.service
[Unit]
Description=Raptor OS GPU Profile Detection
After=sysinit.target
Before=display-manager.service

[Service]
Type=oneshot
ExecStart=/usr/bin/raptor-gpu-profile.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

# Make browser choice script executable
chmod +x /usr/bin/raptor-browser-choice.sh 2>/dev/null || true

echo "HUD_READY"
