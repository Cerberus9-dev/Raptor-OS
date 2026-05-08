#!/bin/bash
set -oue pipefail

# ── GPU detection ─────────────────────────────────────────────────────────────
if lspci | grep -i "VGA\|3D\|Display" | grep -qi "nvidia"; then
    GPU_VENDOR="nvidia"
elif lspci | grep -i "VGA\|3D\|Display" | grep -qi "amd\|radeon\|ati"; then
    GPU_VENDOR="amd"
elif lspci | grep -i "VGA\|3D\|Display" | grep -qi "intel"; then
    GPU_VENDOR="intel"
else
    GPU_VENDOR="unknown"
fi
echo "Detected GPU vendor: $GPU_VENDOR"

IS_IGPU=false
if lspci | grep -i "VGA\|3D\|Display" | grep -qi "intel"; then
    IS_IGPU=true
fi
if lspci -v | grep -i "VGA\|3D\|Display" -A5 | grep -qi \
    "subsystem.*apu\|integrated\|cezanne\|renoir\|lucienne\|rembrandt\|mendocino"; then
    IS_IGPU=true
fi

# ── Gaming sysctl ─────────────────────────────────────────────────────────────
cat << 'SYSCTL' > /etc/sysctl.d/raptor-gaming.conf
# Group tasks by session so background work doesn't starve the game
kernel.sched_autogroup_enabled=1
SYSCTL

if [ "$IS_IGPU" = true ]; then
    cat << 'SYSCTL' >> /etc/sysctl.d/raptor-gaming.conf
# iGPU shares RAM with VRAM — keep more pages in the page cache
vm.vfs_cache_pressure=50
SYSCTL
fi

# ── GPU environment variables ─────────────────────────────────────────────────
mkdir -p /etc/environment.d

# Common Proton/Unity vars applied to every profile.
# NOTE: mesa_glthread is intentionally NOT included here.
# Unity (Unturned) and Project Zomboid's renderer are not GL-thread-safe —
# enabling async glthread causes flickering, wrong lighting, and draw-call
# corruption in both games. It is only safe to enable per-game via Steam
# launch options if the specific game supports it.
COMMON_UNITY_VARS="WINE_LARGE_ADDRESS_AWARE=1
PROTON_FORCE_LARGE_ADDRESS_AWARE=1
STAGING_SHARED_MEMORY=1"

if [ -f /etc/raptor-force-performance ]; then
    echo "Performance override active"
    cat << ENVEOF > /etc/environment.d/raptor-gpu.conf
# Performance profile
# RADV_PERFTEST=gpl is intentionally omitted — GPL pipeline libs cause
# shader compilation artefacts and flickering in Unity/Zomboid on many
# Mesa versions. Re-enable only if you are not running those games.
AMD_VULKAN_ICD=RADV
MESA_SHADER_CACHE_DISABLE=false
__GL_SHADER_DISK_CACHE=1
__GL_SHADER_DISK_CACHE_SKIP_CLEANUP=1
PROTON_ENABLE_NVAPI=1
$COMMON_UNITY_VARS
ENVEOF

elif [ -f /etc/raptor-force-powersave ]; then
    echo "Power saving override active"
    cat << ENVEOF > /etc/environment.d/raptor-gpu.conf
# Power saving profile
MESA_SHADER_CACHE_DISABLE=true
$COMMON_UNITY_VARS
ENVEOF

elif [ "$GPU_VENDOR" = "nvidia" ]; then
    cat << ENVEOF > /etc/environment.d/raptor-gpu.conf
# Nvidia profile
# __NV_PRIME_RENDER_OFFLOAD=1 omitted — forcing dGPU offload unconditionally
# desynchronises display vs render output causing flicker in Unity/Zomboid.
# Enable per-game in Steam launch options if you have a hybrid GPU setup.
__GL_SHADER_DISK_CACHE=1
__GL_SHADER_DISK_CACHE_SKIP_CLEANUP=1
PROTON_ENABLE_NVAPI=1
$COMMON_UNITY_VARS
ENVEOF

elif [ "$GPU_VENDOR" = "amd" ] && [ "$IS_IGPU" = true ]; then
    cat << ENVEOF > /etc/environment.d/raptor-gpu.conf
# AMD iGPU profile
AMD_VULKAN_ICD=RADV
MESA_SHADER_CACHE_DISABLE=false
$COMMON_UNITY_VARS
ENVEOF

elif [ "$GPU_VENDOR" = "amd" ]; then
    cat << ENVEOF > /etc/environment.d/raptor-gpu.conf
# AMD dGPU profile
# RADV_PERFTEST=gpl omitted — causes flickering/lighting bugs in
# Unity (Unturned) and Project Zomboid on many Mesa builds.
AMD_VULKAN_ICD=RADV
MESA_SHADER_CACHE_DISABLE=false
$COMMON_UNITY_VARS
ENVEOF

elif [ "$GPU_VENDOR" = "intel" ]; then
    cat << ENVEOF > /etc/environment.d/raptor-gpu.conf
# Intel profile
MESA_LOADER_DRIVER_OVERRIDE=iris
LIBGL_DRI3_DISABLE=0
vblank_mode=0
$COMMON_UNITY_VARS
ENVEOF

else
    cat << ENVEOF > /etc/environment.d/raptor-gpu.conf
# Fallback profile
MESA_SHADER_CACHE_DISABLE=false
$COMMON_UNITY_VARS
ENVEOF
fi

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

echo "GPU_PROFILE_READY"
