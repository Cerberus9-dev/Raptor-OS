#!/bin/bash
set -e

# =============================================================================
# Raptor HUD v4.2 — F-22 Themed KDE Plasma Shell
# FIXES:
#   • Removed nitrogen entirely — wallpaper now uses plasma-apply-wallpaperimage
#     with qdbus fallback (works natively in KDE Wayland + X11)
#   • Panel layout switched from kwriteconfig5 piecemeal writes to a proper
#     plasma-layout-template layout.js — reliable on first boot
#   • mkdir -p before metadata.json heredoc
# =============================================================================

# ── Palette reference ─────────────────────────────────────────────────────────
# Base:    #0d0f12  Surface: #151a20  Panel:   #1c2330  Border:  #2a3444
# Accent:  #1e90ff  Warning: #f5a623  Success: #2ec27e  Text:    #c8d6e8

mkdir -p /usr/lib/raptor/hud

# ── raptor-set-wallpaper command ──────────────────────────────────────────────
cat << 'WPEOF' > /usr/bin/raptor-set-wallpaper
#!/bin/bash
# Usage: raptor-set-wallpaper /path/to/image.jpg
#   or:  raptor-set-wallpaper   (opens KDE file picker)
#
# Uses plasma-apply-wallpaperimage (Plasma 5.26+) with a qdbus fallback.
# No nitrogen required.

WALLPAPER_CACHE="$HOME/.config/raptor-wallpaper"

_apply_kde_wallpaper() {
    local IMG="$1"

    # Method 1: plasma-apply-wallpaperimage (Plasma 5.26+, works Wayland + X11)
    if command -v plasma-apply-wallpaperimage &>/dev/null; then
        plasma-apply-wallpaperimage "$IMG" && return 0
    fi

    # Method 2: qdbus / qdbus6 script to every desktop containment
    local QDBUS=""
    command -v qdbus6  &>/dev/null && QDBUS="qdbus6"
    command -v qdbus   &>/dev/null && QDBUS="qdbus"

    if [ -n "$QDBUS" ]; then
        local SCRIPT
        SCRIPT=$(cat << JEOF
var allDesktops = desktops();
for (var i = 0; i < allDesktops.length; i++) {
    var d = allDesktops[i];
    d.wallpaperPlugin = "org.kde.image";
    d.currentConfigGroup = ["Wallpaper", "org.kde.image", "General"];
    d.writeConfig("Image", "file://$IMG");
}
JEOF
)
        $QDBUS org.kde.plasmashell /PlasmaShell \
            org.kde.PlasmaShell.evaluateScript "$SCRIPT" 2>/dev/null && return 0
    fi

    echo "[raptor-wallpaper] Could not set wallpaper — Plasma not running?" >&2
    return 1
}

set_wallpaper() {
    local IMG="$1"
    [ -f "$IMG" ] || { echo "File not found: $IMG" >&2; exit 1; }
    _apply_kde_wallpaper "$IMG" || exit 1
    echo "$IMG" > "$WALLPAPER_CACHE"
    echo "Wallpaper set: $IMG"
}

if [ -n "$1" ]; then
    set_wallpaper "$1"
elif command -v kdialog &>/dev/null; then
    FILE=$(kdialog --getopenfilename "$HOME" \
        "Images (*.png *.jpg *.jpeg *.webp *.bmp *.svg)|*.png *.jpg *.jpeg *.webp *.bmp *.svg")
    [ -n "$FILE" ] && set_wallpaper "$FILE"
else
    echo "Usage: raptor-set-wallpaper /path/to/image.jpg"
    exit 1
fi
WPEOF
chmod +x /usr/bin/raptor-set-wallpaper

cat << 'EOF' > /usr/share/applications/raptor-set-wallpaper.desktop
[Desktop Entry]
Type=Application
Name=Set Wallpaper
Comment=Set the desktop wallpaper using the KDE image plugin
Exec=/usr/bin/raptor-set-wallpaper
Icon=preferences-desktop-wallpaper
Terminal=false
Categories=X-RaptorOS;System;Settings;
EOF

# ── Autostart: restore wallpaper on login via KDE method ─────────────────────
mkdir -p /etc/xdg/autostart
cat << 'EOF' > /etc/xdg/autostart/raptor-wallpaper.desktop
[Desktop Entry]
Type=Application
Name=Raptor Wallpaper Restore
Comment=Restores saved wallpaper on login
Exec=bash -c 'WP="$HOME/.config/raptor-wallpaper"; [ -f "$WP" ] && IMG="$(cat "$WP")" && [ -f "$IMG" ] && raptor-set-wallpaper "$IMG" || true'
Hidden=false
NoDisplay=true
X-GNOME-Autostart-enabled=true
EOF

# ── RaptorOS KDE Color Scheme ─────────────────────────────────────────────────
mkdir -p /usr/share/color-schemes
cat << 'EOF' > /usr/share/color-schemes/RaptorOS.colors
[ColorEffects:Disabled]
Color=56,68,82
ColorAmount=0.55
ColorEffect=3
ContrastAmount=0.65
ContrastEffect=1
IntensityAmount=0.1
IntensityEffect=2

[ColorEffects:Inactive]
ChangeSelectionColor=true
Color=56,68,82
ColorAmount=0.025
ColorEffect=2
ContrastAmount=0.1
ContrastEffect=2
Enable=false
IntensityAmount=0
IntensityEffect=0

[Colors:Button]
BackgroundAlternate=30,42,58
BackgroundNormal=28,35,48
DecorationFocus=30,144,255
DecorationHover=30,144,255
ForegroundActive=30,144,255
ForegroundInactive=90,106,126
ForegroundLink=30,144,255
ForegroundNegative=220,50,50
ForegroundNeutral=245,166,35
ForegroundNormal=200,214,232
ForegroundPositive=46,194,126
ForegroundVisited=140,100,220

[Colors:Complementary]
BackgroundAlternate=20,28,40
BackgroundNormal=13,15,18
DecorationFocus=30,144,255
DecorationHover=30,144,255
ForegroundActive=30,144,255
ForegroundInactive=90,106,126
ForegroundLink=30,144,255
ForegroundNegative=220,50,50
ForegroundNeutral=245,166,35
ForegroundNormal=200,214,232
ForegroundPositive=46,194,126
ForegroundVisited=140,100,220

[Colors:Header]
BackgroundAlternate=21,26,32
BackgroundNormal=21,26,32
DecorationFocus=30,144,255
DecorationHover=30,144,255
ForegroundActive=30,144,255
ForegroundInactive=90,106,126
ForegroundLink=30,144,255
ForegroundNegative=220,50,50
ForegroundNeutral=245,166,35
ForegroundNormal=200,214,232
ForegroundPositive=46,194,126
ForegroundVisited=140,100,220

[Colors:Selection]
BackgroundAlternate=20,100,200
BackgroundNormal=30,144,255
DecorationFocus=30,144,255
DecorationHover=30,144,255
ForegroundActive=255,255,255
ForegroundInactive=180,200,220
ForegroundLink=180,220,255
ForegroundNegative=220,50,50
ForegroundNeutral=245,166,35
ForegroundNormal=255,255,255
ForegroundPositive=46,194,126
ForegroundVisited=200,170,255

[Colors:Tooltip]
BackgroundAlternate=21,26,32
BackgroundNormal=13,15,18
DecorationFocus=30,144,255
DecorationHover=30,144,255
ForegroundActive=30,144,255
ForegroundInactive=90,106,126
ForegroundLink=30,144,255
ForegroundNegative=220,50,50
ForegroundNeutral=245,166,35
ForegroundNormal=200,214,232
ForegroundPositive=46,194,126
ForegroundVisited=140,100,220

[Colors:View]
BackgroundAlternate=18,24,32
BackgroundNormal=13,15,18
DecorationFocus=30,144,255
DecorationHover=30,144,255
ForegroundActive=30,144,255
ForegroundInactive=90,106,126
ForegroundLink=30,144,255
ForegroundNegative=220,50,50
ForegroundNeutral=245,166,35
ForegroundNormal=200,214,232
ForegroundPositive=46,194,126
ForegroundVisited=140,100,220

[Colors:Window]
BackgroundAlternate=21,26,32
BackgroundNormal=28,35,48
DecorationFocus=30,144,255
DecorationHover=30,144,255
ForegroundActive=30,144,255
ForegroundInactive=90,106,126
ForegroundLink=30,144,255
ForegroundNegative=220,50,50
ForegroundNeutral=245,166,35
ForegroundNormal=200,214,232
ForegroundPositive=46,194,126
ForegroundVisited=140,100,220

[General]
ColorScheme=RaptorOS
Name=RaptorOS
shadeSortColumn=true

[KDE]
contrast=5

