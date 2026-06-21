#!/bin/bash
set -oue pipefail

# =============================================================================
# Raptor OS — GPU Profile Detection & Configuration  v3.0
#
# BUILD-TIME: writes static config files, the runtime detection script,
#             and the systemd service that runs it on boot.
#
# RUNTIME:    /usr/lib/raptor/gpu-detect.sh runs via raptor-gpu-profile.service
#             after sysinit, where lspci/sysfs/kernel modules are available.
# =============================================================================

mkdir -p /etc/environment.d \
         /etc/sysctl.d \
         /usr/lib/raptor \
         /usr/lib/systemd/system \
         /etc/polkit-1/rules.d \
         /etc/sudoers.d \
         /etc/raptor

# ── Fallback env file (overwritten at runtime by gpu-detect.sh) ───────────────
cat << 'ENVEOF' > /etc/environment.d/raptor-gpu.conf
# Raptor OS: GPU profile — applied at boot by raptor-gpu-profile.service.
# This file is the safe fallback written at image build time.
# It will be replaced on first boot once the GPU is detected.
MESA_SHADER_CACHE_DISABLE=false
WINE_LARGE_ADDRESS_AWARE=1
PROTON_FORCE_LARGE_ADDRESS_AWARE=1
# WINE_FULLSCREEN_FSR and DXVK_ASYNC are intentionally NOT set globally.
# They cause flickering/lighting glitches in OpenGL games like Project Zomboid.
# Set per-game in Steam: right-click game → Properties → Launch Options:
#   WINE_FULLSCREEN_FSR=1 DXVK_ASYNC=1 %command%
STAGING_SHARED_MEMORY=1
PROTON_NO_ESYNC=0
PROTON_NO_FSYNC=0
ENVEOF

# ── Gaming sysctl (static — safe to write at build time) ─────────────────────
cat << 'SYSCTL' > /etc/sysctl.d/raptor-gaming.conf
# ── Raptor OS Gaming sysctl ──────────────────────────────────────────────────
kernel.sched_autogroup_enabled=1
kernel.sched_min_granularity_ns=500000
kernel.sched_wakeup_granularity_ns=1000000
kernel.sched_migration_cost_ns=250000
fs.inotify.max_user_watches=524288
fs.inotify.max_user_instances=256
vm.swappiness=10
vm.dirty_ratio=15
vm.dirty_background_ratio=5
kernel.split_lock_mitigate=0
SYSCTL

# ── Runtime detection + apply script ─────────────────────────────────────────
cat << 'DETECT' > /usr/lib/raptor/gpu-detect.sh
#!/bin/bash
set -euo pipefail

# ── GPU detection (runs at boot where lspci/sysfs are available) ──────────────
GPU_VENDOR="unknown"
GPU_MODEL=""

if lspci 2>/dev/null | grep -i "VGA\|3D\|Display" | grep -qi "nvidia"; then
    GPU_VENDOR="nvidia"
    GPU_MODEL=$(lspci | grep -i "VGA\|3D\|Display" | grep -i "nvidia" \
        | sed 's/.*\[//;s/\].*//' | head -1)
elif lspci 2>/dev/null | grep -i "VGA\|3D\|Display" | grep -qi "amd\|radeon\|ati"; then
    GPU_VENDOR="amd"
    GPU_MODEL=$(lspci | grep -i "VGA\|3D\|Display" | grep -i "amd\|radeon\|ati" \
        | sed 's/.*\[//;s/\].*//' | head -1)
elif lspci 2>/dev/null | grep -i "VGA\|3D\|Display" | grep -qi "intel"; then
    GPU_VENDOR="intel"
    GPU_MODEL=$(lspci | grep -i "VGA\|3D\|Display" | grep -i "intel" \
        | sed 's/.*\[//;s/\].*//' | head -1)
fi
echo "Detected GPU vendor: $GPU_VENDOR  model: ${GPU_MODEL:-unknown}"

