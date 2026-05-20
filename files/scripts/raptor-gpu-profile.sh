#!/bin/bash
set -oue pipefail

# ═══════════════════════════════════════════════════════════════════════════════
# Raptor OS — GPU Profile Detection & Configuration  v2.0
# ═══════════════════════════════════════════════════════════════════════════════

# ── GPU detection ──────────────────────────────────────────────────────────────
GPU_VENDOR="unknown"
GPU_MODEL=""

if lspci | grep -i "VGA\|3D\|Display" | grep -qi "nvidia"; then
    GPU_VENDOR="nvidia"
    GPU_MODEL=$(lspci | grep -i "VGA\|3D\|Display" | grep -i "nvidia" | sed 's/.*\[//;s/\].*//' | head -1)
elif lspci | grep -i "VGA\|3D\|Display" | grep -qi "amd\|radeon\|ati"; then
    GPU_VENDOR="amd"
    GPU_MODEL=$(lspci | grep -i "VGA\|3D\|Display" | grep -i "amd\|radeon\|ati" | sed 's/.*\[//;s/\].*//' | head -1)
elif lspci | grep -i "VGA\|3D\|Display" | grep -qi "intel"; then
    GPU_VENDOR="intel"
    GPU_MODEL=$(lspci | grep -i "VGA\|3D\|Display" | grep -i "intel" | sed 's/.*\[//;s/\].*//' | head -1)
fi
echo "Detected GPU vendor: $GPU_VENDOR  model: ${GPU_MODEL:-unknown}"

# ── iGPU / dGPU detection ──────────────────────────────────────────────────────
IS_IGPU=false
IS_HYBRID=false

if lspci | grep -i "VGA\|3D\|Display" | grep -qi "intel"; then
    IS_IGPU=true
fi
if lspci -v | grep -i "VGA\|3D\|Display" -A5 | grep -qi \
    "subsystem.*apu\|integrated\|cezanne\|renoir\|lucienne\|rembrandt\|mendocino\|phoenix\|hawk point"; then
    IS_IGPU=true
fi
# Detect hybrid (iGPU + dGPU)
DISPLAY_DEVS=$(lspci | grep -ic "VGA\|3D\|Display")
if [ "$DISPLAY_DEVS" -ge 2 ]; then
    IS_HYBRID=true
fi

# ── Get total RAM for tuning ───────────────────────────────────────────────────
TOTAL_RAM_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
TOTAL_RAM_GB=$(( TOTAL_RAM_KB / 1024 / 1024 ))

# ── Read active profile flag ───────────────────────────────────────────────────
PROFILE="auto"
[ -f /etc/raptor-force-extreme ]     && PROFILE="extreme"
[ -f /etc/raptor-force-performance ] && PROFILE="performance"
[ -f /etc/raptor-force-powersave ]   && PROFILE="powersave"
[ -f /etc/raptor-force-balanced ]    && PROFILE="balanced"
echo "Active profile: $PROFILE"

# ── Gaming sysctl ──────────────────────────────────────────────────────────────
cat << SYSCTL > /etc/sysctl.d/raptor-gaming.conf
# ── Raptor OS Gaming sysctl ──────────────────────────────────────────────────
# Group tasks by session — background work won't starve the game
kernel.sched_autogroup_enabled=1

# Reduce scheduler latency for interactive/game processes
kernel.sched_min_granularity_ns=500000
kernel.sched_wakeup_granularity_ns=3000000
kernel.sched_migration_cost_ns=250000

# Increase inotify limits for large game asset directories
fs.inotify.max_user_watches=524288
fs.inotify.max_user_instances=256

# Reduce swappiness (games benefit from keeping data in RAM)
vm.swappiness=10

# Larger dirty ratio — games write logs/saves in bursts
vm.dirty_ratio=15
vm.dirty_background_ratio=5

# Split-lock detection off (some Unity builds trigger this)
kernel.split_lock_mitigate=0
SYSCTL