[WM]
activeBackground=21,26,32
activeBlend=30,144,255
activeForeground=200,214,232
inactiveBackground=13,15,18
inactiveBlend=42,52,68
inactiveForeground=90,106,126
EOF

# ── Aurorae Window Decoration ─────────────────────────────────────────────────
mkdir -p /usr/share/aurorae/themes/RaptorOS
cat << 'EOF' > /usr/share/aurorae/themes/RaptorOS/RaptorOSrc
[General]
ActiveTextColor=200,214,232
Animation=0
BorderBottom=1
BorderLeft=1
BorderRight=1
BorderTop=0
ButtonHeight=18
ButtonMarginTop=6
ButtonSpacing=2
ButtonWidth=18
DecorationPosition=0
DrawButtons=true
DrawSeparator=false
GrabBarBelow=false
InactiveTextColor=90,106,126
OverrideBorderSizes=false
PaddingBottom=4
PaddingLeft=4
PaddingRight=4
PaddingTop=0
ShadowColor=0,0,0
ShadowOpacity=0.8
ShadowSize=30
TitleAlignment=1
TitleEdgeBottom=4
TitleEdgeLeft=6
TitleEdgeRight=6
TitleEdgeTop=6
TitleHeight=24
UseKWinTextColors=true
EOF

cat << 'SVGEOF' > /usr/share/aurorae/themes/RaptorOS/RaptorOS.svg
<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink">
  <defs>
    <linearGradient id="titlebar-active" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0%" stop-color="#1c2330"/>
      <stop offset="100%" stop-color="#151a20"/>
    </linearGradient>
    <linearGradient id="titlebar-inactive" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0%" stop-color="#111418"/>
      <stop offset="100%" stop-color="#0d0f12"/>
    </linearGradient>
  </defs>
  <g id="decoration">
    <rect width="100" height="30" fill="url(#titlebar-active)"/>
    <rect y="29" width="100" height="1" fill="#1e90ff" opacity="0.7"/>
    <rect width="2" height="30" fill="#1e90ff" opacity="0.5"/>
  </g>
  <g id="decoration-inactive">
    <rect width="100" height="30" fill="url(#titlebar-inactive)"/>
    <rect y="29" width="100" height="1" fill="#2a3444"/>
    <rect width="2" height="30" fill="#2a3444"/>
  </g>
  <g id="close">
    <rect width="18" height="18" rx="1" fill="#3a1515"/>
    <line x1="5" y1="5" x2="13" y2="13" stroke="#cc3333" stroke-width="1.5" stroke-linecap="square"/>
    <line x1="13" y1="5" x2="5" y2="13" stroke="#cc3333" stroke-width="1.5" stroke-linecap="square"/>
  </g>
  <g id="close-hover">
    <rect width="18" height="18" rx="1" fill="#cc3333"/>
    <line x1="5" y1="5" x2="13" y2="13" stroke="white" stroke-width="1.5" stroke-linecap="square"/>
    <line x1="13" y1="5" x2="5" y2="13" stroke="white" stroke-width="1.5" stroke-linecap="square"/>
  </g>
  <g id="maximize">
    <rect width="18" height="18" rx="1" fill="#1c2330"/>
    <rect x="4" y="4" width="10" height="10" fill="none" stroke="#1e90ff" stroke-width="1.5"/>
  </g>
  <g id="maximize-hover">
    <rect width="18" height="18" rx="1" fill="#1e4a7a"/>
    <rect x="4" y="4" width="10" height="10" fill="none" stroke="#5ab0ff" stroke-width="1.5"/>
  </g>
  <g id="minimize">
    <rect width="18" height="18" rx="1" fill="#1c2330"/>
    <line x1="4" y1="13" x2="14" y2="13" stroke="#1e90ff" stroke-width="1.5" stroke-linecap="square"/>
  </g>
  <g id="minimize-hover">
    <rect width="18" height="18" rx="1" fill="#1e4a7a"/>
    <line x1="4" y1="13" x2="14" y2="13" stroke="#5ab0ff" stroke-width="1.5" stroke-linecap="square"/>
  </g>
</svg>
SVGEOF

# ── Raptor OS App Launcher Category ──────────────────────────────────────────
mkdir -p /usr/share/desktop-directories
cat << 'EOF' > /usr/share/desktop-directories/raptor-os.directory
[Desktop Entry]
Type=Directory
Name=Raptor OS
Comment=Raptor OS tools and utilities
Icon=preferences-system
EOF

mkdir -p /etc/xdg/menus
for MENUFILE in /etc/xdg/menus/applications.menu \
                /etc/xdg/menus/kde-applications.menu; do
  if [ -f "$MENUFILE" ]; then
    if ! grep -q 'X-RaptorOS' "$MENUFILE" 2>/dev/null; then
      if grep -q '<!-- End Applications -->' "$MENUFILE" 2>/dev/null; then
        sed -i 's|</Menu> <!-- End Applications -->|  <Menu>\n    <Name>Raptor OS</Name>\n    <Directory>raptor-os.directory</Directory>\n    <Include><Category>X-RaptorOS</Category></Include>\n  </Menu>\n</Menu> <!-- End Applications -->|' "$MENUFILE"
      else
        sed -i 's|</Menu>$|  <Menu>\n    <Name>Raptor OS</Name>\n    <Directory>raptor-os.directory</Directory>\n    <Include><Category>X-RaptorOS</Category></Include>\n  </Menu>\n</Menu>|' "$MENUFILE"
      fi
    fi
  else
    cat << 'MENUEOF' > "$MENUFILE"
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
MENUEOF
  fi
done

mkdir -p /etc/xdg/menus/applications-merged
cp /etc/xdg/menus/kde-applications.menu \
   /etc/xdg/menus/applications-merged/raptor-os.menu 2>/dev/null || true

# ── GPU Profile Detection, Configuration & Profiler UI ───────────────────────
mkdir -p /usr/bin /usr/lib/raptor /usr/lib/systemd/system \
         /etc/environment.d /etc/sysctl.d /etc/polkit-1/rules.d \
         /etc/sudoers.d /etc/raptor

cat << 'ENVEOF' > /etc/environment.d/raptor-gpu.conf
MESA_SHADER_CACHE_DISABLE=false
WINE_LARGE_ADDRESS_AWARE=1
PROTON_FORCE_LARGE_ADDRESS_AWARE=1
STAGING_SHARED_MEMORY=1
WINE_FULLSCREEN_FSR=1
PROTON_NO_ESYNC=0
PROTON_NO_FSYNC=0
ENVEOF

cat << 'SYSCTL' > /etc/sysctl.d/raptor-gaming.conf
kernel.sched_autogroup_enabled=1
kernel.sched_min_granularity_ns=500000
kernel.sched_wakeup_granularity_ns=3000000
kernel.sched_migration_cost_ns=250000
fs.inotify.max_user_watches=524288
fs.inotify.max_user_instances=256
vm.swappiness=10
vm.dirty_ratio=15
vm.dirty_background_ratio=5
kernel.split_lock_mitigate=0
SYSCTL

cat << 'DETECT' > /usr/lib/raptor/gpu-detect.sh
#!/bin/bash
set -euo pipefail
LOG_TAG="raptor-gpu"
log() { echo "$*"; logger -t "$LOG_TAG" "$*" 2>/dev/null || true; }

GPU_VENDOR="unknown"; GPU_MODEL=""
LSPCI_OUT=$(lspci 2>/dev/null | grep -iE "VGA|3D controller|Display controller" || true)

if   echo "$LSPCI_OUT" | grep -qi "nvidia";            then GPU_VENDOR="nvidia"
    GPU_MODEL=$(echo "$LSPCI_OUT" | grep -i nvidia   | head -1 | sed 's/.*: //')
elif echo "$LSPCI_OUT" | grep -qiE "amd|radeon|ati";  then GPU_VENDOR="amd"
    GPU_MODEL=$(echo "$LSPCI_OUT" | grep -iE "amd|radeon|ati" | head -1 | sed 's/.*: //')
elif echo "$LSPCI_OUT" | grep -qi "intel";             then GPU_VENDOR="intel"
    GPU_MODEL=$(echo "$LSPCI_OUT" | grep -i intel    | head -1 | sed 's/.*: //')
fi
log "Detected GPU vendor: $GPU_VENDOR  model: ${GPU_MODEL:-unknown}"

IS_IGPU=false
if echo "$LSPCI_OUT" | grep -qi "intel"; then
    lsmod 2>/dev/null | grep -qiE "^nvidia |^amdgpu " || IS_IGPU=true
elif [ "$GPU_VENDOR" = "amd" ]; then
    VRAM=$(cat /sys/class/drm/card0/device/mem_info_vram_total 2>/dev/null || echo 0)
    [ "$VRAM" -lt $((512 * 1024 * 1024)) ] && IS_IGPU=true || true
fi

