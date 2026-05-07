#!/bin/bash
set -oue pipefail
 
# ═══════════════════════════════════════════════════════════════════════════════
# Raptor OS — HUD Script
# Installs: theme, KDE globals, profile switcher, RAM optimizer, GPU profiler,
#           desktop category, and all .desktop entries.
# The Update Center is handled by raptor-update.sh (separate script).
# ═══════════════════════════════════════════════════════════════════════════════
 
# ── Neon Green theme ───────────────────────────────────────────────────────────
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
        cat << 'EOF' > "$dir/.config/kdeglobals"
[General]
ColorScheme=BreezeDark
AccentColor=51,255,51
accentColorFromWallpaper=false
EOF
    fi
done
 
# ── Theme autostart ────────────────────────────────────────────────────────────
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
 
for dir in /root /home/*; do
    if [ -d "$dir" ]; then
        mkdir -p "$dir/.config/autostart"
        cp /etc/skel/.config/autostart/raptor-theme.desktop "$dir/.config/autostart/" 2>/dev/null || true
    fi
done
 
# ── Profile Switcher script ────────────────────────────────────────────────────
cat << 'EOF' > /usr/bin/raptor-profile-switcher.sh
#!/bin/bash
 
CURRENT_GPU="Auto"
[ -f /etc/raptor-force-performance ] && CURRENT_GPU="Max Performance"
[ -f /etc/raptor-force-powersave ]   && CURRENT_GPU="Power Saving"
 
CHOICE=$(zenity --list \
  --title="Raptor OS — GPU Profile Switcher" \
  --text="Current GPU profile: <b>$CURRENT_GPU</b>\n\nSelect a new profile:" \
  --radiolist \
  --column="" --column="Profile" --column="Description" \
  TRUE  "Auto"            "Automatically detect and optimize for your GPU" \
  FALSE "Max Performance" "Maximum GPU performance, higher power usage" \
  FALSE "Power Saving"    "Reduced GPU usage, better battery life" \
  --width=640 --height=360 2>/dev/null) || exit 0
 
case "$CHOICE" in
  "Max Performance")
    sudo touch /etc/raptor-force-performance
    sudo rm -f /etc/raptor-force-powersave
    /usr/bin/raptor-gpu-profile.sh
    zenity --question --title="Raptor OS" \
      --text="Max Performance profile applied.\nLog out now to apply changes?" \
      --width=340 2>/dev/null \
      && qdbus org.kde.ksmserver /KSMServer logout 0 0 0
    ;;
  "Power Saving")
    sudo touch /etc/raptor-force-powersave
    sudo rm -f /etc/raptor-force-performance
    /usr/bin/raptor-gpu-profile.sh
    zenity --question --title="Raptor OS" \
      --text="Power Saving profile applied.\nLog out now to apply changes?" \
      --width=340 2>/dev/null \
      && qdbus org.kde.ksmserver /KSMServer logout 0 0 0
    ;;
  "Auto")
    sudo rm -f /etc/raptor-force-performance /etc/raptor-force-powersave
    /usr/bin/raptor-gpu-profile.sh
    zenity --question --title="Raptor OS" \
      --text="Auto profile applied.\nLog out now to apply changes?" \
      --width=340 2>/dev/null \
      && qdbus org.kde.ksmserver /KSMServer logout 0 0 0
    ;;
esac
EOF
chmod +x /usr/bin/raptor-profile-switcher.sh
 
# ── RAM Optimizer script ───────────────────────────────────────────────────────
cat << 'EOF' > /usr/bin/raptor-ram-optimizer.sh
#!/bin/bash
 
BEFORE=$(free -h | awk '/^Mem:/{print $3}')
 
zenity --question \
  --title="Raptor RAM Optimizer" \
  --text="Current RAM usage: <b>$BEFORE</b>\n\nThis will:\n• Sync filesystem buffers\n• Drop page/slab/inode caches\n• Compact memory\n• Optionally pause indexers\n\nContinue?" \
  --width=360 2>/dev/null || exit 0
 
# Flush buffers then drop caches
sync
echo 3 | sudo tee /proc/sys/vm/drop_caches > /dev/null
 
# Compact memory (kernel 3.10+)
echo 1 | sudo tee /proc/sys/vm/compact_memory > /dev/null 2>/dev/null || true
 
zenity --question \
  --title="Raptor RAM Optimizer" \
  --text="Suspend background indexers (baloo, tracker) to free additional RAM?\n\nThey will resume on next login." \
  --width=380 2>/dev/null \
  && {
    pkill -STOP -f "baloo_file" 2>/dev/null || true
    pkill -STOP -f "tracker"    2>/dev/null || true
  }
 
AFTER=$(free -h | awk '/^Mem:/{print $3}')
 
zenity --info \
  --title="Raptor RAM Optimizer — Done" \
  --text="Memory freed!\n\n<b>Before:</b> $BEFORE\n<b>After:</b>  $AFTER" \
  --width=300 2>/dev/null
EOF
chmod +x /usr/bin/raptor-ram-optimizer.sh
 
# ── GPU Profile detection script ───────────────────────────────────────────────
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
lspci | grep -i "VGA\|3D\|Display" | grep -qi "intel" && IS_IGPU=true
lspci -v | grep -i "VGA\|3D\|Display" -A5 | grep -qi \
    "cezanne\|renoir\|lucienne\|rembrandt\|mendocino\|integrated\|apu" && IS_IGPU=true
 
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
 
# ── systemd service for GPU detection at boot ──────────────────────────────────
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
 
# ── Raptor OS app menu category ────────────────────────────────────────────────
mkdir -p /usr/share/desktop-directories
cat << 'EOF' > /usr/share/desktop-directories/raptor-os.directory
[Desktop Entry]
Type=Directory
Name=Raptor OS
Comment=Raptor OS system tools and utilities
Icon=system-help
EOF
 
mkdir -p /etc/xdg/menus/applications-merged
cat << 'EOF' > /etc/xdg/menus/applications-merged/raptor-os.menu
<!DOCTYPE Menu PUBLIC "-//freedesktop//DTD Menu 1.0//EN"
  "http://www.freedesktop.org/standards/menu-spec/menu-1.0.dtd">
<Menu>
  <Name>Applications</Name>
  <Menu>
    <Name>Raptor OS</Name>
    <Directory>raptor-os.directory</Directory>
    <Include>
      <Category>X-RaptorOS</Category>
    </Include>
  </Menu>
</Menu>
EOF
 
# ── .desktop entries ───────────────────────────────────────────────────────────
mkdir -p /usr/share/applications
 
cat << 'EOF' > /usr/share/applications/raptor-profile-switcher.desktop
[Desktop Entry]
Type=Application
Name=Raptor GPU Profile Switcher
Comment=Switch between GPU performance profiles
Exec=/usr/bin/raptor-profile-switcher.sh
Icon=preferences-system-performance
Terminal=false
Categories=X-RaptorOS;System;Settings;
Keywords=gpu;performance;power;profile;raptor;
EOF
 
cat << 'EOF' > /usr/share/applications/raptor-ram-optimizer.desktop
[Desktop Entry]
Type=Application
Name=Raptor RAM Optimizer
Comment=Free up RAM and optimize memory usage
Exec=/usr/bin/raptor-ram-optimizer.sh
Icon=memory
Terminal=false
Categories=X-RaptorOS;System;Settings;
Keywords=ram;memory;optimize;performance;raptor;
EOF
 
# Make browser choice script executable if present
chmod +x /usr/bin/raptor-browser-choice.sh 2>/dev/null || true
 
# Rebuild KDE sycoca so new menu entries appear immediately
kbuildsycoca6 --noincremental 2>/dev/null || true
 
echo "HUD_READY"