# ── iGPU / hybrid detection ───────────────────────────────────────────────────
IS_IGPU=false
IS_HYBRID=false

if lspci 2>/dev/null | grep -i "VGA\|3D\|Display" | grep -qi "intel"; then
    IS_IGPU=true
fi
if lspci -v 2>/dev/null | grep -i "VGA\|3D\|Display" -A5 | grep -qi \
    "subsystem.*apu\|integrated\|cezanne\|renoir\|lucienne\|rembrandt\|mendocino\|phoenix\|hawk point"; then
    IS_IGPU=true
fi
DISPLAY_DEVS=$(lspci 2>/dev/null | grep -ic "VGA\|3D\|Display" || echo 0)
if [ "$DISPLAY_DEVS" -ge 2 ]; then
    IS_HYBRID=true
fi

# ── Active profile flag ───────────────────────────────────────────────────────
PROFILE="auto"
[ -f /etc/raptor-force-extreme ]     && PROFILE="extreme"
[ -f /etc/raptor-force-performance ] && PROFILE="performance"
[ -f /etc/raptor-force-powersave ]   && PROFILE="powersave"
[ -f /etc/raptor-force-balanced ]    && PROFILE="balanced"
echo "Active profile: $PROFILE"

# ── Common env vars ───────────────────────────────────────────────────────────
COMMON_VARS="WINE_LARGE_ADDRESS_AWARE=1
PROTON_FORCE_LARGE_ADDRESS_AWARE=1
# WINE_FULLSCREEN_FSR and DXVK_ASYNC are intentionally NOT set globally.
# They cause flickering/lighting glitches in OpenGL games like Project Zomboid.
# Set per-game in Steam: right-click game → Properties → Launch Options:
#   WINE_FULLSCREEN_FSR=1 DXVK_ASYNC=1 %command%
STAGING_SHARED_MEMORY=1
PROTON_NO_ESYNC=0
PROTON_NO_FSYNC=0"

# ── Profile → env file ────────────────────────────────────────────────────────
case "$PROFILE" in

  extreme)
    cat << ENVEOF > /etc/environment.d/raptor-gpu.conf
# ── Raptor OS: EXTREME PERFORMANCE profile ───────────────────────────────────
AMD_VULKAN_ICD=RADV
MESA_SHADER_CACHE_DISABLE=false
MESA_SHADER_CACHE_MAX_SIZE=4G
__GL_SHADER_DISK_CACHE=1
__GL_SHADER_DISK_CACHE_SKIP_CLEANUP=1
__GL_THREADED_OPTIMIZATIONS=1
AMDGPU_HIGH_POWER=1
PROTON_ENABLE_NVAPI=1
# DXVK_ASYNC=1  ← set per-game, not globally (causes shader flicker)
DXVK_FRAME_RATE=0
VKD3D_CONFIG=dxr11,dxr
VKD3D_FEATURE_LEVEL=12_2
$COMMON_VARS
ENVEOF
    if [ "$GPU_VENDOR" = "amd" ]; then
        for f in /sys/class/drm/card*/device/power_dpm_force_performance_level; do
            echo "high" > "$f" 2>/dev/null || true
        done
        for f in /sys/class/drm/card*/device/pp_power_profile_mode; do
            echo 1 > "$f" 2>/dev/null || true
        done
    fi
    if [ "$GPU_VENDOR" = "nvidia" ]; then
        nvidia-smi -pm 1 > /dev/null 2>&1 || true
        nvidia-smi --auto-boost-default=0 > /dev/null 2>&1 || true
    fi
    ;;

  performance)
    cat << ENVEOF > /etc/environment.d/raptor-gpu.conf