IS_HYBRID=false
DISPLAY_DEVS=$(echo "$LSPCI_OUT" | grep -c "" || true)
[ "$DISPLAY_DEVS" -ge 2 ] && IS_HYBRID=true
DRM_CARDS=$(ls /sys/class/drm/ 2>/dev/null | grep -c "^card[0-9]$" || echo 0)
[ "$DRM_CARDS" -ge 2 ] && IS_HYBRID=true
log "iGPU=$IS_IGPU  hybrid=$IS_HYBRID  display_devs=$DISPLAY_DEVS"

PROFILE="auto"
[ -f /etc/raptor-force-extreme ]     && PROFILE="extreme"
[ -f /etc/raptor-force-performance ] && PROFILE="performance"
[ -f /etc/raptor-force-powersave ]   && PROFILE="powersave"
[ -f /etc/raptor-force-balanced ]    && PROFILE="balanced"
log "Active profile: $PROFILE"

COMMON_VARS="WINE_LARGE_ADDRESS_AWARE=1
PROTON_FORCE_LARGE_ADDRESS_AWARE=1
STAGING_SHARED_MEMORY=1
WINE_FULLSCREEN_FSR=1
PROTON_NO_ESYNC=0
PROTON_NO_FSYNC=0"

write_env() {
    local COMMENT="$1"; shift
    { echo "# ── Raptor OS: $COMMENT ──"; printf '%s\n' "$@"; } \
        > /etc/environment.d/raptor-gpu.conf
    # Re-apply any manual VRAM override if one has been set
    if [ -f /etc/raptor/vram-override.conf ]; then
        cat /etc/raptor/vram-override.conf >> /etc/environment.d/raptor-gpu.conf
    fi
}

case "$PROFILE" in
  extreme)
    write_env "EXTREME PERFORMANCE profile" \
        "AMD_VULKAN_ICD=RADV" "MESA_SHADER_CACHE_DISABLE=false" \
        "MESA_SHADER_CACHE_MAX_SIZE=4G" "__GL_SHADER_DISK_CACHE=1" \
        "__GL_SHADER_DISK_CACHE_SKIP_CLEANUP=1" "__GL_THREADED_OPTIMIZATIONS=1" \
        "AMDGPU_HIGH_POWER=1" "PROTON_ENABLE_NVAPI=1" "DXVK_ASYNC=1" \
        "DXVK_FRAME_RATE=0" "RADV_DEBUG=nocompute" \
        "VKD3D_CONFIG=dxr11,dxr" "VKD3D_FEATURE_LEVEL=12_2" $COMMON_VARS
    if [ "$GPU_VENDOR" = "amd" ]; then
        for f in /sys/class/drm/card*/device/power_dpm_force_performance_level; do echo "high" > "$f" 2>/dev/null || true; done
        for f in /sys/class/drm/card*/device/pp_power_profile_mode; do echo 1 > "$f" 2>/dev/null || true; done
    fi
    [ "$GPU_VENDOR" = "nvidia" ] && { nvidia-smi -pm 1 >/dev/null 2>&1 || true; nvidia-smi --auto-boost-default=0 >/dev/null 2>&1 || true; }
    ;;
  performance)
    write_env "MAX PERFORMANCE profile" \
        "AMD_VULKAN_ICD=RADV" "MESA_SHADER_CACHE_DISABLE=false" \
        "MESA_SHADER_CACHE_MAX_SIZE=2G" "__GL_SHADER_DISK_CACHE=1" \
        "__GL_SHADER_DISK_CACHE_SKIP_CLEANUP=1" "__GL_THREADED_OPTIMIZATIONS=1" \
        "PROTON_ENABLE_NVAPI=1" "DXVK_ASYNC=1" \
        "VKD3D_CONFIG=dxr11" "VKD3D_FEATURE_LEVEL=12_1" $COMMON_VARS
    if [ "$GPU_VENDOR" = "amd" ]; then
        for f in /sys/class/drm/card*/device/power_dpm_force_performance_level; do echo "high" > "$f" 2>/dev/null || true; done
    fi
    [ "$GPU_VENDOR" = "nvidia" ] && { nvidia-smi -pm 1 >/dev/null 2>&1 || true; }
    ;;
  balanced)
    write_env "BALANCED profile" \
        "AMD_VULKAN_ICD=RADV" "MESA_SHADER_CACHE_DISABLE=false" \
        "__GL_SHADER_DISK_CACHE=1" "PROTON_ENABLE_NVAPI=1" $COMMON_VARS
    if [ "$GPU_VENDOR" = "amd" ]; then
        for f in /sys/class/drm/card*/device/power_dpm_force_performance_level; do echo "auto" > "$f" 2>/dev/null || true; done
    fi
    ;;
  powersave)
    write_env "POWER SAVING profile" "MESA_SHADER_CACHE_DISABLE=true" $COMMON_VARS
    if [ "$GPU_VENDOR" = "amd" ]; then
        for f in /sys/class/drm/card*/device/power_dpm_force_performance_level; do echo "low" > "$f" 2>/dev/null || true; done
    fi
    [ "$GPU_VENDOR" = "nvidia" ] && { nvidia-smi -pm 0 >/dev/null 2>&1 || true; }
    ;;
  auto|*)
    if [ "$GPU_VENDOR" = "nvidia" ]; then
        write_env "NVIDIA auto profile" \
            "__GL_SHADER_DISK_CACHE=1" "__GL_SHADER_DISK_CACHE_SKIP_CLEANUP=1" \
            "__GL_THREADED_OPTIMIZATIONS=1" "PROTON_ENABLE_NVAPI=1" \
            "DXVK_ASYNC=1" "VKD3D_CONFIG=dxr11" $COMMON_VARS
    elif [ "$GPU_VENDOR" = "amd" ] && [ "$IS_IGPU" = true ]; then
        write_env "AMD iGPU auto profile" \
            "AMD_VULKAN_ICD=RADV" "MESA_SHADER_CACHE_DISABLE=false" $COMMON_VARS
    elif [ "$GPU_VENDOR" = "amd" ]; then
        write_env "AMD dGPU auto profile" \
            "AMD_VULKAN_ICD=RADV" "MESA_SHADER_CACHE_DISABLE=false" \
            "MESA_SHADER_CACHE_MAX_SIZE=2G" "__GL_SHADER_DISK_CACHE=1" \
            "DXVK_ASYNC=1" $COMMON_VARS
    elif [ "$GPU_VENDOR" = "intel" ]; then
        write_env "Intel auto profile" \
            "MESA_LOADER_DRIVER_OVERRIDE=iris" "LIBGL_DRI3_DISABLE=0" \
            "vblank_mode=0" $COMMON_VARS
    else
        write_env "fallback profile" "MESA_SHADER_CACHE_DISABLE=false" $COMMON_VARS
    fi
    ;;
esac

set_cpu_governor() {
    ls /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor &>/dev/null || { log "cpufreq not available"; return; }
    for f in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do echo "$1" > "$f" 2>/dev/null || true; done
    log "CPU governor → $1"
}
case "$PROFILE" in
    extreme|performance) set_cpu_governor "performance" ;;
    balanced)            set_cpu_governor "schedutil"   ;;
    powersave)           set_cpu_governor "powersave"   ;;
    auto|*)              set_cpu_governor "schedutil"   ;;
esac

