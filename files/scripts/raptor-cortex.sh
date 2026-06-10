#!/bin/bash
set -e

# =============================================================================
# Raptor Cortex v4.1 — Unified Memory & Performance Management
# • RAM optimization with page cache management, compaction, zram recompress
# • Background service trimming/restoring for gaming
# • Seamless performance mode switching (no login required)
# • Game mode auto-suspend/resume via Cortex patterns
# • CPU boost management (complements GPU Profiler)
# • Per-mode kernel tuning (power/balanced/performance)
# • Battery slider passthrough via power-profiles-daemon
# • PCIe ASPM, NVMe power states, USB autosuspend, runtime PM
# =============================================================================

# ── Custom icon ───────────────────────────────────────────────────────────────
mkdir -p /usr/share/icons/hicolor/scalable/apps
cat << 'SVGEOF' > /usr/share/icons/hicolor/scalable/apps/raptor-cortex.svg
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64">
  <defs>
    <radialGradient id="bg" cx="50%" cy="50%" r="50%">
      <stop offset="0%" stop-color="#7c3aed"/>
      <stop offset="100%" stop-color="#4c1d95"/>
    </radialGradient>
    <radialGradient id="core" cx="50%" cy="50%" r="50%">
      <stop offset="0%" stop-color="#c4b5fd"/>
      <stop offset="100%" stop-color="#7c3aed"/>
    </radialGradient>
  </defs>
  <circle cx="32" cy="32" r="30" fill="url(#bg)"/>
  <circle cx="32" cy="32" r="24" fill="none" stroke="#a78bfa" stroke-width="1.5"
          stroke-dasharray="12 4" stroke-linecap="round"/>
  <line x1="32" y1="10" x2="32" y2="18" stroke="#c4b5fd" stroke-width="2" stroke-linecap="round"/>
  <line x1="32" y1="46" x2="32" y2="54" stroke="#c4b5fd" stroke-width="2" stroke-linecap="round"/>
  <line x1="10" y1="32" x2="18" y2="32" stroke="#c4b5fd" stroke-width="2" stroke-linecap="round"/>
  <line x1="46" y1="32" x2="54" y2="32" stroke="#c4b5fd" stroke-width="2" stroke-linecap="round"/>
  <line x1="16.7" y1="16.7" x2="22.4" y2="22.4" stroke="#c4b5fd" stroke-width="1.5" stroke-linecap="round"/>
  <line x1="41.6" y1="41.6" x2="47.3" y2="47.3" stroke="#c4b5fd" stroke-width="1.5" stroke-linecap="round"/>
  <line x1="47.3" y1="16.7" x2="41.6" y2="22.4" stroke="#c4b5fd" stroke-width="1.5" stroke-linecap="round"/>
  <line x1="22.4" y1="41.6" x2="16.7" y2="47.3" stroke="#c4b5fd" stroke-width="1.5" stroke-linecap="round"/>
  <circle cx="32" cy="32" r="9" fill="url(#core)"/>
  <path d="M 29 26 L 35 26 L 33 31 L 36 31 L 29 40 L 31 33 L 28 33 Z"
        fill="white" opacity="0.95"/>
</svg>
SVGEOF

gtk-update-icon-cache /usr/share/icons/hicolor 2>/dev/null || true

# ── Privileged helper ─────────────────────────────────────────────────────────
mkdir -p /usr/lib/raptor

cat << 'EOF' > /usr/lib/raptor/cortex-helper
#!/bin/bash
# Args: CACHE COMPACT ZRAM OOM DEEP SWAP THP CPU | trim-background |
#       restore-background | set-mode <power_saving|balanced|performance>
ACTION="${1:-help}"

# ── Hardware power helpers ────────────────────────────────────────────────────

_apply_pcie_aspm() {
    # powersave | performance | default
    local P="$1"
    [ -f /sys/module/pcie_aspm/parameters/policy ] && \
        echo "$P" > /sys/module/pcie_aspm/parameters/policy 2>/dev/null || true
}

_apply_nvme_power() {
    # min_power | max_performance | auto
    local S="$1"
    for f in /sys/class/nvme/nvme*/power/control \
              /sys/bus/pci/devices/*/nvme/nvme*/power/control; do
        [ -f "$f" ] && echo "$S" > "$f" 2>/dev/null || true
    done
}

_apply_usb_autosuspend() {
    # 1 = enable (power save), 0 = disable (performance)
    if [ "$1" = "1" ]; then
        for d in /sys/bus/usb/devices/*/power/autosuspend_delay_ms; do
            echo 2000 > "$d" 2>/dev/null || true
        done
        for c in /sys/bus/usb/devices/*/power/control; do
            echo auto > "$c" 2>/dev/null || true
        done
    else
        for c in /sys/bus/usb/devices/*/power/control; do
            echo on > "$c" 2>/dev/null || true
        done
    fi
}

_apply_runtime_pm() {
    # auto | on
    local P="$1"
    for f in /sys/bus/pci/devices/*/power/control; do
        echo "$P" > "$f" 2>/dev/null || true
    done
}

_apply_sata_link_power() {
    # min_power | medium_power | max_performance
    local P="$1"
    for f in /sys/class/scsi_host/host*/link_power_management_policy; do
        echo "$P" > "$f" 2>/dev/null || true
    done
}