# ── Raptor OS: MAX PERFORMANCE profile ───────────────────────────────────────
AMD_VULKAN_ICD=RADV
MESA_SHADER_CACHE_DISABLE=false
MESA_SHADER_CACHE_MAX_SIZE=2G
__GL_SHADER_DISK_CACHE=1
__GL_SHADER_DISK_CACHE_SKIP_CLEANUP=1
__GL_THREADED_OPTIMIZATIONS=1
PROTON_ENABLE_NVAPI=1
# DXVK_ASYNC=1  ← set per-game, not globally (causes shader flicker)
VKD3D_CONFIG=dxr11
VKD3D_FEATURE_LEVEL=12_1
$COMMON_VARS
ENVEOF
    if [ "$GPU_VENDOR" = "amd" ]; then
        for f in /sys/class/drm/card*/device/power_dpm_force_performance_level; do
            echo "high" > "$f" 2>/dev/null || true
        done
    fi
    if [ "$GPU_VENDOR" = "nvidia" ]; then
        nvidia-smi -pm 1 > /dev/null 2>&1 || true
    fi
    ;;

  balanced)
    cat << ENVEOF > /etc/environment.d/raptor-gpu.conf
# ── Raptor OS: BALANCED profile ───────────────────────────────────────────────
AMD_VULKAN_ICD=RADV
MESA_SHADER_CACHE_DISABLE=false
__GL_SHADER_DISK_CACHE=1
PROTON_ENABLE_NVAPI=1
$COMMON_VARS
ENVEOF
    if [ "$GPU_VENDOR" = "amd" ]; then
        for f in /sys/class/drm/card*/device/power_dpm_force_performance_level; do
            echo "auto" > "$f" 2>/dev/null || true
        done
    fi
    ;;

  powersave)
    cat << ENVEOF > /etc/environment.d/raptor-gpu.conf
# ── Raptor OS: POWER SAVING profile ──────────────────────────────────────────
MESA_SHADER_CACHE_DISABLE=true
$COMMON_VARS
ENVEOF
    if [ "$GPU_VENDOR" = "amd" ]; then
        for f in /sys/class/drm/card*/device/power_dpm_force_performance_level; do
            echo "low" > "$f" 2>/dev/null || true
        done
    fi
    if [ "$GPU_VENDOR" = "nvidia" ]; then
        nvidia-smi -pm 0 > /dev/null 2>&1 || true
    fi
    ;;

  auto|*)
    if [ "$GPU_VENDOR" = "nvidia" ]; then
        cat << ENVEOF > /etc/environment.d/raptor-gpu.conf
# ── Raptor OS: NVIDIA auto profile ────────────────────────────────────────────
__GL_SHADER_DISK_CACHE=1
__GL_SHADER_DISK_CACHE_SKIP_CLEANUP=1
__GL_THREADED_OPTIMIZATIONS=1
PROTON_ENABLE_NVAPI=1
# DXVK_ASYNC=1  ← set per-game, not globally (causes shader flicker)
VKD3D_CONFIG=dxr11
$COMMON_VARS
ENVEOF
    elif [ "$GPU_VENDOR" = "amd" ] && [ "$IS_IGPU" = true ]; then
        cat << ENVEOF > /etc/environment.d/raptor-gpu.conf
# ── Raptor OS: AMD iGPU auto profile ──────────────────────────────────────────
AMD_VULKAN_ICD=RADV
MESA_SHADER_CACHE_DISABLE=false
$COMMON_VARS
ENVEOF
    elif [ "$GPU_VENDOR" = "amd" ]; then
        cat << ENVEOF > /etc/environment.d/raptor-gpu.conf
# ── Raptor OS: AMD dGPU auto profile ──────────────────────────────────────────
AMD_VULKAN_ICD=RADV
MESA_SHADER_CACHE_DISABLE=false
MESA_SHADER_CACHE_MAX_SIZE=2G
__GL_SHADER_DISK_CACHE=1
# DXVK_ASYNC=1  ← set per-game, not globally (causes shader flicker)
$COMMON_VARS
ENVEOF
    elif [ "$GPU_VENDOR" = "intel" ]; then
        cat << ENVEOF > /etc/environment.d/raptor-gpu.conf
