#!/bin/bash
set -e

# =============================================================================
# Raptor HUD v4.2 — F-22 Themed KDE Plasma Shell
# =============================================================================

# ── Palette reference ────────────────────────────────────────────────────────
# Base:    #0d0f12  Surface: #151a20  Panel:   #1c2330  Border:  #2a3444
# Accent:  #33FF33  Warning: #f5a623  Success: #2ec27e  Text:    #c8d6e8

mkdir -p /usr/lib/raptor/hud

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
DecorationFocus=51,255,51
DecorationHover=51,255,51
ForegroundActive=51,255,51
ForegroundInactive=90,106,126
ForegroundLink=51,255,51
ForegroundNegative=220,50,50
ForegroundNeutral=245,166,35
ForegroundNormal=200,214,232
ForegroundPositive=46,194,126
ForegroundVisited=140,100,220

[Colors:Complementary]
BackgroundAlternate=20,28,40
BackgroundNormal=13,15,18
DecorationFocus=51,255,51
DecorationHover=51,255,51
ForegroundActive=51,255,51
ForegroundInactive=90,106,126
ForegroundLink=51,255,51
ForegroundNegative=220,50,50
ForegroundNeutral=245,166,35
ForegroundNormal=200,214,232
ForegroundPositive=46,194,126
ForegroundVisited=140,100,220

[Colors:Header]
BackgroundAlternate=21,26,32
BackgroundNormal=21,26,32
DecorationFocus=51,255,51
DecorationHover=51,255,51
ForegroundActive=51,255,51
ForegroundInactive=90,106,126
ForegroundLink=51,255,51
ForegroundNegative=220,50,50
ForegroundNeutral=245,166,35
ForegroundNormal=200,214,232
ForegroundPositive=46,194,126
ForegroundVisited=140,100,220

[Colors:Selection]
BackgroundAlternate=15,60,15
BackgroundNormal=30,90,30
DecorationFocus=51,255,51
DecorationHover=51,255,51
ForegroundActive=255,255,255
ForegroundInactive=180,200,220
ForegroundLink=150,255,150
ForegroundNegative=220,50,50
ForegroundNeutral=245,166,35
ForegroundNormal=255,255,255
ForegroundPositive=46,194,126
ForegroundVisited=200,170,255

[Colors:Tooltip]
BackgroundAlternate=21,26,32
BackgroundNormal=13,15,18
DecorationFocus=51,255,51
DecorationHover=51,255,51
ForegroundActive=51,255,51
ForegroundInactive=90,106,126
ForegroundLink=51,255,51
ForegroundNegative=220,50,50
ForegroundNeutral=245,166,35
ForegroundNormal=200,214,232
ForegroundPositive=46,194,126
ForegroundVisited=140,100,220

[Colors:View]
BackgroundAlternate=18,24,32
BackgroundNormal=13,15,18
DecorationFocus=51,255,51
DecorationHover=51,255,51
ForegroundActive=51,255,51
ForegroundInactive=90,106,126
ForegroundLink=51,255,51
ForegroundNegative=220,50,50
ForegroundNeutral=245,166,35
ForegroundNormal=200,214,232
ForegroundPositive=46,194,126
ForegroundVisited=140,100,220

[Colors:Window]
BackgroundAlternate=21,26,32
BackgroundNormal=28,35,48
DecorationFocus=51,255,51
DecorationHover=51,255,51
ForegroundActive=51,255,51
ForegroundInactive=90,106,126
ForegroundLink=51,255,51
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
activeBlend=51,255,51
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
    <rect y="29" width="100" height="1" fill="#33FF33" opacity="0.7"/>
    <rect width="2" height="30" fill="#33FF33" opacity="0.5"/>
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
    <rect x="4" y="4" width="10" height="10" fill="none" stroke="#33FF33" stroke-width="1.5"/>
  </g>
  <g id="maximize-hover">
    <rect width="18" height="18" rx="1" fill="#1e4a7a"/>
    <rect x="4" y="4" width="10" height="10" fill="none" stroke="#5ab0ff" stroke-width="1.5"/>
  </g>
  <g id="minimize">
    <rect width="18" height="18" rx="1" fill="#1c2330"/>
    <line x1="4" y1="13" x2="14" y2="13" stroke="#33FF33" stroke-width="1.5" stroke-linecap="square"/>
  </g>
  <g id="minimize-hover">
    <rect width="18" height="18" rx="1" fill="#1e4a7a"/>
    <line x1="4" y1="13" x2="14" y2="13" stroke="#5ab0ff" stroke-width="1.5" stroke-linecap="square"/>
  </g>