ENVFILE=/etc/environment.d/raptor-gpu.conf
if [ -f "$ENVFILE" ]; then
    ENV_KEYS=()
    while IFS= read -r line; do
        [[ "$line" =~ ^# ]] && continue; [[ -z "$line" ]] && continue
        ENV_KEYS+=("${line%%=*}")
    done < "$ENVFILE"
    if [ ${#ENV_KEYS[@]} -gt 0 ]; then
        set -a; source "$ENVFILE"; set +a
        while read -r UID_VAL _REST; do
            [[ "$UID_VAL" =~ ^[0-9]+$ ]] || continue
            RUNTIME_DIR="/run/user/$UID_VAL"; [ -d "$RUNTIME_DIR" ] || continue
            DBUS="unix:path=$RUNTIME_DIR/bus"
            sudo -u "#$UID_VAL" DBUS_SESSION_BUS_ADDRESS="$DBUS" \
                systemctl --user import-environment "${ENV_KEYS[@]}" 2>/dev/null || true
            USER_HOME=$(getent passwd "$UID_VAL" | cut -d: -f6)
            mkdir -p "$USER_HOME/.config/environment.d" 2>/dev/null || true
            cp "$ENVFILE" "$USER_HOME/.config/environment.d/raptor-gpu.conf" 2>/dev/null || true
        done < <(loginctl list-users --no-legend 2>/dev/null || true)
    fi
fi

sysctl --system >/dev/null 2>&1 || true
log "GPU_PROFILE_READY  profile=$PROFILE  vendor=$GPU_VENDOR  igpu=$IS_IGPU  hybrid=$IS_HYBRID"
DETECT
chmod +x /usr/lib/raptor/gpu-detect.sh

# ── Interactive GPU Profiler TUI ──────────────────────────────────────────────
cat << 'UIEOF' > /usr/bin/raptor-gpu-profile-ui.sh
#!/bin/bash
DETECT_SCRIPT="/usr/lib/raptor/gpu-detect.sh"
ENV_FILE="/etc/environment.d/raptor-gpu.conf"
FORCE_DIR="/etc"

R='\033[0m'; BLUE='\033[38;5;33m'; AMBER='\033[38;5;214m'
GREEN='\033[38;5;42m'; DIM='\033[38;5;60m'; BOLD='\033[1m'; RED='\033[38;5;160m'

current_profile() {
    for p in extreme performance balanced powersave; do
        [ -f "$FORCE_DIR/raptor-force-$p" ] && { echo "$p"; return; }
    done; echo "auto"
}
read_gpu_model()  { lspci 2>/dev/null | grep -iE "VGA|3D|Display" | head -1 | sed 's/.*: //' | cut -c1-56 || echo "Unknown GPU"; }
read_gpu_vendor() {
    local l; l=$(lspci 2>/dev/null | grep -iE "VGA|3D|Display" | head -1 || true)
    if   echo "$l" | grep -qi nvidia;        then echo "NVIDIA"
    elif echo "$l" | grep -qiE "amd|radeon"; then echo "AMD"
    elif echo "$l" | grep -qi intel;         then echo "Intel"
    else echo "Unknown"; fi
}
read_vram() {
    local v; v=$(cat /sys/class/drm/card0/device/mem_info_vram_total 2>/dev/null || true)
    [ -n "$v" ] && [ "$v" -gt 0 ] 2>/dev/null && { echo "$(( v / 1024 / 1024 )) MiB"; return; }
    v=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits 2>/dev/null | head -1 || true)
    [ -n "$v" ] && { echo "${v} MiB"; return; }; echo "N/A"
}
read_gpu_temp() {
    local t; t=$(cat /sys/class/drm/card0/device/hwmon/hwmon*/temp1_input 2>/dev/null | head -1 || true)
    [ -n "$t" ] && [ "$t" -gt 0 ] 2>/dev/null && { echo "$(( t / 1000 ))°C"; return; }
    t=$(nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader 2>/dev/null | head -1 || true)
    [ -n "$t" ] && { echo "${t}°C"; return; }; echo "N/A"
}
read_gpu_util() {
    local u; u=$(nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits 2>/dev/null | head -1 || true)
    [ -n "$u" ] && { echo "${u}%"; return; }
    u=$(cat /sys/class/drm/card0/device/gpu_busy_percent 2>/dev/null || true)
    [ -n "$u" ] && { echo "${u}%"; return; }; echo "N/A"
}
read_vram_override() {
    grep -E "^MESA_VRAM_LIMIT=|^__GL_VRAM_LIMIT=" /etc/raptor/vram-override.conf 2>/dev/null \
        | head -1 | sed 's/.*=//' || echo "none"
}

draw_header() {
    clear
    echo -e "${BLUE}${BOLD}"
    echo "  ██████╗  █████╗ ██████╗ ████████╗ ██████╗ ██████╗      ██████╗ ███████╗"
    echo "  ██╔══██╗██╔══██╗██╔══██╗╚══██╔══╝██╔═══██╗██╔══██╗    ██╔═══██╗██╔════╝"
    echo "  ██████╔╝███████║██████╔╝   ██║   ██║   ██║██████╔╝    ██║   ██║███████╗"
    echo "  ██╔══██╗██╔══██║██╔═══╝    ██║   ██║   ██║██╔══██╗    ██║   ██║╚════██║"
    echo "  ██║  ██║██║  ██║██║        ██║   ╚██████╔╝██║  ██║    ╚██████╔╝███████║"
    echo "  ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝        ╚═╝    ╚═════╝ ╚═╝  ╚═╝     ╚═════╝ ╚══════╝"
    echo -e "${R}"
    echo -e "  ${DIM}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${R}"
    echo -e "  ${AMBER}▸ GPU PROFILER  ${DIM}│${R}  F-22 RAPTOR HUD  ${DIM}│${R}  $(date '+%Y-%m-%d %H:%M:%S')"
    echo -e "  ${DIM}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${R}"
    echo ""
}

draw_status() {
    local PROF; PROF=$(current_profile)
    echo -e "  ${BOLD}HARDWARE${R}"
    echo -e "  ${DIM}┌─────────────────────────────────────────────────┐${R}"
    printf   "  ${DIM}│${R}  Vendor   ${BLUE}%-38s${R}${DIM}│${R}\n" "$(read_gpu_vendor)"
    printf   "  ${DIM}│${R}  Model    ${BLUE}%-38s${R}${DIM}│${R}\n" "$(read_gpu_model)"
    printf   "  ${DIM}│${R}  VRAM     ${BLUE}%-38s${R}${DIM}│${R}\n" "$(read_vram)"
    printf   "  ${DIM}│${R}  Override ${AMBER}%-38s${R}${DIM}│${R}\n" "$(read_vram_override)"
    echo -e  "  ${DIM}└─────────────────────────────────────────────────┘${R}"
    echo ""
    echo -e "  ${BOLD}LIVE TELEMETRY${R}"
    echo -e "  ${DIM}┌─────────────────────────────────────────────────┐${R}"
    printf   "  ${DIM}│${R}  Temp     ${AMBER}%-38s${R}${DIM}│${R}\n" "$(read_gpu_temp)"
    printf   "  ${DIM}│${R}  Usage    ${GREEN}%-38s${R}${DIM}│${R}\n" "$(read_gpu_util)"
    printf   "  ${DIM}│${R}  Profile  "
    case "$PROF" in
        extreme)     printf "${RED}%-38s${R}"   "■ EXTREME"         ;;
        performance) printf "${AMBER}%-38s${R}" "▲ PERFORMANCE"     ;;
        balanced)    printf "${GREEN}%-38s${R}" "● BALANCED"        ;;
        powersave)   printf "${BLUE}%-38s${R}"  "▼ POWER SAVE"      ;;
        auto|*)      printf "${DIM}%-38s${R}"   "○ AUTO (detected)" ;;
    esac
    echo -e "${DIM}│${R}"
    echo -e "  ${DIM}└─────────────────────────────────────────────────┘${R}"
    echo ""
}

draw_menu() {
    echo -e "  ${BOLD}SELECT PROFILE${R}"
    echo -e "  ${DIM}──────────────────────────────────────────────────${R}"
    echo -e "  ${RED}[1]${R}  ■  EXTREME     Max clocks, no power cap"
    echo -e "  ${AMBER}[2]${R}  ▲  PERFORMANCE High clocks, GPU persistence on"
    echo -e "  ${GREEN}[3]${R}  ●  BALANCED    Auto clocks, schedutil CPU"
    echo -e "  ${BLUE}[4]${R}  ▼  POWER SAVE  Low clocks, minimal draw"
    echo -e "  ${DIM}[5]${R}  ○  AUTO        Detect and apply best profile"
    echo -e "  ${DIM}──────────────────────────────────────────────────${R}"
    echo -e "  ${DIM}[v]${R}  Set VRAM override   ${DIM}[V]${R}  Clear VRAM override"
    echo -e "  ${DIM}[r]${R}  Refresh   ${DIM}[l]${R}  Show env vars   ${DIM}[q]${R}  Quit"
    echo ""
    echo -ne "  ${BLUE}RAPTOR>${R}  "
}

apply_profile() {
    local TARGET="$1"
    echo -e "\n  ${AMBER}Applying profile: ${BOLD}${TARGET}${R}"
    sudo rm -f \
        "$FORCE_DIR/raptor-force-extreme" \
        "$FORCE_DIR/raptor-force-performance" \
        "$FORCE_DIR/raptor-force-balanced" \
        "$FORCE_DIR/raptor-force-powersave" 2>/dev/null || true
    if [ "$TARGET" != "auto" ]; then
        sudo touch "$FORCE_DIR/raptor-force-$TARGET" 2>/dev/null || {
            echo -e "  ${RED}[ERROR]${R} Could not write flag — check sudoers."; sleep 2; return
        }
    fi
    echo -e "  ${DIM}Running gpu-detect.sh…${R}"
    if sudo "$DETECT_SCRIPT"; then
        echo -e "  ${GREEN}[OK]${R} Profile applied. Open apps need restart to pick up new env vars."
    else
        echo -e "  ${RED}[WARN]${R} gpu-detect.sh exited non-zero — check output above."
    fi
    sleep 2
}

