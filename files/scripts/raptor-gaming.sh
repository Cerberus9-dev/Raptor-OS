#!/bin/bash
set -oue pipefail

# ── Lutris ────────────────────────────────────────────────────────────────────
mkdir -p /etc/skel/.config/lutris
cat << 'EOF' > /etc/skel/.config/lutris/lutris.conf
[lutris]
prefer-system-libraries=true
reset-desktop-on-quit=false
game-show-logs=false
EOF

# ── Steam ─────────────────────────────────────────────────────────────────────
mkdir -p /etc/skel/.steam/steam
cat << 'EOF' > /etc/skel/.steam/steam/steam_dev.cfg
@nClientDownloadEnableHTTP2PlatformLinux 0
@fDownloadRateImprovementToAddAnotherConnection 1.0
EOF

# ── System-wide ulimits for gaming processes ──────────────────────────────────
# Unturned (Unity) opens many files simultaneously (assets, maps, bundles).
# Default nofile=1024 causes silent failures on large maps; bump to 1M.
cat << 'EOF' > /etc/security/limits.d/raptor-gaming.conf
# Raise open file descriptor limit for all users (Unity asset streaming)
*    soft    nofile    1048576
*    hard    nofile    1048576
# Allow more locked memory pages (useful for Vulkan/VKMS drivers)
*    soft    memlock   unlimited
*    hard    memlock   unlimited
EOF

# ── Unturned / Unity recommended Steam launch options ─────────────────────────
# Write a hint file users can reference when setting launch options in Steam.
# These are not applied automatically — the user must paste them into
# Steam → right-click Unturned → Properties → Launch Options.
mkdir -p /etc/raptor
cat << 'EOF' > /etc/raptor/unturned-launch-options.txt
Recommended Steam launch options for Unturned (Unity / low-RAM systems):

  PROTON_FORCE_LARGE_ADDRESS_AWARE=1 STAGING_SHARED_MEMORY=1 %command% \
    -gc.maxreserved 128 \
    -force-gfx-jobs native \
    -disable-gpu-skinning \
    -no-sandbox

Explanation:
  -gc.maxreserved 128        Cap Unity's reserved GC heap to 128 MB;
                              prevents the mono runtime from grabbing a large
                              upfront slab and never returning it to the OS.
  -force-gfx-jobs native     Run graphics jobs on native threads instead of
                              job workers, reducing memory fragmentation.
  -disable-gpu-skinning       Moves skinning back to CPU, freeing GPU RAM on
                              shared-memory (iGPU) systems.
  -no-sandbox                Removes the Chromium sandbox layer Unity embeds;
                              saves ~40 MB of address space on 32-bit builds.
EOF

echo "Hint file written to /etc/raptor/unturned-launch-options.txt"
echo "GAMING_READY"
