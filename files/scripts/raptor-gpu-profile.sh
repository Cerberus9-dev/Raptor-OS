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
# vm.swappiness is NOT set here — raptor-memory.conf (script 1) owns it.
# Duplicating it here caused an unpredictable race depending on boot order.
cat << 'EOF' > /etc/sysctl.d/raptor-gaming.conf
# Scheduler: group tasks by session so background work doesn't starve the game
kernel.sched_autogroup_enabled=1

# Reduce inode/dentry cache pressure on iGPU systems where RAM is shared
# (only relevant for iGPU; set below)
EOF

if [ "$IS_IGPU" = true ]; then
    cat << 'EOF' >> /etc/sysctl.d/raptor-gaming.conf
# iGPU shares RAM with VRAM — keep more pages in the page cache
vm.vfs_cache_pressure=50
EOF
fi

# ── GPU environment variables ─────────────────────────────────────────────────
mkdir -p /etc/environment.d

# Shared Proton/Unity memory vars added to every profile:
# WINE_LARGE_ADDRESS_AWARE — lets 32-bit Unity builds address >2 GB
# PROTON_FORCE_LARGE_ADDRESS_AWARE — same flag via Proton wrapper
# STAGING_SHARED_MEMORY — use shared mem for cross-process communication
COMMON_UNITY_VARS=$(cat << 'VARS'
WINE_LARGE_ADDRESS_AWARE=1
PROTON_FORCE_LARGE_ADDRESS_AWARE=1
STAGING_SHARED_MEMORY=1
VARS
)

if [ -f /etc/raptor-force-performance ]; then
    echo "Performance override active"
    cat << EOF > /etc/environment.d/raptor-gpu.conf
RADV_PERFTEST=gpl
AMD_VULKAN_ICD=RADV
mesa_glthread=true
MESA_SHADER_CACHE_DISABLE=false
__GL_SHADER_DISK_CACHE=1
__GL_SHADER_DISK_CACHE_SKIP_CLEANUP=1
PROTON_ENABLE_NVAPI=1
$COMMON_UNITY_VARS
EOF

elif [ -f /etc/raptor-force-powersave ]; then
    echo "Power saving override active"
    cat << EOF > /etc/environment.d/raptor-gpu.conf
mesa_glthread=false
MESA_SHADER_CACHE_DISABLE=true
$COMMON_UNITY_VARS
EOF

elif [ "$GPU_VENDOR" = "nvidia" ]; then
    cat << EOF > /etc/environment.d/raptor-gpu.conf
__GL_SHADER_DISK_CACHE=1
__GL_SHADER_DISK_CACHE_SKIP_CLEANUP=1
PROTON_ENABLE_NVAPI=1
__NV_PRIME_RENDER_OFFLOAD=1
$COMMON_UNITY_VARS
EOF

elif [ "$GPU_VENDOR" = "amd" ]; then
    if [ "$IS_IGPU" = true ]; then
        cat << EOF > /etc/environment.d/raptor-gpu.conf
AMD_VULKAN_ICD=RADV
mesa_glthread=true
MESA_SHADER_CACHE_DISABLE=false
$COMMON_UNITY_VARS
EOF
    else
        cat << EOF > /etc/environment.d/raptor-gpu.conf
RADV_PERFTEST=gpl
AMD_VULKAN_ICD=RADV
mesa_glthread=true
MESA_SHADER_CACHE_DISABLE=false
$COMMON_UNITY_VARS
EOF
    fi

elif [ "$GPU_VENDOR" = "intel" ]; then
    cat << EOF > /etc/environment.d/raptor-gpu.conf
MESA_LOADER_DRIVER_OVERRIDE=iris
LIBGL_DRI3_DISABLE=0
vblank_mode=0
mesa_glthread=true
$COMMON_UNITY_VARS
EOF

else
    cat << EOF > /etc/environment.d/raptor-gpu.conf
mesa_glthread=true
MESA_SHADER_CACHE_DISABLE=false
$COMMON_UNITY_VARS
EOF
fi

echo "GPU_PROFILE_READY"