if [ "$PROFILE" = "extreme" ]; then
    cat << SYSCTL >> /etc/sysctl.d/raptor-gaming.conf

# ── Extreme mode extras ──────────────────────────────────────────────────────
# Huge pages for VRAM-heavy games
vm.nr_hugepages=128
# Never OOM-kill the current game session
vm.oom_kill_allocating_task=0
kernel.perf_event_max_stack=127
SYSCTL
fi

if [ "$IS_IGPU" = true ]; then
    cat << SYSCTL >> /etc/sysctl.d/raptor-gaming.conf

# ── iGPU extras (shared RAM/VRAM) ────────────────────────────────────────────
vm.vfs_cache_pressure=50
vm.min_free_kbytes=131072
SYSCTL
fi

# Reload sysctl immediately
sysctl --system > /dev/null 2>&1 || true

# ── Build GPU environment vars ─────────────────────────────────────────────────
mkdir -p /etc/environment.d

# Base vars safe for every profile and GPU
COMMON_VARS="WINE_LARGE_ADDRESS_AWARE=1
PROTON_FORCE_LARGE_ADDRESS_AWARE=1
STAGING_SHARED_MEMORY=1
# Proton FSR (FidelityFX Super Resolution) available in compatible games
WINE_FULLSCREEN_FSR=1
# Better frame pacing
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
# Threaded optimizations
__GL_THREADED_OPTIMIZATIONS=1
# Force highest GPU P-state (AMD)
AMDGPU_HIGH_POWER=1
# Explicit sync for lower latency
PROTON_ENABLE_NVAPI=1
DXVK_ASYNC=1
DXVK_FRAME_RATE=0
# Radeon performance tuning
RADV_DEBUG=nocompute
# VKD3D extras
VKD3D_CONFIG=dxr11,dxr
VKD3D_FEATURE_LEVEL=12_2
$COMMON_VARS
ENVEOF
    # Force AMD/NVIDIA power to performance mode at the sysfs level
    if [ "$GPU_VENDOR" = "amd" ]; then
        for f in /sys/class/drm/card*/device/power_dpm_force_performance_level; do
            echo "high" > "$f" 2>/dev/null || true
        done
        for f in /sys/class/drm/card*/device/pp_power_profile_mode; do
            # profile 5 = compute, profile 4 = VR, profile 3 = video, profile 1 = 3D_FULL_SCREEN
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
# RADV_PERFTEST=gpl intentionally omitted — causes flickering in Unity/Zomboid
AMD_VULKAN_ICD=RADV
MESA_SHADER_CACHE_DISABLE=false
MESA_SHADER_CACHE_MAX_SIZE=2G
__GL_SHADER_DISK_CACHE=1
__GL_SHADER_DISK_CACHE_SKIP_CLEANUP=1
__GL_THREADED_OPTIMIZATIONS=1
PROTON_ENABLE_NVAPI=1
DXVK_ASYNC=1
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
    # Auto: pick the best default for the detected hardware
    if [ "$GPU_VENDOR" = "nvidia" ]; then
        cat << ENVEOF > /etc/environment.d/raptor-gpu.conf
# ── Raptor OS: NVIDIA auto profile ────────────────────────────────────────────
# __NV_PRIME_RENDER_OFFLOAD=1 omitted — causes flicker in Unity/Zomboid on hybrid
__GL_SHADER_DISK_CACHE=1
__GL_SHADER_DISK_CACHE_SKIP_CLEANUP=1
__GL_THREADED_OPTIMIZATIONS=1
PROTON_ENABLE_NVAPI=1
DXVK_ASYNC=1
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
# RADV_PERFTEST=gpl omitted — lighting bugs in Unity/Zomboid on many Mesa builds
AMD_VULKAN_ICD=RADV
MESA_SHADER_CACHE_DISABLE=false
MESA_SHADER_CACHE_MAX_SIZE=2G
__GL_SHADER_DISK_CACHE=1
DXVK_ASYNC=1
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