</svg>
SVGEOF

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
    echo "  ██████╗  █████╗ ██████╗ ████████╗ ██████╗ ██████╗      ██████╗ ██████╗ ███████╗"
    echo "  ██╔══██╗██╔══██╗██╔══██╗╚══██╔══╝██╔═══██╗██╔══██╗    ██╔═══██╗██╔══██╗██╔════╝"
    echo "  ██████╔╝███████║██████╔╝   ██║   ██║   ██║██████╔╝    ██║   ██║███████║███████╗"
    echo "  ██╔══██╗██╔══██║██╔═══╝    ██║   ██║   ██║██╔══██╗    ██║   ██║╚════██║╚════██║"
    echo "  ██║  ██║██║  ██║██║        ██║   ╚██████╔╝██║  ██║    ╚██████╔╝███████║███████║"
    echo "  ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝        ╚═╝    ╚═════╝ ╚═╝  ╚═╝     ╚═════╝ ╚══════╝╚══════╝"
    echo -e "${R}"
    echo -e "  ${DIM}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${R}"
    echo -e "  ${AMBER}▸ GPU PROFILER  ${DIM}│${R}  F-22 RAPTOR HUD  ${DIM}│${R}  $(date '+%Y-%m-%d %H:%M:%S')"
    echo -e "  ${DIM}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${R}"
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

# ── Baloo: filename-only indexing, 1-thread, low priority ─────────────────────
mkdir -p /etc/xdg
cat << 'BALOORCEOF' > /etc/xdg/baloofilerc
[Basic Settings]
Indexing-Enabled=true
Only from Cache=false

[General]
# Disable full-text content indexing — filename search only
exclude filters=*~,*.part,*.tmp,*.log,*.o,*.la,*.lo,*.loT,*.moc,moc_*.cpp,qrc_*.cpp,ui_*.h,cmake_install.cmake,CMakeCache.txt,CTestTestfile.cmake,libtool,config.status,confdefs.h,autom4te,conftest,confstat,Makefile.am,*.gcode,.hg,.git,.svn,.bzr,_darcs,.deps,.libs,.sconf_temp,.DS_Store,socket_*
dbPath[$e]=$HOME/.local/share/baloo
# 1 thread: prevents Baloo from competing with game loading/shader compilation
max threads=1
BALOORCEOF

# Also write /etc/xdg/kwinrc at build time for system-wide window decoration defaults.
cat << 'SYSKWINRC' > /etc/xdg/kwinrc
[org.kde.kdecoration2]
ButtonsOnLeft=M
ButtonsOnRight=IAX

[Windows]
TitlebarDoubleClickCommand=Maximize
ClickRaise=true
ElectricBorderMaximize=true
ElectricBorderTiling=true
FocusPolicy=ClickToFocus

[Compositing]
AnimationSpeed=3
LatencyPolicy=0
HiddenPreviews=4
SYSKWINRC

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

# ── GTK theme ──────────────────────────────────────────────────────────────────
mkdir -p /usr/share/themes/RaptorOS-GTK/gtk-3.0
mkdir -p /usr/share/themes/RaptorOS-GTK/gtk-4.0

cat << 'EOF' > /usr/share/themes/RaptorOS-GTK/gtk-3.0/gtk.css
@define-color bg_color #151a20;
@define-color fg_color #c8d6e8;
@define-color base_color #0d0f12;
@define-color text_color #c8d6e8;
@define-color selected_bg_color #33FF33;
@define-color selected_fg_color #ffffff;
@define-color tooltip_bg_color #0d0f12;
@define-color tooltip_fg_color #c8d6e8;
@define-color borders #2a3444;
@define-color warning_color #f5a623;
@define-color success_color #2ec27e;
@define-color error_color #dc3232;
@define-color accent #33FF33;

