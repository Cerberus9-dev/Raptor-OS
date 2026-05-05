#!/bin/bash
set -oue pipefail

# Detect GPU vendor
if lspci | grep -i "VGA\|3D\|Display" | grep -qi "nvidia"; then
    GPU_VENDOR="nvidia"
elif lspci | grep -i "VGA\|3D\|Display" | grep -qi "amd\|radeon"; then
    GPU_VENDOR="amd"
elif lspci | grep -i "VGA\|3D\|Display" | grep -qi "intel"; then
    GPU_VENDOR="intel"
else
    GPU_VENDOR="unknown"
fi

echo "Detected GPU vendor: $GPU_VENDOR"

# Detect if iGPU or low end (no dedicated VRAM shown)
IS_IGPU=false
if lspci | grep -i "VGA\|3D\|Display" | grep -qi "intel"; then
    IS_IGPU=true
fi
if lspci -v | grep -i "VGA\|3D\|Display" -A5 | grep -qi "subsystem.*apu\|integrated"; then
    IS_IGPU=true
fi

# Safe sysctl tweaks for all profiles
cat << 'EOF' > /etc/sysctl.d/raptor-gaming.conf
vm.swappiness=10
vm.dirty_ratio=10
vm.dirty_background_ratio=5
kernel.sched_autogroup_enabled=1
EOF

# Extra sysctl for low end / iGPU
if [ "$IS_IGPU" = true ]; then
    cat << 'EOF' >> /etc/sysctl.d/raptor-gaming.conf
vm.vfs_cache_pressure=50
vm.swappiness=5
EOF
fi

# Apply vendor specific profile
mkdir -p /etc/environment.d

if [ "$GPU_VENDOR" = "nvidia" ]; then
    cat << 'EOF' > /etc/environment.d/raptor-gpu.conf
__GL_SHADER_DISK_CACHE=1
__GL_SHADER_DISK_CACHE_SKIP_CLEANUP=1
PROTON_ENABLE_NVAPI=1
__NV_PRIME_RENDER_OFFLOAD=1
EOF

elif [ "$GPU_VENDOR" = "amd" ]; then
    if [ "$IS_IGPU" = true ]; then
        # Conservative settings for AMD iGPU
        cat << 'EOF' > /etc/environment.d/raptor-gpu.conf
AMD_VULKAN_ICD=RADV
mesa_glthread=true
MESA_SHADER_CACHE_DISABLE=false
EOF
    else
        # Full settings for AMD dGPU
        cat << 'EOF' > /etc/environment.d/raptor-gpu.conf
RADV_PERFTEST=gpl
AMD_VULKAN_ICD=RADV
mesa_glthread=true
MESA_SHADER_CACHE_DISABLE=false
EOF
    fi

elif [ "$GPU_VENDOR" = "intel" ]; then
    cat << 'EOF' > /etc/environment.d/raptor-gpu.conf
MESA_LOADER_DRIVER_OVERRIDE=iris
LIBGL_DRI3_DISABLE=0
vblank_mode=0
mesa_glthread=true
EOF

else
    cat << 'EOF' > /etc/environment.d/raptor-gpu.conf
mesa_glthread=true
MESA_SHADER_CACHE_DISABLE=false
EOF
fi

echo "GPU_PROFILE_READY"