_apply_audio_powersave() {
    # 1 or 0
    for f in /sys/module/snd_hda_intel/parameters/power_save \
              /sys/module/snd_ac97_codec/parameters/power_save; do
        [ -f "$f" ] && echo "$1" > "$f" 2>/dev/null || true
    done
}

# FIX: clear Powerdevil session action so switching to power-saver
# doesn't trigger a logout/suspend. Patches every user's config and
# tells the running daemon to reload.
_clear_powerdevil_session_action() {
    while IFS=: read -r _ _ uid _ _ home _; do
        [ "$uid" -lt 1000 ] && continue
        [ -d "$home" ] || continue
        PPRC="$home/.config/powermanagementprofilesrc"
        [ -f "$PPRC" ] || continue
        [ -f "${PPRC}.raptorbak" ] || cp "$PPRC" "${PPRC}.raptorbak"
        for grp in "Battery][SuspendSession" "LowBattery][SuspendSession" \
                   "AC][SuspendSession"; do
            if grep -q "\[$grp\]" "$PPRC" 2>/dev/null; then
                sed -i "/\[$grp\]/,/^\[/ s/^idleTime=.*/idleTime=0/"     "$PPRC" 2>/dev/null || true
                sed -i "/\[$grp\]/,/^\[/ s/^suspendType=.*/suspendType=0/" "$PPRC" 2>/dev/null || true
            fi
        done
        if grep -q "\[Battery\]\[HandleButtonEvents\]" "$PPRC" 2>/dev/null; then
            sed -i "/\[Battery\]\[HandleButtonEvents\]/,/^\[/ s/^powerButtonAction=.*/powerButtonAction=0/" \
                "$PPRC" 2>/dev/null || true
        fi
    done < /etc/passwd
    # Tell Powerdevil daemon to reload
    for uid in $(loginctl list-users --no-legend 2>/dev/null | awk '{print $1}' || true); do
        runuser -u "#$uid" -- \
            dbus-send --session --dest=org.kde.Solid.PowerManagement \
            /org/kde/Solid/PowerManagement \
            org.kde.Solid.PowerManagement.refreshStatus 2>/dev/null || true
    done
}