# ── Raptor OS: Intel auto profile ─────────────────────────────────────────────
MESA_LOADER_DRIVER_OVERRIDE=iris
LIBGL_DRI3_DISABLE=0
vblank_mode=0
$COMMON_VARS
ENVEOF
    else
        cat << ENVEOF > /etc/environment.d/raptor-gpu.conf
# ── Raptor OS: fallback profile ───────────────────────────────────────────────
MESA_SHADER_CACHE_DISABLE=false
$COMMON_VARS
ENVEOF
    fi
    ;;
esac

# ── CPU governor: match GPU profile ──────────────────────────────────────────
set_cpu_governor() {
    local GOV="$1"
    for f in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
        echo "$GOV" > "$f" 2>/dev/null || true
    done
    echo "CPU governor → $GOV"
}

case "$PROFILE" in
    extreme|performance) set_cpu_governor "performance" ;;
    balanced)            set_cpu_governor "schedutil"   ;;
    powersave)           set_cpu_governor "powersave"   ;;
    auto|*)              set_cpu_governor "schedutil"   ;;
esac

# ── Apply env vars to any already-running user sessions ──────────────────────
ENVFILE=/etc/environment.d/raptor-gpu.conf
if [ -f "$ENVFILE" ]; then
    LIVE_VARS=()
    while IFS= read -r line; do
        [[ "$line" =~ ^#.*$ ]] && continue
        [[ -z "$line" ]]       && continue
        LIVE_VARS+=("$line")
    done < "$ENVFILE"

    if [ ${#LIVE_VARS[@]} -gt 0 ]; then
        for uid in $(loginctl list-users --no-legend 2>/dev/null | awk '{print $1}'); do
            RUNTIME_DIR="/run/user/$uid"
            if [ -d "$RUNTIME_DIR" ]; then
                DBUS="unix:path=$RUNTIME_DIR/bus"
                # set-environment accepts KEY=VALUE pairs directly (import-environment
                # only accepts variable names already in the current env — wrong here).
                sudo -u "#$uid" \
                     DBUS_SESSION_BUS_ADDRESS="$DBUS" \
                     systemctl --user set-environment "${LIVE_VARS[@]}" \
                     2>/dev/null || true
                USER_ENVDIR="$(getent passwd "$uid" | cut -d: -f6)/.config/environment.d"
                mkdir -p "$USER_ENVDIR" 2>/dev/null || true
                cp "$ENVFILE" "$USER_ENVDIR/raptor-gpu.conf" 2>/dev/null || true
            fi
        done
    fi
fi

# ── Reload sysctl ─────────────────────────────────────────────────────────────
sysctl --system > /dev/null 2>&1 || true

echo "GPU_PROFILE_READY  profile=$PROFILE  vendor=$GPU_VENDOR  igpu=$IS_IGPU  hybrid=$IS_HYBRID"
DETECT
chmod +x /usr/lib/raptor/gpu-detect.sh

# ── systemd service (runs gpu-detect.sh at boot) ──────────────────────────────
cat << 'SVCEOF' > /usr/lib/systemd/system/raptor-gpu-profile.service
[Unit]
Description=Raptor OS — GPU Profile Detection & Configuration
After=sysinit.target
Before=display-manager.service

[Service]
Type=oneshot
ExecStart=/usr/lib/raptor/gpu-detect.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
SVCEOF

# ── polkit rule ───────────────────────────────────────────────────────────────
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

# ── sudoers drop-in ───────────────────────────────────────────────────────────
cat << 'SUDOERS' > /etc/sudoers.d/raptor-gpu
# Raptor OS: allow any user to switch GPU profiles without a password
ALL ALL=(root) NOPASSWD: /usr/lib/raptor/gpu-detect.sh
ALL ALL=(root) NOPASSWD: /usr/bin/touch /etc/raptor-force-*
ALL ALL=(root) NOPASSWD: /usr/bin/rm -f /etc/raptor-force-*
ALL ALL=(root) NOPASSWD: /usr/sbin/sysctl --system
SUDOERS
chmod 440 /etc/sudoers.d/raptor-gpu

echo "GPU_PROFILE_READY"