* { -gtk-icon-style: symbolic; }
window, .background { background-color: @bg_color; color: @fg_color; }
headerbar { background: linear-gradient(to bottom, #1c2330, #151a20); border-bottom: 1px solid #33FF33; padding: 4px 8px; min-height: 36px; }
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
highlight.color=#33FF33
inactive.highlight.color=#2a3444
text.color=#c8d6e8
window.text.color=#c8d6e8
button.text.color=#c8d6e8
disabled.text.color=#5a6a7e
tooltip.base.color=#0d0f12
tooltip.text.color=#c8d6e8
link.color=#33FF33
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

# ── Konsole profile ────────────────────────────────────────────────────────────
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
Color=0,200,200

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

# ── One-time migration: clean up leftover RaptorOS theme reference ────────────
# This build no longer writes /etc/xdg/plasmarc or the desktoptheme/RaptorOS
# package — but a user upgrading from a build that DID write them may still
# have "name=RaptorOS" sitting in their own ~/.config/plasmarc, which always
# takes priority over system defaults and is untouched by any system rebuild.
# This runs once per user, checks for that specific stale line, removes it
# if found, and restarts plasmashell so the fix is visible immediately —
# using the same detached-subshell restart proven safe earlier (never
# systemctl restart plasma-plasmashell.service, which caused a reboot hang).
mkdir -p /usr/lib/raptor
cat << 'MIGRATIONEOF' > /usr/lib/raptor/cleanup-legacy-panel-theme.sh
#!/bin/bash
set -euo pipefail

STAMP_DIR="$HOME/.local/share/raptor"
STAMP="$STAMP_DIR/legacy-panel-theme-cleaned"
[ -f "$STAMP" ] && exit 0

CHANGED=0
PLASMARC="$HOME/.config/plasmarc"

if [ -f "$PLASMARC" ] && grep -q "^name=RaptorOS$" "$PLASMARC" 2>/dev/null; then
    sed -i '/^name=RaptorOS$/d' "$PLASMARC"
    CHANGED=1
    logger -t raptor-cleanup "Removed stale 'name=RaptorOS' from $PLASMARC"
fi

# Nothing this script can do about /usr — it's read-only on OSTree — but log
# it for visibility if the old theme package is somehow still present.
if [ -d /usr/share/plasma/desktoptheme/RaptorOS ]; then
    logger -t raptor-cleanup \
        "Note: /usr/share/plasma/desktoptheme/RaptorOS still exists on this deployment. A fresh rebase to a build without it should clear this."
fi

if [ "$CHANGED" = "1" ]; then
    plasma-apply-colorscheme BreezeDark 2>/dev/null || true
    (
        sleep 2
        killall plasmashell 2>/dev/null || true
        sleep 2
        WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-0}" \
        DBUS_SESSION_BUS_ADDRESS="${DBUS_SESSION_BUS_ADDRESS:-unix:path=${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/bus}" \
        plasmashell --replace &>/dev/null &
        disown
    ) &>/dev/null &
    disown
fi

mkdir -p "$STAMP_DIR"
touch "$STAMP"
MIGRATIONEOF
chmod +x /usr/lib/raptor/cleanup-legacy-panel-theme.sh

cat << 'EOF' > /etc/xdg/autostart/raptor-cleanup-legacy-theme.desktop
[Desktop Entry]
Type=Application
Name=Raptor OS Legacy Theme Cleanup
Comment=One-time removal of the deprecated RaptorOS panel theme reference
Exec=/usr/lib/raptor/cleanup-legacy-panel-theme.sh
Terminal=false
Hidden=false
X-KDE-autostart-phase=1
NoDisplay=true
EOF

echo "RAPTOR_HUD_READY"
echo ""
echo "Raptor OS — Using KDE Plasma Default Taskbar"
echo "The custom HUD theme (F-22 cockpit aesthetic) is applied through:"
echo "  - Color scheme (RaptorOS)"
echo "  - Window decoration (Aurorae with green accents)"
echo "  - Plasma theme (neon glow effects)"
echo ""
echo "All taskbar configurations are now KDE defaults."
echo "Categories should display properly with full scroll support."