case "$ACTION" in
    # ── RAM optimization flags ─────────────────────────────────────────────
    0|1|2|3|4|5|6|7|8)
        DO_CACHE="${1:-0}";  DO_COMPACT="${2:-0}"; DO_ZRAM="${3:-0}"
        DO_OOM="${4:-0}";    DO_DEEP="${5:-0}";    DO_SWAP="${6:-0}"
        DO_THP="${7:-0}";    DO_CPU="${8:-0}"

        if [ "$DO_CACHE" = "1" ]; then
            sync || true
            echo 3 > /proc/sys/vm/drop_caches 2>/dev/null || true
            echo 2 > /proc/sys/vm/drop_caches 2>/dev/null || true
            echo 1 > /proc/sys/vm/drop_caches 2>/dev/null || true
        fi
        [ "$DO_COMPACT" = "1" ] && echo 1 > /proc/sys/vm/compact_memory 2>/dev/null || true
        if [ "$DO_ZRAM" = "1" ]; then
            echo 3 > /proc/sys/vm/drop_caches 2>/dev/null || true
            echo recompress > /sys/block/zram0/recompress 2>/dev/null || true
            echo writeback   > /sys/block/zram0/writeback   2>/dev/null || true
        fi
        if [ "$DO_OOM" = "1" ]; then
            for proc in plasmashell kwin_wayland kwin_x11 ksmserver kded6; do
                for pid in $(pgrep -x "$proc" 2>/dev/null || true); do
                    echo -800 > /proc/$pid/oom_score_adj 2>/dev/null || true
                done
            done
            for proc in chrome chromium brave firefox; do
                for pid in $(pgrep -x "$proc" 2>/dev/null || true); do
                    echo 300 > /proc/$pid/oom_score_adj 2>/dev/null || true
                done
            done
        fi
        if [ "$DO_DEEP" = "1" ]; then
            echo never > /sys/kernel/mm/transparent_hugepage/enabled 2>/dev/null || true
            sleep 0.5
            echo madvise > /sys/kernel/mm/transparent_hugepage/enabled 2>/dev/null || true
            echo 1 > /proc/sys/kernel/numa_balancing 2>/dev/null || true
            echo 3 > /proc/sys/vm/drop_caches 2>/dev/null || true
            echo 1 > /proc/sys/vm/compact_memory 2>/dev/null || true
        fi
        if [ "$DO_SWAP" = "1" ]; then
            CURRENT=$(cat /proc/sys/vm/swappiness 2>/dev/null || echo 80)
            echo 100 > /proc/sys/vm/swappiness 2>/dev/null || true
            sleep 1
            echo "$CURRENT" > /proc/sys/vm/swappiness 2>/dev/null || true
        fi
        if [ "$DO_THP" = "1" ]; then
            echo madvise       > /sys/kernel/mm/transparent_hugepage/enabled 2>/dev/null || true
            echo defer+madvise > /sys/kernel/mm/transparent_hugepage/defrag  2>/dev/null || true
        fi
        [ "$DO_CPU" = "1" ] && echo 1 > /sys/devices/system/cpu/cpufreq/boost 2>/dev/null || true
        for proc in plasmashell kwin_wayland kwin_x11 kded6 baloo_file; do
            for pid in $(pgrep "$proc" 2>/dev/null || true); do
                kill -USR1 "$pid" 2>/dev/null || true
            done
        done
        ;;

    # ── Per-mode kernel tuning ─────────────────────────────────────────────
    set-mode)
        MODE="${2:-balanced}"
        case "$MODE" in
            power_saving)
                # FIX: clear Powerdevil logout action BEFORE switching profile
                _clear_powerdevil_session_action

                echo 180  > /proc/sys/vm/swappiness                2>/dev/null || true
                echo 5    > /proc/sys/vm/dirty_ratio               2>/dev/null || true
                echo 2    > /proc/sys/vm/dirty_background_ratio    2>/dev/null || true
                echo 6000 > /proc/sys/vm/dirty_writeback_centisecs 2>/dev/null || true
                echo 60000 > /proc/sys/vm/dirty_expire_centisecs   2>/dev/null || true
                echo 1    > /proc/sys/vm/laptop_mode               2>/dev/null || true

                echo 0 > /sys/devices/system/cpu/cpufreq/boost     2>/dev/null || true
                for gov in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
                    echo powersave > "$gov" 2>/dev/null || true
                done
                echo never > /sys/kernel/mm/transparent_hugepage/enabled 2>/dev/null || true

                _apply_pcie_aspm       powersave
                _apply_nvme_power      min_power
                _apply_usb_autosuspend 1
                _apply_runtime_pm      auto
                _apply_sata_link_power min_power
                _apply_audio_powersave 1

                powerprofilesctl set power-saver 2>/dev/null || true
                ;;

            balanced)
                echo 100  > /proc/sys/vm/swappiness                2>/dev/null || true
                echo 15   > /proc/sys/vm/dirty_ratio               2>/dev/null || true
                echo 5    > /proc/sys/vm/dirty_background_ratio    2>/dev/null || true
                echo 1500 > /proc/sys/vm/dirty_writeback_centisecs 2>/dev/null || true
                echo 1500 > /proc/sys/vm/dirty_expire_centisecs    2>/dev/null || true
                echo 0    > /proc/sys/vm/laptop_mode               2>/dev/null || true

                echo 0 > /sys/devices/system/cpu/cpufreq/boost     2>/dev/null || true
                for gov in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
                    echo schedutil > "$gov" 2>/dev/null || true
                done
                echo madvise       > /sys/kernel/mm/transparent_hugepage/enabled 2>/dev/null || true
                echo defer+madvise > /sys/kernel/mm/transparent_hugepage/defrag  2>/dev/null || true

                _apply_pcie_aspm       default
                _apply_nvme_power      auto
                _apply_usb_autosuspend 1
                _apply_runtime_pm      auto
                _apply_sata_link_power medium_power
                _apply_audio_powersave 1

                powerprofilesctl set balanced 2>/dev/null || true
                ;;

            performance)
                echo 60  > /proc/sys/vm/swappiness                 2>/dev/null || true
                echo 10  > /proc/sys/vm/dirty_ratio                2>/dev/null || true
                echo 3   > /proc/sys/vm/dirty_background_ratio     2>/dev/null || true
                echo 500 > /proc/sys/vm/dirty_writeback_centisecs  2>/dev/null || true
                echo 500 > /proc/sys/vm/dirty_expire_centisecs     2>/dev/null || true
                echo 0   > /proc/sys/vm/laptop_mode                2>/dev/null || true

                echo 1 > /sys/devices/system/cpu/cpufreq/boost     2>/dev/null || true
                for gov in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
                    echo performance > "$gov" 2>/dev/null || true
                done
                echo madvise       > /sys/kernel/mm/transparent_hugepage/enabled 2>/dev/null || true
                echo defer+madvise > /sys/kernel/mm/transparent_hugepage/defrag  2>/dev/null || true

                _apply_pcie_aspm       performance
                _apply_nvme_power      max_performance
                _apply_usb_autosuspend 0
                _apply_runtime_pm      on
                _apply_sata_link_power max_performance
                _apply_audio_powersave 0

                sync || true
                echo 1 > /proc/sys/vm/drop_caches    2>/dev/null || true
                echo 1 > /proc/sys/vm/compact_memory 2>/dev/null || true

                powerprofilesctl set performance 2>/dev/null || true
                ;;
        esac
        ;;

    # ── Background trimming for gaming ─────────────────────────────────────
    trim-background)
        sync || true
        echo 1 > /proc/sys/vm/drop_caches    2>/dev/null || true
        echo 1 > /proc/sys/vm/compact_memory 2>/dev/null || true
        BACKGROUND_PROCS=(
            "tracker-miner" "tracker-store" "tracker3"
            "baloo_file" "baloo_file_extractor" "akonadi"
            "kded" "kdeconnectd" "gvfs" "zeitgeist"
            "tumblerd" "packagekitd" "apt-get" "dpkg"
            "updatedb" "mlocate" "snapd" "unattended-upgrade"
            "evolution" "gnome-software"
        )
        for proc in "${BACKGROUND_PROCS[@]}"; do
            pkill -STOP "$proc" 2>/dev/null || true
        done
        for proc in baloo tracker zeitgeist; do
            for pid in $(pgrep -x "$proc" 2>/dev/null); do
                ionice -c 3 -p "$pid" 2>/dev/null || true
                renice +15 -p "$pid" 2>/dev/null || true
            done
        done
        systemctl stop snapd.service   2>/dev/null || true
        systemctl stop fstrim.service  2>/dev/null || true
        balooctl6 suspend 2>/dev/null || balooctl suspend 2>/dev/null || true
        kbuildsycoca6 --invalidate     2>/dev/null || true
        echo 6000 > /proc/sys/vm/dirty_writeback_centisecs 2>/dev/null || true
        ;;

    # ── Background restoration after gaming ────────────────────────────────
    restore-background)
        BACKGROUND_PROCS=(
            "tracker-miner" "tracker-store" "tracker3"
            "baloo_file" "baloo_file_extractor" "akonadi"
            "kded" "kdeconnectd" "gvfs" "zeitgeist"
            "tumblerd" "packagekitd" "evolution"
        )
        for proc in "${BACKGROUND_PROCS[@]}"; do
            pkill -CONT "$proc" 2>/dev/null || true
        done
        balooctl6 resume 2>/dev/null || balooctl resume 2>/dev/null || true
        systemctl start snapd.service  2>/dev/null || true
        echo 500 > /proc/sys/vm/dirty_writeback_centisecs 2>/dev/null || true
        ;;

    *)
        echo "Usage: cortex-helper [CACHE COMPACT ZRAM OOM DEEP SWAP THP CPU] | set-mode <power_saving|balanced|performance> | trim-background | restore-background"
        exit 1
        ;;