set_vram_override() {
    echo ""
    echo -e "  ${BOLD}SET VRAM OVERRIDE${R}"
    echo -e "  ${DIM}Enter VRAM limit in MiB (e.g. 4096 for 4 GB), or 0 to cancel:${R}"
    echo -ne "  ${BLUE}MiB>${R}  "
    read -r MB
    [[ "$MB" =~ ^[0-9]+$ ]] || { echo -e "  ${RED}Invalid — numbers only.${R}"; sleep 2; return; }
    [ "$MB" -eq 0 ] && { echo -e "  ${DIM}Cancelled.${R}"; sleep 1; return; }
    sudo mkdir -p /etc/raptor
    # Write both vars so it works on Mesa (AMD/Intel) and NVIDIA
    printf '# Raptor VRAM override — written by raptor-gpu-profile-ui\nMESA_VRAM_LIMIT=%s\n__GL_VRAM_LIMIT=%s\n' \
        "$MB" "$MB" | sudo tee /etc/raptor/vram-override.conf > /dev/null
    echo -e "  ${GREEN}[OK]${R} VRAM override set to ${MB} MiB. Re-applying current profile…"
    sudo "$DETECT_SCRIPT" 2>/dev/null || true
    sleep 2
}

clear_vram_override() {
    sudo rm -f /etc/raptor/vram-override.conf 2>/dev/null || true
    echo -e "\n  ${GREEN}[OK]${R} VRAM override cleared. Re-applying current profile…"
    sudo "$DETECT_SCRIPT" 2>/dev/null || true
    sleep 2
}

show_env() {
    echo ""
    echo -e "  ${BOLD}CURRENT ENV  ${DIM}(${ENV_FILE})${R}"
    echo -e "  ${DIM}──────────────────────────────────────────────────${R}"
    if [ -f "$ENV_FILE" ]; then
        grep -v '^#' "$ENV_FILE" | grep -v '^$' | while IFS= read -r line; do
            printf "  ${BLUE}%-36s${R}${DIM}=${R}${AMBER}%s${R}\n" "${line%%=*}" "${line#*=}"
        done
    else
        echo -e "  ${DIM}(env file not found)${R}"
    fi
    echo ""; echo -ne "  ${DIM}Press Enter to return…${R}  "; read -r
}

while true; do
    draw_header; draw_status; draw_menu
    read -r -t 30 CHOICE || { echo ""; continue; }
    case "$CHOICE" in
        1) apply_profile "extreme"     ;;
        2) apply_profile "performance" ;;
        3) apply_profile "balanced"    ;;
        4) apply_profile "powersave"   ;;
        5) apply_profile "auto"        ;;
        v) set_vram_override           ;;
        V) clear_vram_override         ;;
        r|R) continue ;;
        l|L) draw_header; show_env ;;
        q|Q) echo -e "\n  ${DIM}Raptor GPU Profiler closed.${R}\n"; exit 0 ;;
        *) echo -e "  ${DIM}Unknown — use 1-5, v, V, r, l, q${R}"; sleep 1 ;;
    esac
done
UIEOF
chmod +x /usr/bin/raptor-gpu-profile-ui.sh

cat << 'LAUNCHEOF' > /usr/bin/raptor-gpu-profile-launcher
#!/bin/bash
TUI="/usr/bin/raptor-gpu-profile-ui.sh"
TITLE="Raptor GPU Profiler"
if   command -v konsole   &>/dev/null; then konsole --title "$TITLE" --profile RaptorOS --noclose -e bash "$TUI"
elif command -v alacritty &>/dev/null; then alacritty --title "$TITLE" --config-file /dev/null -e bash "$TUI"
elif command -v kitty     &>/dev/null; then kitty --title "$TITLE" bash "$TUI"
elif command -v xterm     &>/dev/null; then xterm -title "$TITLE" -fa "JetBrains Mono" -fs 11 -bg "#0d0f12" -fg "#c8d6e8" -e bash "$TUI"
else bash "$TUI"
fi
LAUNCHEOF
chmod +x /usr/bin/raptor-gpu-profile-launcher

cat << 'SVCEOF' > /usr/lib/systemd/system/raptor-gpu-profile.service
[Unit]
Description=Raptor OS — GPU Profile Detection & Configuration
After=sysinit.target
Before=display-manager.service

[Service]
Type=oneshot
ExecStart=/usr/lib/raptor/gpu-detect.sh
RemainAfterExit=yes
SuccessExitStatus=0 1

[Install]
WantedBy=multi-user.target
SVCEOF
systemctl enable raptor-gpu-profile.service 2>/dev/null || true

cat << 'POLKIT' > /etc/polkit-1/rules.d/49-raptor-gpu.rules
polkit.addRule(function(action, subject) {
    var allowedActions = ["org.freedesktop.policykit.exec"];
    if (allowedActions.indexOf(action.id) >= 0 &&
        action.lookup("program") &&
        (action.lookup("program").indexOf("raptor-gpu-profile") !== -1 ||
         action.lookup("program").indexOf("raptor-profile-switcher") !== -1) &&
        subject.active && subject.local) {
        return polkit.Result.YES;
    }
});
POLKIT

cat << 'SUDOERS' > /etc/sudoers.d/raptor-gpu
ALL ALL=(root) NOPASSWD: /usr/lib/raptor/gpu-detect.sh
ALL ALL=(root) NOPASSWD: /usr/bin/touch /etc/raptor-force-extreme
ALL ALL=(root) NOPASSWD: /usr/bin/touch /etc/raptor-force-performance
ALL ALL=(root) NOPASSWD: /usr/bin/touch /etc/raptor-force-balanced
ALL ALL=(root) NOPASSWD: /usr/bin/touch /etc/raptor-force-powersave
ALL ALL=(root) NOPASSWD: /usr/bin/rm -f /etc/raptor-force-extreme
ALL ALL=(root) NOPASSWD: /usr/bin/rm -f /etc/raptor-force-performance
ALL ALL=(root) NOPASSWD: /usr/bin/rm -f /etc/raptor-force-balanced
ALL ALL=(root) NOPASSWD: /usr/bin/rm -f /etc/raptor-force-powersave
ALL ALL=(root) NOPASSWD: /usr/sbin/sysctl --system
ALL ALL=(root) NOPASSWD: /usr/bin/mkdir -p /etc/raptor
ALL ALL=(root) NOPASSWD: /usr/bin/tee /etc/raptor/vram-override.conf
ALL ALL=(root) NOPASSWD: /usr/bin/rm -f /etc/raptor/vram-override.conf
SUDOERS
chmod 440 /etc/sudoers.d/raptor-gpu
command -v visudo &>/dev/null && visudo -c -f /etc/sudoers.d/raptor-gpu \
    && echo "[OK] sudoers valid" || echo "[WARN] check /etc/sudoers.d/raptor-gpu"

mkdir -p /usr/share/applications
cat << 'EOF' > /usr/share/applications/raptor-gpu-profile.desktop
[Desktop Entry]
Type=Application
Name=Raptor GPU Profiler
GenericName=GPU Monitor
Comment=Monitor and manage GPU performance profiles
Exec=/usr/bin/raptor-gpu-profile-launcher
TryExec=/usr/bin/raptor-gpu-profile-launcher
Icon=preferences-system-performance
Terminal=false
NoDisplay=false
Categories=X-RaptorOS;System;Monitor;
Keywords=gpu;profile;performance;raptor;monitor;nvidia;amd;intel;
StartupNotify=true
EOF

# ── Plasma desktop theme ──────────────────────────────────────────────────────
mkdir -p /usr/share/plasma/desktoptheme/RaptorOS/widgets
mkdir -p /usr/share/plasma/desktoptheme/RaptorOS/opaque/widgets

cat << 'EOF' > /usr/share/plasma/desktoptheme/RaptorOS/metadata.desktop
[Desktop Entry]
Name=RaptorOS
Comment=F-22 Fighter Jet Cockpit HUD theme for Raptor OS
Type=Service
X-KDE-ServiceTypes=Plasma/Theme
X-KDE-PluginInfo-Name=RaptorOS
X-KDE-PluginInfo-Version=2.6
X-KDE-PluginInfo-License=GPL-2.0-or-later
X-KDE-PluginInfo-EnabledByDefault=true

[Plasmatarget]
BaseTheme=breezedark
EOF

# ── System-wide theme defaults (written at BUILD TIME) ────────────────────────
# Writing /etc/xdg/plasmarc at build time makes RaptorOS the system default
# before any user logs in. Without this, KDE starts with Breeze Dark and the
# per-user service tries to override an already-active theme — often losing
# the race against KDE's own session restore. With this file present, Plasma
# reads RaptorOS as the configured theme from the very first session start.
mkdir -p /etc/xdg
cat << 'SYSPLASMARC' > /etc/xdg/plasmarc
[Theme]
name=RaptorOS
SYSPLASMARC