# ── Live-apply env vars to running user sessions (no logout needed) ────────────
# Re-export every var in the generated file to all active user systemd sessions
ENVFILE=/etc/environment.d/raptor-gpu.conf
if [ -f "$ENVFILE" ]; then
    # Build a clean list: skip comment lines and blank lines
    LIVE_VARS=()
    while IFS= read -r line; do
        [[ "$line" =~ ^#.*$ ]] && continue
        [[ -z "$line" ]]       && continue
        LIVE_VARS+=("$line")
    done < "$ENVFILE"

    if [ ${#LIVE_VARS[@]} -gt 0 ]; then
        # Apply to every logged-in user's systemd --user instance
        for uid in $(loginctl list-users --no-legend | awk '{print $1}'); do
            RUNTIME_DIR="/run/user/$uid"
            if [ -d "$RUNTIME_DIR" ]; then
                DBUS="unix:path=$RUNTIME_DIR/bus"
                # systemctl --user import-environment via sudo -u or dbus
                sudo -u "#$uid" \
                     DBUS_SESSION_BUS_ADDRESS="$DBUS" \
                     systemctl --user import-environment "${LIVE_VARS[@]}" \
                     2>/dev/null || true
                # Also write a per-user environment.d file that sticks across restarts
                USER_ENVDIR="$(getent passwd "$uid" | cut -d: -f6)/.config/environment.d"
                mkdir -p "$USER_ENVDIR" 2>/dev/null || true
                cp "$ENVFILE" "$USER_ENVDIR/raptor-gpu.conf" 2>/dev/null || true
            fi
        done
        echo "Live env vars applied to all sessions — no logout required."
    fi
fi

# ── CPU governor: match GPU profile ──────────────────────────────────────────
set_cpu_governor() {
    local GOV="$1"
    for f in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
        echo "$GOV" > "$f" 2>/dev/null || true
    done
    echo "CPU governor → $GOV"
}

case "$PROFILE" in
    extreme)     set_cpu_governor "performance" ;;
    performance) set_cpu_governor "performance" ;;
    balanced)    set_cpu_governor "schedutil"   ;;
    powersave)   set_cpu_governor "powersave"   ;;
    auto)        set_cpu_governor "schedutil"   ;;
esac

# ── systemd service ───────────────────────────────────────────────────────────
cat << 'SVCEOF' > /usr/lib/systemd/system/raptor-gpu-profile.service
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
SVCEOF

# ── polkit rule: allow any logged-in user to switch profiles without sudo ──────
mkdir -p /etc/polkit-1/rules.d
cat << 'POLKIT' > /etc/polkit-1/rules.d/49-raptor-gpu.rules
// Allow any locally logged-in user to run raptor-gpu-profile.sh and
// the profile flag files without a password prompt.
polkit.addRule(function(action, subject) {
    var allowedActions = [
        "org.freedesktop.policykit.exec"
    ];
    if (allowedActions.indexOf(action.id) >= 0 &&
        action.lookup("program") &&
        (action.lookup("program").indexOf("raptor-gpu-profile") !== -1 ||
         action.lookup("program").indexOf("raptor-profile-switcher") !== -1) &&
        subject.active && subject.local) {
        return polkit.Result.YES;
    }
});
POLKIT

# ── sudoers drop-in: passwordless for specific raptor commands ─────────────────
cat << 'SUDOERS' > /etc/sudoers.d/raptor-gpu
# Raptor OS: allow any user to switch GPU profiles without a password
ALL ALL=(root) NOPASSWD: /usr/bin/raptor-gpu-profile.sh
ALL ALL=(root) NOPASSWD: /usr/bin/touch /etc/raptor-force-*
ALL ALL=(root) NOPASSWD: /usr/bin/rm -f /etc/raptor-force-*
ALL ALL=(root) NOPASSWD: /usr/sbin/sysctl --system
SUDOERS
chmod 440 /etc/sudoers.d/raptor-gpu

echo "GPU_PROFILE_READY  profile=$PROFILE  vendor=$GPU_VENDOR  igpu=$IS_IGPU  hybrid=$IS_HYBRID"