esac
exit 0
EOF
chmod +x /usr/lib/raptor/cortex-helper

# ── Sudoers ───────────────────────────────────────────────────────────────────
mkdir -p /etc/sudoers.d
cat << 'EOF' > /etc/sudoers.d/raptor-cortex
ALL ALL=(root) NOPASSWD: /usr/lib/raptor/cortex-helper
EOF
chmod 440 /etc/sudoers.d/raptor-cortex || true
visudo -cf /etc/sudoers.d/raptor-cortex || true

# ── Cortex suspend config ─────────────────────────────────────────────────────
mkdir -p /etc/raptor
cat << 'EOF' > /etc/raptor/cortex-suspend.conf
# Raptor Cortex — services to suspend during gaming
baloo_file
tracker
akonadiserver
kwalletd
kdeconnectd
kio_thumbnail
kactivitymanagerd
plasma-geolocation
kbuildsycoca
zeitgeist
evolution-data
gvfsd-metadata
colord
pipewire-media-session
EOF

# ── Gamemode hooks ────────────────────────────────────────────────────────────
cat << 'EOF' > /usr/lib/raptor/gamemode-start
#!/bin/bash
sudo /usr/lib/raptor/cortex-helper 1 1 1 1 0 0 0 1 2>/dev/null || true
sudo /usr/lib/raptor/cortex-helper trim-background 2>/dev/null || true
CONFIG=/etc/raptor/cortex-suspend.conf
[ -f "$CONFIG" ] || exit 0
while IFS= read -r pattern; do
    [ -z "$pattern" ] && continue
    case "$pattern" in "#"*) continue ;; esac
    pgrep -f "$pattern" > /dev/null 2>&1 && pkill -STOP -f "$pattern" 2>/dev/null || true
done < "$CONFIG"
EOF
chmod +x /usr/lib/raptor/gamemode-start

cat << 'EOF' > /usr/lib/raptor/gamemode-end
#!/bin/bash
CONFIG=/etc/raptor/cortex-suspend.conf
[ -f "$CONFIG" ] || exit 0
while IFS= read -r pattern; do
    [ -z "$pattern" ] && continue
    case "$pattern" in "#"*) continue ;; esac
    pkill -CONT -f "$pattern" 2>/dev/null || true
done < "$CONFIG"
sudo /usr/lib/raptor/cortex-helper restore-background 2>/dev/null || true
EOF
chmod +x /usr/lib/raptor/gamemode-end

# ── Gamemode config ───────────────────────────────────────────────────────────
mkdir -p /etc/gamemode.d
cat << 'EOF' > /etc/gamemode.d/raptor-cortex.ini
[general]
renice=10
inhibit_screensaver=1
softrealtime=auto
reaper_freq=5

[gpu]
apply_gpu_optimisations=accept-responsibility
gpu_device=0
amd_performance_level=high

[custom]
start=/usr/lib/raptor/gamemode-start
end=/usr/lib/raptor/gamemode-end
EOF

# ── Python GUI ────────────────────────────────────────────────────────────────
cat << 'PYEOF' > /usr/bin/raptor-cortex
#!/usr/bin/env python3
"""Raptor Cortex v4.2 — Unified memory & performance management for Raptor OS"""

import gi
gi.require_version("Gtk", "4.0")
gi.require_version("Adw", "1")
from gi.repository import Gtk, Adw, GLib

import subprocess
import threading
import os
import sys

CORTEX_CONFIG  = "/etc/raptor/cortex-suspend.conf"
HELPER         = "/usr/lib/raptor/cortex-helper"
MODE_STATE_FILE = os.path.expanduser("~/.config/raptor-cortex-mode")