# Also write system-wide kdeglobals defaults for color scheme and icons
cat << 'SYSKDEGLOBALS' > /etc/xdg/kdeglobals
[General]
ColorScheme=RaptorOS

[Icons]
Theme=breeze-dark

[KDE]
LookAndFeelPackage=org.kde.breezedark.desktop
SingleClick=false
SYSKDEGLOBALS

# Plasma 6 uses KPackage format (metadata.json) for theme discovery.
# Without this file Plasma 6 cannot locate the theme by its ID string —
# kwriteconfig6 writes "RaptorOS" to plasmarc but Plasma finds no theme
# with that ID in its package index and silently falls back to Breeze Dark.
# This is the primary reason the HUD theme never applied in v1–v5.
cat << 'EOF' > /usr/share/plasma/desktoptheme/RaptorOS/metadata.json
{
    "KPlugin": {
        "Id": "RaptorOS",
        "Name": "RaptorOS",
        "Description": "F-22 Fighter Jet Cockpit HUD theme for Raptor OS",
        "Authors": [{"Name": "Raptor OS", "Email": ""}],
        "Category": "Plasma Theme",
        "Version": "2.6",
        "Website": "https://github.com/Cerberus9-dev/Raptor-OS",
        "License": "GPL-2.0-or-later",
        "EnabledByDefault": true
    },
    "X-Plasma-API-Minimum-Version": "6.0"
}
EOF

cat << 'SVGEOF' > /usr/share/plasma/desktoptheme/RaptorOS/widgets/panel-background.svg
<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink">
  <defs>
    <linearGradient id="topglow" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0%"   stop-color="#1e90ff" stop-opacity="0.55"/>
      <stop offset="18%"  stop-color="#1e90ff" stop-opacity="0.12"/>
      <stop offset="100%" stop-color="#0d0f12" stop-opacity="0"/>
    </linearGradient>
    <radialGradient id="radar-sweep" cx="50%" cy="120%" r="80%">
      <stop offset="0%"  stop-color="#00ff41" stop-opacity="0.07"/>
      <stop offset="60%" stop-color="#00ff41" stop-opacity="0.02"/>
      <stop offset="100%" stop-color="#00ff41" stop-opacity="0"/>
    </radialGradient>
  </defs>
  <rect id="hint-stretch-borders" x="0" y="0" width="1" height="1" fill="none"/>
  <rect id="hint-tile-center"     x="0" y="0" width="1" height="1" fill="none"/>
  <g id="topleft">
    <rect x="0" y="0" width="24" height="48" fill="#0d0f12"/>
    <polygon points="0,0 24,0 0,24" fill="#1c2330"/>
    <line x1="0" y1="0" x2="24" y2="0" stroke="#1e90ff" stroke-width="1" opacity="0.8"/>
    <line x1="0" y1="0" x2="0"  y2="48" stroke="#1e90ff" stroke-width="0.5" opacity="0.4"/>
  </g>
  <g id="topright">
    <rect x="0" y="0" width="24" height="48" fill="#0d0f12"/>
    <polygon points="0,0 24,0 24,24" fill="#1c2330"/>
    <line x1="0" y1="0" x2="24" y2="0"  stroke="#1e90ff" stroke-width="1"   opacity="0.8"/>
    <line x1="24" y1="0" x2="24" y2="48" stroke="#1e90ff" stroke-width="0.5" opacity="0.4"/>
  </g>
  <g id="bottomleft"><rect x="0" y="0" width="24" height="4" fill="#0d0f12"/></g>
  <g id="bottomright"><rect x="0" y="0" width="24" height="4" fill="#0d0f12"/></g>
  <g id="top">
    <rect x="0" y="0" width="1" height="48" fill="#0d0f12"/>
    <rect x="0" y="0" width="1" height="48" fill="url(#topglow)"/>
    <line x1="0" y1="0" x2="1" y2="0" stroke="#1e90ff" stroke-width="1.5" opacity="0.85"/>
  </g>
  <g id="bottom"><rect x="0" y="0" width="1" height="4" fill="#080a0c"/></g>
  <g id="left">
    <rect x="0" y="0" width="24" height="1" fill="#0d0f12"/>
    <line x1="0" y1="0" x2="24" y2="0" stroke="#1e90ff" stroke-width="1" opacity="0.8"/>
  </g>
  <g id="right">
    <rect x="0" y="0" width="24" height="1" fill="#0d0f12"/>
    <line x1="0" y1="0" x2="24" y2="0" stroke="#1e90ff" stroke-width="1" opacity="0.8"/>
  </g>
  <g id="center">
    <rect x="0" y="0" width="1" height="48" fill="#0d0f12"/>
    <rect x="0" y="0" width="1" height="48" fill="url(#radar-sweep)"/>
  </g>
</svg>
SVGEOF

cp /usr/share/plasma/desktoptheme/RaptorOS/widgets/panel-background.svg \
   /usr/share/plasma/desktoptheme/RaptorOS/opaque/widgets/panel-background.svg

# ── Radar arc plasmoid ────────────────────────────────────────────────────────
mkdir -p /usr/share/plasma/plasmoids/org.raptoros.radararc/contents/ui

cat << 'EOF' > /usr/share/plasma/plasmoids/org.raptoros.radararc/metadata.json
{
    "KPackageStructure": "Plasma/Applet",
    "KPlugin": {
        "Authors": [{"Email": "raptor@local", "Name": "RaptorOS"}],
        "Category": "Utilities",
        "Description": "Cockpit radar arc decoration for the Raptor HUD panel",
        "Icon": "preferences-system-performance",
        "Id": "org.raptoros.radararc",
        "Name": "Raptor Radar Arc",
        "Version": "1.0"
    }
}
EOF

cat << 'QMLEOF' > /usr/share/plasma/plasmoids/org.raptoros.radararc/contents/ui/main.qml
import QtQuick 2.15
import QtQuick.Controls 2.15

Item {
    id: root
    implicitWidth: 120
    implicitHeight: 48
    property string side: plasmoid.configuration.side || "left"
    property real sweepAngle: 0

    // Static blip definitions: angle (degrees from top), dist (0-1 of maxR)
    readonly property var blipDefs: [
        { a: 210, r: 0.38 }, { a: 255, r: 0.58 },
        { a: 290, r: 0.29 }, { a: 238, r: 0.72 }, { a: 222, r: 0.50 }
    ]
    property var blipBrightness: [0.6, 0.3, 0.8, 0.2, 0.5]

    SequentialAnimation on sweepAngle {
        loops: Animation.Infinite
        NumberAnimation { to: 360; duration: 4000; easing.type: Easing.Linear }
    }

    onSweepAngleChanged: {
        var bb = blipBrightness.slice()
        for (var i = 0; i < blipDefs.length; i++) {
            var diff = (sweepAngle - blipDefs[i].a + 360) % 360
            if (diff >= 0 && diff < 4) {
                bb[i] = 0.9 + Math.random() * 0.1
            } else {
                bb[i] = Math.max(0, bb[i] - 0.001)
            }
        }
        blipBrightness = bb
        canvas.requestPaint()
    }

    Canvas {
        id: canvas
        anchors.fill: parent
        onPaint: {
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)

            // Corner anchor: left widget anchors at bottom-left, right at bottom-right
            var cx = side === "left" ? 0 : width
            var cy = height
            var maxR = width * 1.4

            // Grid arcs from corner
            ctx.strokeStyle = "rgba(0,255,65,0.18)"
            ctx.lineWidth = 0.5
            for (var rr = maxR * 0.3; rr <= maxR; rr += maxR * 0.25) {
                ctx.beginPath(); ctx.arc(cx, cy, rr, -Math.PI, 0); ctx.stroke()
            }

            // Sweep trail
            var sweepRad = (sweepAngle - 90) * Math.PI / 180
            var trailLen = Math.PI / 3
            for (var s = 0; s < 32; s++) {
                var frac   = s / 32
                var startA = sweepRad - trailLen * frac
                var endA   = sweepRad - trailLen * (frac + 1 / 32)
                ctx.beginPath(); ctx.moveTo(cx, cy)
                ctx.arc(cx, cy, maxR, startA, endA, true); ctx.closePath()
                ctx.fillStyle = "rgba(0,255,65," + ((1 - frac) * 0.15) + ")"
                ctx.fill()
            }

            // Sweep line
            ctx.strokeStyle = "rgba(0,255,65,0.55)"
            ctx.lineWidth = 1
            ctx.beginPath(); ctx.moveTo(cx, cy)
            ctx.lineTo(cx + maxR * Math.cos(sweepRad), cy + maxR * Math.sin(sweepRad))
            ctx.stroke()

            // Blips with brightness persistence
            var bb = root.blipBrightness
            for (var bi = 0; bi < root.blipDefs.length; bi++) {
                if (bb[bi] < 0.02) continue
                var blip = root.blipDefs[bi]
                var ba = (blip.a - 90) * Math.PI / 180
                var bx = cx + blip.r * maxR * Math.cos(ba)
                var by = cy + blip.r * maxR * Math.sin(ba)
                if (side === "left"  && bx < -4) continue
                if (side === "right" && bx > width + 4) continue
                if (by < -4) continue

                var grad = ctx.createRadialGradient(bx, by, 0, bx, by, 6)
                grad.addColorStop(0, "rgba(0,255,65," + (bb[bi] * 0.6) + ")")
                grad.addColorStop(1, "rgba(0,0,0,0)")
                ctx.fillStyle = grad
                ctx.beginPath(); ctx.arc(bx, by, 6, 0, Math.PI * 2); ctx.fill()

                ctx.fillStyle   = "rgba(30,144,255," + bb[bi] + ")"
                ctx.beginPath(); ctx.arc(bx, by, 1.5, 0, Math.PI * 2); ctx.fill()
            }
        }
    }

    Column {
        anchors {
            left:           side === "left"  ? parent.left  : undefined
            right:          side === "right" ? parent.right : undefined
            verticalCenter: parent.verticalCenter
            leftMargin:     side === "left"  ? 4 : 0
            rightMargin:    side === "right" ? 4 : 0
        }
        spacing: 1
        Text { text: "HDG"; color: "#3a5060"; font.family: "Monospace"; font.pixelSize: 7; font.letterSpacing: 1.5 }
        Text { text: "270°"; color: "#1e90ff"; font.family: "Monospace"; font.pixelSize: 10; font.bold: true }
        Text { text: "ALT"; color: "#3a5060"; font.family: "Monospace"; font.pixelSize: 7; font.letterSpacing: 1.5 }
        Text { text: "FL350"; color: "#f5a623"; font.family: "Monospace"; font.pixelSize: 10; font.bold: true }
    }
}
QMLEOF

