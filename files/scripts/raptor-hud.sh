#!/bin/bash
set -oue pipefail

# ═══════════════════════════════════════════════════════════════════════════════
# Raptor OS — HUD Script  v2.0
# Installs: KDE theme, GPU profile switcher (no-password), RAM optimizer,
#           background process trimmer, browser launchers,
#           Raptor OS app menu category, and all .desktop entries.
# ═══════════════════════════════════════════════════════════════════════════════

# ── Neon Green KDE theme ───────────────────────────────────────────────────────
mkdir -p /etc/skel/.config
cat << 'EOF' > /etc/skel/.config/kdeglobals
[General]
ColorScheme=BreezeDark
AccentColor=51,255,51
accentColorFromWallpaper=false

[KDE]
AnimationDurationFactor=0.5
EOF

for dir in /root /home/*; do
    if [ -d "$dir" ]; then
        mkdir -p "$dir/.config"
        cp /etc/skel/.config/kdeglobals "$dir/.config/kdeglobals"
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
        cp /etc/skel/.config/autostart/raptor-theme.desktop \
           "$dir/.config/autostart/" 2>/dev/null || true
    fi
done

# ── GPU Profile Switcher (no password / no logout) ─────────────────────────────
cat << 'SWITCHER' > /usr/bin/raptor-profile-switcher.sh
#!/bin/bash

# ── Determine current profile label ──────────────────────────────────────────
CURRENT_GPU="Auto (Smart detect)"
[ -f /etc/raptor-force-extreme ]     && CURRENT_GPU="⚡ Extreme Performance"
[ -f /etc/raptor-force-performance ] && CURRENT_GPU="🚀 Max Performance"
[ -f /etc/raptor-force-balanced ]    && CURRENT_GPU="⚖  Balanced"
[ -f /etc/raptor-force-powersave ]   && CURRENT_GPU="🍃 Power Saving"

# Get GPU model for display
GPU_LINE=$(lspci | grep -i "VGA\|3D\|Display" | head -1 | sed 's/.*: //')

CHOICE=$(zenity --list \
  --title="Raptor OS — GPU Profile Switcher" \
  --text="<b>GPU:</b> ${GPU_LINE}\n<b>Current profile:</b> ${CURRENT_GPU}\n\nSelect a new profile:" \
  --radiolist \
  --column="" --column="Profile" --column="Description" \
  FALSE "⚡ Extreme"     "Unlocked clocks, max CPU governor, async shaders, DXR raytracing" \
  FALSE "🚀 Performance" "High GPU/CPU clocks, full DXVK async, large shader cache" \
  TRUE  "🎯 Auto"        "Best settings for your detected hardware (recommended)" \
  FALSE "⚖  Balanced"   "Good performance, reasonable power draw" \
  FALSE "🍃 Power Save"  "Minimum clocks, disabled caches — for battery/thermals" \
  --width=700 --height=420 2>/dev/null) || exit 0

# ── Strip emoji prefix ────────────────────────────────────────────────────────
CHOICE_CLEAN=$(echo "$CHOICE" | sed 's/^[^ ]* //')

# ── Apply profile flags ───────────────────────────────────────────────────────
sudo rm -f /etc/raptor-force-extreme \
           /etc/raptor-force-performance \
           /etc/raptor-force-powersave \
           /etc/raptor-force-balanced

case "$CHOICE_CLEAN" in
  "Extreme")     sudo touch /etc/raptor-force-extreme ;;
  "Performance") sudo touch /etc/raptor-force-performance ;;
  "Balanced")    sudo touch /etc/raptor-force-balanced ;;
  "Power Save")  sudo touch /etc/raptor-force-powersave ;;
  "Auto")        : ;;  # no flag = auto
esac

# ── Run profile detection (live — no logout needed) ───────────────────────────
sudo /usr/bin/raptor-gpu-profile.sh

# ── Notify user ───────────────────────────────────────────────────────────────
zenity --info \
  --title="Raptor OS" \
  --text="<b>${CHOICE}</b> profile applied!\n\nChanges are live — no logout required.\nFor best results with shader caches, restart any open games." \
  --width=400 2>/dev/null || true
SWITCHER
chmod +x /usr/bin/raptor-profile-switcher.sh

# ── RAM Optimizer (no password via polkit/sudo) ────────────────────────────────
cat << 'RAMOPT' > /usr/bin/raptor-ram-launcher
#!/bin/bash
# Launcher: shows a menu then calls the real optimizer with sudo (no password needed)
TOTAL=$(grep MemTotal /proc/meminfo | awk '{print $2}')
FREE=$(grep MemAvailable /proc/meminfo | awk '{print $2}')
USED=$(( (TOTAL - FREE) / 1024 ))
TOTAL_MB=$(( TOTAL / 1024 ))

CHOICE=$(zenity --list \
  --title="Raptor OS — RAM Optimizer" \
  --text="<b>RAM Usage:</b> ${USED} MB used of ${TOTAL_MB} MB\n\nChoose an optimization level:" \
  --radiolist \
  --column="" --column="Level" --column="What it does" \
  TRUE  "🧹 Quick Clean"     "Drop page caches + compact memory (instant, safe)" \
  FALSE "🎮 Gaming Mode"     "Quick clean + pause all indexers and background services" \
  FALSE "💪 Deep Clean"      "Gaming mode + ZRAM rebalance + swap trimming" \
  FALSE "🔧 Aggressive"      "Deep clean + kill optional background processes" \
  FALSE "♻  Restore"         "Resume all paused services after gaming" \
  --width=700 --height=380 2>/dev/null) || exit 0

case "$CHOICE" in
  *"Quick Clean"*)
    sudo /usr/bin/raptor-ram-optimizer.sh quick
    ;;
  *"Gaming Mode"*)
    sudo /usr/bin/raptor-ram-optimizer.sh gaming
    sudo /usr/bin/raptor-trim-background.sh
    ;;
  *"Deep Clean"*)
    sudo /usr/bin/raptor-ram-optimizer.sh deep
    sudo /usr/bin/raptor-trim-background.sh
    ;;
  *"Aggressive"*)
    sudo /usr/bin/raptor-ram-optimizer.sh aggressive
    sudo /usr/bin/raptor-trim-background.sh
    ;;
  *"Restore"*)
    sudo /usr/bin/raptor-restore-background.sh
    ;;
esac

FREE_AFTER=$(grep MemAvailable /proc/meminfo | awk '{print $2}')
FREE_AFTER_MB=$(( FREE_AFTER / 1024 ))

zenity --info \
  --title="Raptor OS — RAM Optimizer" \
  --text="<b>Done!</b>\n\nRAM now available: <b>${FREE_AFTER_MB} MB</b>" \
  --width=320 2>/dev/null || true
RAMOPT
chmod +x /usr/bin/raptor-ram-launcher

cat << 'RAMSCRIPT' > /usr/bin/raptor-ram-optimizer.sh
#!/bin/bash
# Raptor OS RAM Optimizer — called by raptor-ram-launcher with a level arg
LEVEL="${1:-quick}"
echo "=== Raptor RAM Optimizer: $LEVEL ==="

# ── quick: always run these ─────────────────────────────────────────────────
sync
# Drop page caches (1), dentries+inodes (2), or both (3)
echo 3 > /proc/sys/vm/drop_caches
echo "✔ Dropped page/dentry/inode caches"

# Compact memory to reduce fragmentation
echo 1 > /proc/sys/vm/compact_memory 2>/dev/null || true
echo "✔ Compacted memory"

if [ "$LEVEL" = "quick" ]; then exit 0; fi

# ── gaming ──────────────────────────────────────────────────────────────────
# Reduce swappiness temporarily for the session
sysctl -w vm.swappiness=5 > /dev/null
echo "✔ Swappiness → 5 (gaming)"

# Force writeback of dirty pages
echo 0 > /proc/sys/vm/dirty_writeback_centisecs
sleep 0.5
echo 500 > /proc/sys/vm/dirty_writeback_centisecs
echo "✔ Flushed dirty pages"

if [ "$LEVEL" = "gaming" ]; then exit 0; fi

# ── deep ────────────────────────────────────────────────────────────────────
# Recycle ZRAM if present
if command -v zramctl &>/dev/null; then
    ZRAM_DEVS=$(zramctl --noheadings --output NAME 2>/dev/null || true)
    for dev in $ZRAM_DEVS; do
        ZRAM_SIZE=$(zramctl --noheadings --output SIZE "$dev" 2>/dev/null || echo "0")
        swapoff "$dev" 2>/dev/null || true
        echo 1 > "/sys/block/$(basename $dev)/reset" 2>/dev/null || true
        echo "✔ ZRAM $dev recycled"
    done
    /usr/bin/raptor-zram-setup.sh 2>/dev/null || true
fi

# Trim SSDs (releases unused blocks)
fstrim -v / 2>/dev/null || true
echo "✔ SSD TRIM run"

if [ "$LEVEL" = "deep" ]; then exit 0; fi

# ── aggressive ──────────────────────────────────────────────────────────────
# Kill optional heavyweight background processes (not system-critical)
OPTIONAL_PROCS=(
    "tumblerd"       # KDE thumbnail generator
    "kio_http_cache" # KDE HTTP cache worker
    "kactivitymanagerd"
    "gvfsd-metadata"
    "tracker-miner-fs"
    "tracker-store"
    "zeitgeist-daemon"
    "evolution-calendar"
    "evolution-addressbook"
    "gnome-software"
    "update-notifier"
)
for proc in "${OPTIONAL_PROCS[@]}"; do
    if pkill -0 "$proc" 2>/dev/null; then
        pkill "$proc" 2>/dev/null || true
        echo "✔ Stopped $proc"
    fi
done

# Set OOM score on known memory hogs to let kernel clean them up under pressure
for proc in "web_content" "plugin_container" "npviewer"; do
    for pid in $(pgrep "$proc" 2>/dev/null); do
        echo 500 > "/proc/$pid/oom_score_adj" 2>/dev/null || true
    done
done

echo "=== Aggressive clean complete ==="
RAMSCRIPT
chmod +x /usr/bin/raptor-ram-optimizer.sh

# sudoers entry for RAM optimizer
cat << 'RAMSU' >> /etc/sudoers.d/raptor-gpu
ALL ALL=(root) NOPASSWD: /usr/bin/raptor-ram-optimizer.sh
RAMSU

# polkit rule for RAM optimizer
cat << 'POLKIT2' > /etc/polkit-1/rules.d/49-raptor-ram.rules
polkit.addRule(function(action, subject) {
    if (action.id === "org.freedesktop.policykit.exec" &&
        action.lookup("program") &&
        action.lookup("program").indexOf("raptor-ram") !== -1 &&
        subject.active && subject.local) {
        return polkit.Result.YES;
    }
});
POLKIT2

# ── Browser choice ──────────────────────────────────────────────────────────
chmod +x /usr/bin/raptor-browser-choice.sh 2>/dev/null || true

# ── Raptor OS app menu category ─────────────────────────────────────────────
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

# ── .desktop entries ─────────────────────────────────────────────────────────
# NOTE: Categories must end with X-RaptorOS; only — extra standard categories
# can cause KDE Plasma to drop entries from custom X- folders.

mkdir -p /usr/share/applications

cat << 'EOF' > /usr/share/applications/raptor-profile-switcher.desktop
[Desktop Entry]
Version=1.1
Type=Application
Name=Raptor GPU Profile Switcher
Comment=Switch GPU profiles instantly — no password or logout required
Exec=/usr/bin/raptor-profile-switcher.sh
Icon=preferences-system-performance
Terminal=false
Categories=X-RaptorOS;
Keywords=gpu;performance;power;profile;raptor;extreme;
EOF

cat << 'EOF' > /usr/share/applications/raptor-ram-optimizer.desktop
[Desktop Entry]
Version=1.1
Type=Application
Name=Raptor RAM Optimizer
Comment=Free RAM, pause indexers, optimize memory for gaming — no password needed
Exec=/usr/bin/raptor-ram-launcher
Icon=memory
Terminal=false
Categories=X-RaptorOS;
Keywords=ram;memory;optimize;performance;raptor;gaming;
EOF

cat << 'EOF' > /usr/share/applications/raptor-background-trim.desktop
[Desktop Entry]
Version=1.1
Type=Application
Name=Raptor Background Trimmer
Comment=Pause background services and free resources before gaming
Exec=bash -c "pkexec /usr/bin/raptor-trim-background.sh && zenity --info --title='Raptor OS' --text='Background services paused.\nRun \"Raptor Restore Background\" after gaming.' --width=360"
Icon=system-run
Terminal=false
Categories=X-RaptorOS;
Keywords=background;services;gaming;performance;raptor;trim;
EOF

cat << 'EOF' > /usr/share/applications/raptor-restore-background.desktop
[Desktop Entry]
Version=1.1
Type=Application
Name=Raptor Restore Background
Comment=Resume background services after gaming
Exec=bash -c "pkexec /usr/bin/raptor-restore-background.sh && zenity --info --title='Raptor OS' --text='Background services restored.' --width=300"
Icon=system-reboot
Terminal=false
Categories=X-RaptorOS;
Keywords=background;restore;services;raptor;
EOF

cat << 'EOF' > /usr/share/applications/raptor-brave-optimized.desktop
[Desktop Entry]
Version=1.1
Type=Application
Name=Brave (Raptor Optimized)
Comment=Brave browser with GPU acceleration and performance flags
Exec=/usr/local/bin/brave-optimized %U
Icon=brave-browser
Terminal=false
MimeType=x-scheme-handler/http;x-scheme-handler/https;
Categories=X-RaptorOS;Network;WebBrowser;
Keywords=brave;browser;optimized;raptor;
EOF

echo "HUD_READY"