ALL_SERVICES = [
    # ── KDE / indexing ────────────────────────────────────────────────────────
    ("Baloo file indexer",      "baloo_file"),
    ("Akonadi server",          "akonadiserver"),
    ("KDE Connect daemon",      "kdeconnectd"),
    ("Thumbnail generator",     "kio_thumbnail"),
    ("Activity manager",        "kactivitymanagerd"),
    ("KDE wallet daemon",       "kwalletd"),
    ("Plasma geolocation",      "plasma-geolocation"),
    ("KDE sycoca builder",      "kbuildsycoca"),
    # ── GNOME / cross-desktop ─────────────────────────────────────────────────
    ("Evolution data server",   "evolution-data"),
    ("Zeitgeist daemon",        "zeitgeist"),
    ("GVFS metadata",           "gvfsd-metadata"),
    ("Colour management",       "colord"),
    # ── System daemons safe to pause while gaming ─────────────────────────────
    ("Package manager daemon",  "packagekitd"),      # apt/dnf background checks
    ("KDE crash handler",       "drkonqi"),           # crash reporter, unneeded in-game
    ("Bluetooth OBEX",          "obexd"),             # BT file transfer daemon
    ("Smart card daemon",       "pcscd"),             # rarely used on gaming desktops
    ("Printer discovery",       "cups-browsed"),      # network printer scan
    # ── Audio session (suspend last — restoring audio can be slow) ────────────
    ("PipeWire media session",  "pipewire-media-session"),
]

PERFORMANCE_MODES = {
    "power_saving": (
        "Power Saving",
        "Reduces CPU governor, dirty writeback, PCIe ASPM on, NVMe min power. Battery slider works normally.",
        "battery-low-symbolic",
        "#f5c211",
    ),
    "balanced": (
        "Balanced",
        "Moderate tuning with schedutil governor, USB autosuspend, medium SATA power.",
        "media-playlist-shuffle-symbolic",
        "#3584e4",
    ),
    "performance": (
        "Performance",
        "CPU boost on, performance governor, PCIe/NVMe max performance, background trimmed.",
        "starred-symbolic",
        "#2ec27e",
    ),
}


def detect_system_mode() -> str:
    """Read the persisted Cortex mode from ~/.config/raptor-cortex-mode.
    Falls back to 'balanced' if not set."""
    try:
        with open(MODE_STATE_FILE) as f:
            mode = f.read().strip()
            if mode in PERFORMANCE_MODES:
                return mode
    except Exception:
        pass
    return "balanced"


def persist_mode(mode: str) -> None:
    """Write the current mode to ~/.config/raptor-cortex-mode."""
    try:
        os.makedirs(os.path.dirname(MODE_STATE_FILE), exist_ok=True)
        with open(MODE_STATE_FILE, "w") as f:
            f.write(mode + "\n")
    except Exception as e:
        print(f"[cortex] Could not persist mode: {e}", file=sys.stderr)


def read_meminfo():
    info = {}
    try:
        with open("/proc/meminfo") as f:
            for line in f:
                parts = line.split()
                if len(parts) >= 2:
                    key = parts[0].rstrip(":")
                    info[key] = int(parts[1]) // 1024
    except Exception:
        pass
    return info


def mem_used_mb():
    m = read_meminfo()
    total = m.get("MemTotal", 0)
    avail = m.get("MemAvailable", 0)
    return total - avail, total


def fmt_mb(mb):
    return f"{mb / 1024:.1f} GB" if mb >= 1024 else f"{mb} MB"


def get_zram_usage():
    try:
        if not os.path.exists("/sys/block/zram0"):
            return 0, 0, False
        with open("/sys/block/zram0/disksize") as f:
            total_mb = int(f.read().strip()) // (1024 * 1024)
        try:
            with open("/sys/block/zram0/mm_stat") as f:
                orig_mb = int(f.read().split()[0]) // (1024 * 1024)
        except Exception:
            orig_mb = 0
        return orig_mb, total_mb, total_mb > 0
    except Exception:
        return 0, 0, False


def get_swap_usage():
    m = read_meminfo()
    total = m.get("SwapTotal", 0)
    free  = m.get("SwapFree", 0)
    return total - free, total


def get_cpu_boost():
    try:
        with open("/sys/devices/system/cpu/cpufreq/boost") as f:
            return f.read().strip() == "1"
    except Exception:
        return None


def load_cortex_config():
    patterns = set()
    try:
        with open(CORTEX_CONFIG) as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith("#"):
                    patterns.add(line)
    except Exception:
        pass
    return patterns


def save_cortex_config(patterns):
    try:
        lines = [
            "# Raptor Cortex — services to suspend during gaming\n",
            "# This file is managed by the Raptor Cortex GUI.\n",
        ]
        for _, pattern in ALL_SERVICES:
            if pattern in patterns:
                lines.append(pattern + "\n")
        with open(CORTEX_CONFIG, "w") as f:
            f.writelines(lines)
    except Exception as e:
        print(f"[cortex] Could not save config: {e}", file=sys.stderr)


class RaptorCortexApp(Adw.Application):
    def __init__(self):
        super().__init__(application_id="io.github.cerberus9dev.RaptorCortex")
        self.connect("activate", self.on_activate)

    def on_activate(self, app):
        self.win = RaptorCortexWindow(application=app)
        self.win.present()