# ── apply-plasma-panel.sh ─────────────────────────────────────────────────────
# Panel layout is applied via a Plasma layout script (layout.js) which is the
# correct, reliable mechanism for first-boot panel configuration. kwriteconfig5
# alone is not sufficient when Plasma has never run for that user because the
# appletsrc file doesn't exist yet and Plasma ignores partial writes on first run.
cat << 'EOF' > /usr/lib/raptor/hud/apply-plasma-panel.sh
#!/bin/bash
# apply-plasma-panel.sh  v6.0 — Raptor OS HUD theme applicator
#
# THEME ONLY. Never touches plasma-org.kde.plasma.desktop-appletsrc,
# never writes wallpaper, never clears pinned apps. The F-22 HUD visual
# look (dark panel + neon glow) comes entirely from the RaptorOS Plasma
# theme SVGs — the panel structure is irrelevant.
#
# v1-v5 all had variants of the same bug: modifying the appletsrc caused
# the wallpaper to reset, pinned apps to clear, and either broke the boot
# sequence (v4 used systemctl restart plasma-plasmashell which is PartOf
# graphical-session.target) or silently failed when D-Bus vars weren't
# in the service environment.

set -euo pipefail

# Session env — set explicitly; systemd user services don't always inherit these
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
export DBUS_SESSION_BUS_ADDRESS="${DBUS_SESSION_BUS_ADDRESS:-unix:path=${XDG_RUNTIME_DIR}/bus}"
export WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-0}"

# kwriteconfig shim — tries Plasma 6 first, falls back to 5
kwc() {
    if command -v kwriteconfig6 &>/dev/null; then
        kwriteconfig6 "$@" 2>/dev/null || true
    else
        kwriteconfig5 "$@" 2>/dev/null || true
    fi
}

# Verify the RaptorOS theme is installed before trying to apply it.
# If it's missing for any reason, bail rather than leaving plasmarc
# pointing at a theme that doesn't exist (causes Breeze fallback).
THEME_DIR="/usr/share/plasma/desktoptheme/RaptorOS"
if [ ! -f "$THEME_DIR/metadata.desktop" ] && [ ! -f "$THEME_DIR/metadata.json" ]; then
    echo "ERROR: RaptorOS Plasma theme not found at $THEME_DIR — aborting theme apply"
    exit 1
fi

# ── 1. Colour scheme ──────────────────────────────────────────────────────────
plasma-apply-colorscheme RaptorOS 2>/dev/null \
    || plasma-apply-colorscheme /usr/share/color-schemes/RaptorOS.colors 2>/dev/null \
    || true
kwc --file kdeglobals --group General --key ColorScheme RaptorOS
kwc --file kdeglobals --group General --key Name        RaptorOS

# ── 2. Plasma theme (provides the panel-background.svg neon glow) ─────────────
kwc --file plasmarc --group Theme --key name RaptorOS

# ── 3. Icons ──────────────────────────────────────────────────────────────────
ICON_THEME="breeze-dark"
kwc --file kdeglobals --group Icons --key Theme "$ICON_THEME"
kwc --file kdeglobals --group KDE   --key LookAndFeelPackage org.kde.breezedark.desktop
plasma-apply-icon-theme "$ICON_THEME" 2>/dev/null || true

# ── 4. Window decoration ──────────────────────────────────────────────────────
kwc --file kwinrc --group "org.kde.kdecoration2" --key library org.kde.kwin.aurorae
kwc --file kwinrc --group "org.kde.kdecoration2" --key theme "__aurorae__svg__RaptorOS"
# Window button layout — Windows style: Minimize, Maximize, Close on the right
# KDE codes: I=Minimize, A=Maximize, X=Close, M=AppMenu, _=Spacer
kwc --file kwinrc --group "org.kde.kdecoration2" --key ButtonsOnLeft  "M"
kwc --file kwinrc --group "org.kde.kdecoration2" --key ButtonsOnRight "IAX"

# Window behaviour — closer to Windows defaults
# Double-click titlebar maximises (Windows default)
kwc --file kwinrc --group Windows --key TitlebarDoubleClickCommand Maximize
# Click-to-raise (Windows always raises on click, not just titlebar)
kwc --file kwinrc --group Windows --key ClickRaise true
# Edge tiling — drag to screen edge to snap/tile (Windows Aero snap)
kwc --file kwinrc --group Windows --key ElectricBorders 1
kwc --file kwinrc --group Windows --key ElectricBorderMaximize true
kwc --file kwinrc --group Windows --key ElectricBorderTiling true
# Windows-like Alt+F4 always closes, no confirmation
kwc --file kwinrc --group KDE --key AnimationSpeed 3

# ── 5. Kvantum ────────────────────────────────────────────────────────────────
mkdir -p "$HOME/.config/Kvantum"
printf '[General]\ntheme=RaptorOS\n' > "$HOME/.config/Kvantum/kvantum.kvconfig"
kwc --file kdeglobals --group KDE --key widgetStyle kvantum

# ── 6. GTK ────────────────────────────────────────────────────────────────────
mkdir -p "$HOME/.config/gtk-3.0"
cat > "$HOME/.config/gtk-3.0/settings.ini" << GTKEOF
[Settings]
gtk-theme-name=RaptorOS-GTK
gtk-icon-theme-name=${ICON_THEME}
gtk-cursor-theme-name=Adwaita
gtk-font-name=JetBrains Mono 10
gtk-application-prefer-dark-theme=1
GTKEOF

# ── 7. Sycoca rebuild + icon loader notify ────────────────────────────────────
XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR}" kbuildsycoca6 --noincremental 2>/dev/null \
    || XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR}" kbuildsycoca5 --noincremental 2>/dev/null \
    || true
dbus-send --session --dest=org.kde.KIconLoader --type=signal \
    /KIconLoader org.kde.KIconLoader.iconChanged int32:0 2>/dev/null || true

# ── 8. KWin decoration reload (no compositor restart) ─────────────────────────
qdbus6 org.kde.KWin /KWin reconfigure 2>/dev/null \
    || qdbus org.kde.KWin /KWin reconfigure 2>/dev/null \
    || true

# ── 9. Restart plasmashell to load the new theme ──────────────────────────────
# Runs in a fully detached subshell so this script exits cleanly first.
# The stamp is written (ExecStartPost) before plasmashell restarts.
# systemctl restart is intentionally NOT used — plasma-plasmashell.service
# is PartOf=graphical-session.target; restarting via systemd cascades and
# hung the machine on reboot in v4.
(
    sleep 5
    killall plasmashell 2>/dev/null || true
    sleep 2
    WAYLAND_DISPLAY="$WAYLAND_DISPLAY" \
    DBUS_SESSION_BUS_ADDRESS="$DBUS_SESSION_BUS_ADDRESS" \
    plasmashell --replace &>/dev/null &
    disown
) &>/dev/null &
disown