class RaptorCortexWindow(Adw.ApplicationWindow):
    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        self.set_title("Raptor Cortex")
        self.set_default_size(700, 940)
        self._running = False
        self._suspended_now = []
        self._cortex_patterns = load_cortex_config()
        # Read the persisted mode so the UI always reflects reality
        self._current_mode = detect_system_mode()
        self._mode_btns = {}
        self._toast_overlay = None
        self._build_ui()
        GLib.timeout_add_seconds(2, self._refresh_stats)
        self._refresh_stats()

    def _build_ui(self):
        root = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        self.set_content(root)
        root.append(Adw.HeaderBar())

        # Toast overlay wraps the scrollable content
        self._toast_overlay = Adw.ToastOverlay()
        self._toast_overlay.set_vexpand(True)
        root.append(self._toast_overlay)

        scroll = Gtk.ScrolledWindow()
        scroll.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
        scroll.set_vexpand(True)
        self._toast_overlay.set_child(scroll)

        content = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=16)
        content.set_margin_top(20)
        content.set_margin_bottom(20)
        content.set_margin_start(20)
        content.set_margin_end(20)
        scroll.set_child(content)

        self.mode_banner = Adw.Banner()
        self.mode_banner.set_revealed(True)
        self._update_mode_banner()
        content.append(self.mode_banner)

        stats_group = Adw.PreferencesGroup(title="System Memory")
        content.append(stats_group)

        ram_row = Adw.ActionRow(title="RAM Usage")
        self.ram_bar = Gtk.LevelBar()
        self.ram_bar.set_min_value(0)
        self.ram_bar.set_max_value(1)
        self.ram_bar.set_size_request(200, -1)
        self.ram_bar.set_valign(Gtk.Align.CENTER)
        self.ram_label = Gtk.Label(label="…")
        self.ram_label.add_css_class("dim-label")
        ram_row.add_suffix(self.ram_label)
        ram_row.add_suffix(self.ram_bar)
        stats_group.add(ram_row)

        self.swap_row = Adw.ActionRow(title="Swap / zram")
        self.swap_label = Gtk.Label(label="…")
        self.swap_label.add_css_class("dim-label")
        self.swap_row.add_suffix(self.swap_label)
        stats_group.add(self.swap_row)

        self.zram_row = Adw.ActionRow(title="zram compression")
        self.zram_label = Gtk.Label(label="…")
        self.zram_label.add_css_class("dim-label")
        self.zram_row.add_suffix(self.zram_label)
        stats_group.add(self.zram_row)

        self.boost_row = Adw.ActionRow(title="CPU Boost")
        self.boost_label = Gtk.Label(label="…")
        self.boost_label.add_css_class("dim-label")
        self.boost_row.add_suffix(self.boost_label)
        stats_group.add(self.boost_row)

        mode_group = Adw.PreferencesGroup(title="Performance Mode")
        mode_group.set_description(
            "Applies kernel tuning instantly — CPU, PCIe ASPM, NVMe, SATA, USB, audio power. "
            "Battery tray slider remains functional.")
        content.append(mode_group)

        ICON_FALLBACKS = {
            "power_saving": "battery-low-symbolic",
            "balanced":     "media-playlist-shuffle-symbolic",
            "performance":  "starred-symbolic",
        }

        for key, (label, desc, _, color) in PERFORMANCE_MODES.items():
            icon = Gtk.Image.new_from_icon_name(ICON_FALLBACKS[key])
            icon.set_pixel_size(20)
            icon.set_valign(Gtk.Align.CENTER)
            icon.set_margin_end(4)

            check = Gtk.Image.new_from_icon_name("object-select-symbolic")
            check.set_pixel_size(16)
            check.set_valign(Gtk.Align.CENTER)

            row = Adw.ActionRow(title=label)
            row.set_subtitle(desc)
            row.set_activatable(True)
            row.connect("activated", self._on_mode_switch, key)
            row.add_prefix(icon)
            row.add_suffix(check)
            mode_group.add(row)

            self._mode_btns[key] = (row, icon, check)

        self._refresh_mode_buttons()

        opts_group = Adw.PreferencesGroup(title="Manual Optimization Options")
        opts_group.set_description("Choose what to run when you click Optimize Memory Now.")
        content.append(opts_group)

        self.opt_caches  = self._switch_row("Drop page/dentry/inode caches",    "Immediately frees RAM",                          True)
        opts_group.add(self.opt_caches)
        self.opt_compact = self._switch_row("Memory compaction",                 "Reduces fragmentation",                          True)
        opts_group.add(self.opt_compact)
        self.opt_zram    = self._switch_row("zram recompress",                   "Re-squeeze compressed swap pages",               True)
        opts_group.add(self.opt_zram)
        self.opt_swap    = self._switch_row("Swap pressure flush",               "Push cold pages to swap temporarily",            True)
        opts_group.add(self.opt_swap)
        self.opt_oom     = self._switch_row("Adjust OOM scores",                 "Protect KDE shell; make browsers killable",      True)
        opts_group.add(self.opt_oom)
        self.opt_deep    = self._switch_row("Deep Clean (slow)",                 "Flush hugepages + NUMA + slab caches",           False)
        opts_group.add(self.opt_deep)

        cortex_group = Adw.PreferencesGroup(title="Raptor Cortex — Game Mode")
        cortex_group.set_description(
            "Selected services are suspended when any game launches and resumed when it exits.")
        content.append(cortex_group)

        self._service_switches = {}
        for name, pattern in ALL_SERVICES:
            row = Adw.SwitchRow()
            row.set_title(name)
            row.set_subtitle(f"pgrep: {pattern}")
            row.set_active(pattern in self._cortex_patterns)
            row.connect("notify::active", self._on_cortex_toggle, pattern)
            cortex_group.add(row)
            self._service_switches[pattern] = row

        self.result_group = Adw.PreferencesGroup(title="Last Optimization")
        self.result_group.set_visible(False)
        content.append(self.result_group)

        self.result_row = Adw.ActionRow()
        self.result_row.set_title("Freed")
        self.result_icon = Gtk.Image.new_from_icon_name("emblem-ok-symbolic")
        self.result_icon.add_css_class("success")
        self.result_row.add_prefix(self.result_icon)
        self.result_group.add(self.result_row)

        self.sus_group = Adw.PreferencesGroup(title="Currently Suspended")
        self.sus_group.set_visible(False)
        content.append(self.sus_group)

        self.sus_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
        self.sus_group.add(self.sus_box)

        btn_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
        btn_box.set_halign(Gtk.Align.CENTER)
        content.append(btn_box)

        self.run_btn = Gtk.Button(label="Optimize Memory Now")
        self.run_btn.add_css_class("suggested-action")
        self.run_btn.add_css_class("pill")
        self.run_btn.connect("clicked", self.on_optimize)
        btn_box.append(self.run_btn)

        self.resume_btn = Gtk.Button(label="Resume All Services")
        self.resume_btn.add_css_class("pill")
        self.resume_btn.set_sensitive(False)
        self.resume_btn.connect("clicked", self.on_resume)
        btn_box.append(self.resume_btn)

        self.spinner = Gtk.Spinner()
        btn_box.append(self.spinner)

    def _update_mode_banner(self):
        label, desc, _, _ = PERFORMANCE_MODES[self._current_mode]
        self.mode_banner.set_title(f"Active mode: {label} — {desc}")

    def _refresh_mode_buttons(self):
        for key, (row, icon, check) in self._mode_btns.items():
            is_active = (key == self._current_mode)
            # Active row: show checkmark, full opacity, not clickable (already selected)
            check.set_visible(is_active)
            icon.set_opacity(1.0 if is_active else 0.4)
            icon.set_css_classes(["accent"] if is_active else [])
            row.set_opacity(1.0 if is_active else 0.65)
            # Sensitive=False on the active row prevents re-selecting same mode,
            # but ALL inactive rows remain fully clickable.
            row.set_sensitive(not is_active)

    def _switch_row(self, title, subtitle, default):
        row = Adw.SwitchRow()
        row.set_title(title)
        row.set_subtitle(subtitle)
        row.set_active(default)
        return row

    def _on_cortex_toggle(self, row, _param, pattern):
        if row.get_active():
            self._cortex_patterns.add(pattern)
        else:
            self._cortex_patterns.discard(pattern)
        threading.Thread(target=save_cortex_config, args=(self._cortex_patterns,), daemon=True).start()

    def _on_mode_switch(self, row, mode_key):
        # Update UI immediately so it feels responsive
        self._current_mode = mode_key
        self._refresh_mode_buttons()
        self._update_mode_banner()
        # Persist the selection so next app launch reads the right mode
        persist_mode(mode_key)
        # Apply the kernel tuning in a background thread
        threading.Thread(target=self._apply_mode, args=(mode_key,), daemon=True).start()

    def _apply_mode(self, mode_key):
        ok = True

        result = subprocess.run(["sudo", HELPER, "set-mode", mode_key],
                                capture_output=True, text=True)
        if result.returncode != 0:
            ok = False

        if mode_key == "performance":
            subprocess.run(["sudo", HELPER, "1", "1", "1", "1", "0", "0", "0", "1"],
                           capture_output=True)
            subprocess.run(["sudo", HELPER, "trim-background"],
                           capture_output=True)
        elif mode_key == "balanced":
            subprocess.run(["sudo", HELPER, "1", "1", "0", "1", "0", "0", "0", "0"],
                           capture_output=True)
        elif mode_key == "power_saving":
            subprocess.run(["sudo", HELPER, "1", "0", "0", "0", "0", "0", "0", "0"],
                           capture_output=True)

        label = PERFORMANCE_MODES[mode_key][0]
        if ok:
            msg = f"Mode set to {label}"
        else:
            msg = f"{label} applied (powerprofilesctl unavailable, kernel tuning still active)"

        GLib.idle_add(self._on_mode_applied, msg)

    def _on_mode_applied(self, message):
        toast = Adw.Toast.new(message)
        toast.set_timeout(3)
        self._toast_overlay.add_toast(toast)
        self._refresh_stats()
        return False

    def _refresh_stats(self):
        used, total = mem_used_mb()
        if total > 0:
            ratio = used / total
            self.ram_bar.set_value(ratio)
            self.ram_label.set_text(f"{fmt_mb(used)} / {fmt_mb(total)}")
            if ratio > 0.85:
                self.ram_bar.remove_css_class("success")
                self.ram_bar.add_css_class("error")
            elif ratio > 0.65:
                self.ram_bar.remove_css_class("error")
                self.ram_bar.add_css_class("warning")
            else:
                self.ram_bar.remove_css_class("error")
                self.ram_bar.remove_css_class("warning")

        swap_used, swap_total = get_swap_usage()
        self.swap_label.set_text(
            f"{fmt_mb(swap_used)} / {fmt_mb(swap_total)}" if swap_total > 0 else "No swap")

        zram_orig, zram_total, zram_active = get_zram_usage()
        if zram_active:
            if zram_orig > 0:
                ratio = zram_orig / max(zram_total, 1)
                self.zram_label.set_text(f"{fmt_mb(zram_orig)} → {fmt_mb(zram_total)} ({ratio:.1f}x)")
            else:
                self.zram_label.set_text(f"{fmt_mb(zram_total)} slot, idle")
        else:
            self.zram_label.set_text("Not active")

        boost = get_cpu_boost()
        self.boost_label.set_text("Enabled" if boost else "Disabled" if boost is not None else "N/A")
        return True

    def on_optimize(self, btn):
        if self._running:
            return
        self._running = True
        self.run_btn.set_sensitive(False)
        self.spinner.start()
        opts = {
            "caches":  self.opt_caches.get_active(),
            "compact": self.opt_compact.get_active(),
            "zram":    self.opt_zram.get_active(),
            "oom":     self.opt_oom.get_active(),
            "deep":    self.opt_deep.get_active(),
            "swap":    self.opt_swap.get_active(),
        }
        before_used, before_total = mem_used_mb()
        threading.Thread(target=self._do_optimize, args=(opts, before_used, before_total), daemon=True).start()

    def _do_optimize(self, opts, before_used, before_total):
        subprocess.run([
            "sudo", HELPER,
            "1" if opts["caches"]  else "0",
            "1" if opts["compact"] else "0",
            "1" if opts["zram"]    else "0",
            "1" if opts["oom"]     else "0",
            "1" if opts["deep"]    else "0",
            "1" if opts["swap"]    else "0",
            "0", "0"
        ], capture_output=True)

        suspended = []
        for name, pattern in ALL_SERVICES:
            if pattern not in self._cortex_patterns:
                continue
            result = subprocess.run(["pgrep", "-f", pattern], capture_output=True, text=True)
            if result.returncode == 0:
                subprocess.run(["pkill", "-STOP", "-f", pattern], capture_output=True)
                suspended.append(name)

        self._suspended_now = suspended
        after_used, _ = mem_used_mb()
        freed = max(0, before_used - after_used)
        GLib.idle_add(self._show_result, before_used, before_total, after_used, freed, suspended)

    def _show_result(self, before, total, after, freed, suspended):
        self._running = False
        self.run_btn.set_sensitive(True)
        self.spinner.stop()
        self._refresh_stats()

        self.result_group.set_visible(True)
        self.result_row.set_title(f"Freed {fmt_mb(freed)}")
        self.result_row.set_subtitle(
            f"Before: {fmt_mb(before)} / {fmt_mb(total)}   After: {fmt_mb(after)} / {fmt_mb(total)}")

        if suspended:
            self.resume_btn.set_sensitive(True)
            self.sus_group.set_visible(True)
            child = self.sus_box.get_first_child()
            while child:
                nxt = child.get_next_sibling()
                self.sus_box.remove(child)
                child = nxt
            for name in suspended:
                lbl = Gtk.Label(label=f"  • {name}", xalign=0)
                lbl.add_css_class("dim-label")
                self.sus_box.append(lbl)
        else:
            self.sus_group.set_visible(False)

    def on_resume(self, btn):
        for _, pattern in ALL_SERVICES:
            if pattern in self._cortex_patterns:
                subprocess.run(["pkill", "-CONT", "-f", pattern], capture_output=True)
        self._suspended_now.clear()
        self.resume_btn.set_sensitive(False)
        self.sus_group.set_visible(False)
        threading.Thread(
            target=lambda: subprocess.run(["sudo", HELPER, "restore-background"], capture_output=True),
            daemon=True,
        ).start()


if __name__ == "__main__":
    app = RaptorCortexApp()
    sys.exit(app.run(sys.argv))
PYEOF
chmod +x /usr/bin/raptor-cortex

# ── Launcher wrapper ──────────────────────────────────────────────────────────
cat << 'EOF' > /usr/bin/raptor-cortex-launcher
#!/bin/bash
export ADW_DISABLE_PORTAL=1
exec /usr/bin/raptor-cortex "$@"
EOF
chmod +x /usr/bin/raptor-cortex-launcher

# ── .desktop entry ────────────────────────────────────────────────────────────
mkdir -p /usr/share/applications
cat << 'EOF' > /usr/share/applications/raptor-cortex.desktop
[Desktop Entry]
Version=1.1
Type=Application
Name=Raptor Cortex
GenericName=Memory & Performance Manager
Comment=Unified RAM optimization, performance mode switching, and game mode — no password required
Exec=/usr/bin/raptor-cortex-launcher
Icon=raptor-cortex
Terminal=false
Categories=X-RaptorOS;System;Settings;
Keywords=cortex;memory;ram;optimize;performance;gaming;
StartupNotify=true
X-KDE-SubstituteUID=false
EOF

echo "CORTEX_READY"