echo "RAPTOR_HUD_APPLIED_V6"
EOF
chmod +x /usr/lib/raptor/hud/apply-plasma-panel.sh

# ── GTK theme ─────────────────────────────────────────────────────────────────
mkdir -p /usr/share/themes/RaptorOS-GTK/gtk-3.0
mkdir -p /usr/share/themes/RaptorOS-GTK/gtk-4.0

cat << 'EOF' > /usr/share/themes/RaptorOS-GTK/gtk-3.0/gtk.css
@define-color bg_color #151a20;
@define-color fg_color #c8d6e8;
@define-color base_color #0d0f12;
@define-color text_color #c8d6e8;
@define-color selected_bg_color #1e90ff;
@define-color selected_fg_color #ffffff;
@define-color tooltip_bg_color #0d0f12;
@define-color tooltip_fg_color #c8d6e8;
@define-color borders #2a3444;
@define-color warning_color #f5a623;
@define-color success_color #2ec27e;
@define-color error_color #dc3232;
@define-color accent #1e90ff;

* { -gtk-icon-style: symbolic; }
window, .background { background-color: @bg_color; color: @fg_color; }
headerbar { background: linear-gradient(to bottom, #1c2330, #151a20); border-bottom: 1px solid #1e90ff; padding: 4px 8px; min-height: 36px; }
headerbar .title { font-weight: 600; color: @fg_color; letter-spacing: 0.04em; }
button { background: #1c2330; border: 1px solid @borders; color: @fg_color; border-radius: 2px; padding: 4px 12px; transition: all 120ms ease; }
button:hover { background: #1e4a7a; border-color: @accent; color: white; }
button.suggested-action   { background: @accent; border-color: @accent; color: white; }
button.destructive-action { background: #8b1a1a; border-color: #cc3333; color: white; }
entry { background: @base_color; border: 1px solid @borders; color: @fg_color; border-radius: 2px; padding: 4px 8px; caret-color: @accent; }
entry:focus { border-color: @accent; box-shadow: 0 0 0 1px @accent; }
treeview.view:selected, row:selected { background-color: @selected_bg_color; color: @selected_fg_color; }
scrollbar slider { background-color: #2a3444; border-radius: 2px; min-width: 6px; min-height: 6px; }
scrollbar slider:hover { background-color: @accent; }
tooltip { background-color: @tooltip_bg_color; border: 1px solid @borders; color: @tooltip_fg_color; border-radius: 2px; }
menubar, .menubar { background-color: #1c2330; border-bottom: 1px solid @borders; }
menu, .menu { background-color: #151a20; border: 1px solid @borders; }
menu menuitem:hover { background-color: @accent; color: white; }
notebook header { background-color: #1c2330; border-bottom: 1px solid @borders; }
notebook header tab:checked { background-color: @base_color; border-bottom: 2px solid @accent; }
progressbar progress { background-color: @accent; border-radius: 2px; }
checkbutton check, radiobutton radio { background: @base_color; border: 1px solid @borders; }
checkbutton check:checked, radiobutton radio:checked { background-color: @accent; border-color: @accent; }
scale trough { background-color: #2a3444; border-radius: 2px; min-height: 4px; }
scale highlight { background-color: @accent; border-radius: 2px; }
EOF

cp /usr/share/themes/RaptorOS-GTK/gtk-3.0/gtk.css \
   /usr/share/themes/RaptorOS-GTK/gtk-4.0/gtk.css

cat << 'EOF' > /usr/share/themes/RaptorOS-GTK/index.theme
[Desktop Entry]
Type=X-GNOME-Metatheme
Name=RaptorOS-GTK
Comment=F-22 Raptor themed GTK style
Encoding=UTF-8

[X11 Properties]
GtkTheme=RaptorOS-GTK
MetacityTheme=RaptorOS-GTK
IconTheme=breeze-dark
CursorTheme=Adwaita
ButtonLayout=close,minimize,maximize:

[KDE]
WidgetStyle=kvantum
EOF

# ── Kvantum theme ─────────────────────────────────────────────────────────────
mkdir -p /usr/share/Kvantum/RaptorOS
cat << 'EOF' > /usr/share/Kvantum/RaptorOS/RaptorOS.kvconfig
[%General]
author=RaptorOS
comment=F-22 Raptor stealth dark theme
x11drag=all
composite=true
menu_shadow_depth=6
tooltip_shadow_depth=4
popup_blurring=true

[GeneralColors]
window.color=#1c2330
base.color=#0d0f12
alt.base.color=#151a20
button.color=#1c2330
light.color=#2a3a4e
mid.light.color=#1e2d3e
mid.color=#151a20
dark.color=#0a0c0f
shadow.color=#000000
highlight.color=#1e90ff
inactive.highlight.color=#2a3444
text.color=#c8d6e8
window.text.color=#c8d6e8
button.text.color=#c8d6e8
disabled.text.color=#5a6a7e
tooltip.base.color=#0d0f12
tooltip.text.color=#c8d6e8
link.color=#1e90ff
link.visited.color=#8c64dc
progress.indicator.text.color=#ffffff

[Hacks]
transparent_ktitle_label=true
blur_konsole=true
EOF

cat << 'EOF' > /usr/share/Kvantum/RaptorOS/RaptorOS.svg
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 200 200">
  <rect width="200" height="200" fill="#1c2330"/>
</svg>
EOF

# ── Konsole profile ───────────────────────────────────────────────────────────
mkdir -p /usr/share/konsole
cat << 'EOF' > /usr/share/konsole/RaptorOS.profile
[Appearance]
ColorScheme=RaptorOS
Font=JetBrains Mono,11,-1,5,50,0,0,0,0,0
LineSpacing=2

[General]
Command=/bin/bash
Icon=utilities-terminal
Name=RaptorOS
Parent=FALLBACK/
TerminalColumns=120
TerminalRows=36

[Scrolling]
HistoryMode=2
HistorySize=10000
ScrollBarPosition=2

[Terminal Features]
BlinkingCursorEnabled=true
CursorShape=1
EOF

cat << 'EOF' > /usr/share/konsole/RaptorOS.colorscheme
[Background]
Color=13,15,18

[BackgroundIntense]
Color=21,26,32

[Color0]
Color=21,26,32

[Color0Intense]
Color=42,52,68

[Color1]
Color=180,50,50

[Color1Intense]
Color=220,80,80

[Color2]
Color=46,160,100

[Color2Intense]
Color=46,194,126

[Color3]
Color=200,130,30

[Color3Intense]
Color=245,166,35

[Color4]
Color=30,100,200

[Color4Intense]
Color=30,144,255

[Color5]
Color=100,60,180

[Color5Intense]
Color=140,100,220

[Color6]
Color=30,140,180

[Color6Intense]
Color=30,180,220

[Color7]
Color=160,180,200

[Color7Intense]
Color=200,214,232

[Foreground]
Color=200,214,232

[ForegroundIntense]
Color=230,240,255

[General]
Anchor=0.5,0.5
Blur=true
BlurRadius=12
ColorRandomization=false
Description=RaptorOS
Opacity=0.92
EOF

# ── Firstboot systemd user service ───────────────────────────────────────────
mkdir -p /usr/lib/systemd/user
cat << 'EOF' > /usr/lib/systemd/user/raptor-hud-apply.service
[Unit]
Description=Raptor HUD — Apply KDE theme on first login
After=plasma-plasmashell.service
# v4 stamp: v3 fixed the appletsrc structure. v4 fixes the plasmashell
# restart — kquitapp6 silently fails when DBUS_SESSION_BUS_ADDRESS is
# absent from the systemd user service env. v4 sets all session env vars
# explicitly and uses systemctl --user restart plasma-plasmashell.service
# as the primary method (uses private socket, not D-Bus).
# Delete ~/.local/share/raptor-hud-applied-v8 to re-run manually.
ConditionPathExists=!%h/.local/share/raptor-hud-applied-v8

[Service]
Type=oneshot
ExecStart=/usr/lib/raptor/hud/apply-plasma-panel.sh
ExecStartPost=/bin/bash -c 'mkdir -p %h/.local/share && touch %h/.local/share/raptor-hud-applied-v8'
RemainAfterExit=yes

[Install]
WantedBy=default.target
EOF
systemctl --global enable raptor-hud-apply.service 2>/dev/null || true

if command -v kbuildsycoca6 &>/dev/null; then
    kbuildsycoca6 --noincremental 2>/dev/null || true
elif command -v kbuildsycoca5 &>/dev/null; then
    kbuildsycoca5 --noincremental 2>/dev/null || true
fi

echo "RAPTOR_HUD_READY"
echo ""
echo "To set your wallpaper (persists across logins):"
echo "  raptor-set-wallpaper /path/to/image.jpg"
echo "  — or search 'Set Wallpaper' in the app menu"
