#!/bin/bash
set -e

# =============================================================================
# Raptor OS — RAM Optimizer v2 (Raptor Cortex-class memory manager)
# • No-auth optimization via NOPASSWD sudoers helper
# • No-login GPU profile switching via NOPASSWD sudoers helper
# • Deep Clean mode: hugepages flush, NUMA compaction, swap reclaim
# • Razer Cortex-style game mode: auto-suspend/resume on game launch
# • Per-service toggles, OOM tuning, zram recompress
# =============================================================================

# ── Privileged helper (NOPASSWD via sudoers) ──────────────────────────────────
mkdir -p /usr/lib/raptor

cat << 'EOF' > /usr/lib/raptor/ram-optimize-helper
#!/bin/bash
# Args: DO_CACHE DO_COMPACT DO_ZRAM DO_GAMING DO_OOM DO_DEEP DO_SWAP DO_THP
DO_CACHE="${1:-0}"
DO_COMPACT="${2:-0}"
DO_ZRAM="${3:-0}"
DO_GAMING="${4:-0}"
DO_OOM="${5:-0}"
DO_DEEP="${6:-0}"
DO_SWAP="${7:-0}"
DO_THP="${8:-0}"

# --- Drop page/dentry/inode caches ---
if [ "$DO_CACHE" = "1" ]; then
    sync || true
    echo 3 > /proc/sys/vm/drop_caches 2>/dev/null || true
    echo 2 > /proc/sys/vm/drop_caches 2>/dev/null || true
    echo 1 > /proc/sys/vm/drop_caches 2>/dev/null || true
fi

# --- Memory compaction (reduces fragmentation) ---
if [ "$DO_COMPACT" = "1" ]; then
    echo 1 > /proc/sys/vm/compact_memory 2>/dev/null || true
fi

# --- zram recompress (squeezes compressed pages tighter) ---
if [ "$DO_ZRAM" = "1" ]; then
    echo 3 > /proc/sys/vm/drop_caches 2>/dev/null || true
    echo recompress > /sys/block/zram0/recompress 2>/dev/null || true
    echo writeback   > /sys/block/zram0/writeback   2>/dev/null || true
fi

# --- Boost CPU for gaming ---
if [ "$DO_GAMING" = "1" ]; then
    echo 1 > /sys/devices/system/cpu/cpufreq/boost 2>/dev/null || true
    powerprofilesctl set performance 2>/dev/null || true
fi

# --- OOM score adjustments: protect KDE shell ---
if [ "$DO_OOM" = "1" ]; then
    for proc in plasmashell kwin_wayland kwin_x11 ksmserver kded6; do
        for pid in $(pgrep -x "$proc" 2>/dev/null || true); do
            echo -800 > /proc/$pid/oom_score_adj 2>/dev/null || true
        done
    done
    # Make known memory hogs more OOM-killable
    for proc in chrome chromium brave firefox; do
        for pid in $(pgrep -x "$proc" 2>/dev/null || true); do
            echo 300 > /proc/$pid/oom_score_adj 2>/dev/null || true
        done
    done
fi

# --- Deep Clean: flush hugepages, NUMA balance, reclaim slabs ---
if [ "$DO_DEEP" = "1" ]; then
    # Flush transparent hugepages back to base pages temporarily
    echo never > /sys/kernel/mm/transparent_hugepage/enabled 2>/dev/null || true
    sleep 0.5
    echo madvise > /sys/kernel/mm/transparent_hugepage/enabled 2>/dev/null || true
    # Force NUMA memory balance
    echo 1 > /proc/sys/kernel/numa_balancing 2>/dev/null || true
    # Reclaim slab/dentries aggressively then restore
    echo 3 > /proc/sys/vm/drop_caches 2>/dev/null || true
    echo 5 > /proc/sys/vm/drop_caches 2>/dev/null || true
    echo 3 > /proc/sys/vm/drop_caches 2>/dev/null || true
    # Kick memory compaction again after slab reclaim
    echo 1 > /proc/sys/vm/compact_memory 2>/dev/null || true
fi

# --- Swap reclaim: temporarily push swappiness to flush cold pages ---
if [ "$DO_SWAP" = "1" ]; then
    CURRENT=$(cat /proc/sys/vm/swappiness 2>/dev/null || echo 80)
    echo 100 > /proc/sys/vm/swappiness 2>/dev/null || true
    sleep 1
    echo "$CURRENT" > /proc/sys/vm/swappiness 2>/dev/null || true
fi

# --- THP toggle: on demand re-enables madvise mode ---
if [ "$DO_THP" = "1" ]; then
    echo madvise > /sys/kernel/mm/transparent_hugepage/enabled 2>/dev/null || true
    echo defer+madvise > /sys/kernel/mm/transparent_hugepage/defrag 2>/dev/null || true
fi

# Send signal to KDE compositor/shell to trim caches
for proc in plasmashell kwin_wayland kwin_x11 kded6 baloo_file; do
    for pid in $(pgrep "$proc" 2>/dev/null || true); do
        kill -USR1 "$pid" 2>/dev/null || true
    done
done

exit 0
EOF
chmod +x /usr/lib/raptor/ram-optimize-helper

# ── GPU profile switcher helper (no-password) ─────────────────────────────────
cat << 'EOF' > /usr/lib/raptor/gpu-profile-helper
#!/bin/bash
# Args: set-performance | set-powersave | set-auto | status
ACTION="${1:-status}"

case "$ACTION" in
    set-performance)
        touch /etc/raptor-force-performance
        rm -f /etc/raptor-force-powersave
        /usr/bin/raptor-gpu-profile.sh 2>/dev/null || true
        powerprofilesctl set performance 2>/dev/null || true
        echo 1 > /sys/devices/system/cpu/cpufreq/boost 2>/dev/null || true
        ;;
    set-powersave)
        touch /etc/raptor-force-powersave
        rm -f /etc/raptor-force-performance
        /usr/bin/raptor-gpu-profile.sh 2>/dev/null || true
        powerprofilesctl set power-saver 2>/dev/null || true
        echo 0 > /sys/devices/system/cpu/cpufreq/boost 2>/dev/null || true
        ;;
    set-auto)
        rm -f /etc/raptor-force-performance /etc/raptor-force-powersave
        /usr/bin/raptor-gpu-profile.sh 2>/dev/null || true
        powerprofilesctl set balanced 2>/dev/null || true
        ;;
    set-balanced)
        rm -f /etc/raptor-force-performance /etc/raptor-force-powersave
        powerprofilesctl set balanced 2>/dev/null || true
        echo 0 > /sys/devices/system/cpu/cpufreq/boost 2>/dev/null || true
        ;;
    status)
        PROFILE="auto"
        [ -f /etc/raptor-force-performance ] && PROFILE="performance"
        [ -f /etc/raptor-force-powersave ]   && PROFILE="powersave"
        PPCTL=$(powerprofilesctl get 2>/dev/null || echo "unknown")
        echo "$PROFILE:$PPCTL"
        ;;
    *)
        echo "Usage: gpu-profile-helper [set-performance|set-powersave|set-auto|set-balanced|status]"
        exit 1
        ;;
esac
exit 0
EOF
chmod +x /usr/lib/raptor/gpu-profile-helper

# ── gamemode hooks ────────────────────────────────────────────────────────────
cat << 'EOF' > /usr/lib/raptor/gamemode-start
#!/bin/bash
CONFIG=/etc/raptor/cortex-suspend.conf
[ -f "$CONFIG" ] || exit 0
while IFS= read -r pattern; do
    [ -z "$pattern" ] && continue
    case "$pattern" in "#"*) continue ;; esac
    pgrep -f "$pattern" > /dev/null 2>&1 && pkill -STOP -f "$pattern" 2>/dev/null || true
done < "$CONFIG"
# Full pre-game optimization
sudo /usr/lib/raptor/ram-optimize-helper 1 1 1 0 0 1 0 0 2>/dev/null || true
sudo /usr/lib/raptor/gpu-profile-helper set-performance 2>/dev/null || true
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
sudo /usr/lib/raptor/gpu-profile-helper set-auto 2>/dev/null || true
EOF
chmod +x /usr/lib/raptor/gamemode-end

# ── sudoers NOPASSWD for all raptor helpers ───────────────────────────────────
mkdir -p /etc/sudoers.d
cat << 'EOF' > /etc/sudoers.d/raptor-nopasswd
# Raptor OS: allow all users to run raptor helpers without a password prompt
ALL ALL=(root) NOPASSWD: /usr/lib/raptor/ram-optimize-helper
ALL ALL=(root) NOPASSWD: /usr/lib/raptor/gpu-profile-helper
ALL ALL=(root) NOPASSWD: /usr/lib/raptor/gamemode-start
ALL ALL=(root) NOPASSWD: /usr/lib/raptor/gamemode-end
ALL ALL=(root) NOPASSWD: /usr/bin/raptor-gpu-profile.sh
EOF
chmod 440 /etc/sudoers.d/raptor-nopasswd || true
visudo -cf /etc/sudoers.d/raptor-nopasswd || true

# ── Default cortex suspend config ─────────────────────────────────────────────
mkdir -p /etc/raptor
cat << 'EOF' > /etc/raptor/cortex-suspend.conf
# Raptor Cortex — services to suspend during gaming
# Each line is a pgrep -f pattern. Comment out with # to disable.
# This file is managed by the Raptor RAM Optimizer GUI.
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

# ── Gamemode config to use raptor hooks ───────────────────────────────────────
mkdir -p /etc/gamemode.d
cat << 'CONF' > /etc/gamemode.d/raptor.ini
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
CONF

# ── Python GUI ────────────────────────────────────────────────────────────────
cat << 'PYEOF' > /usr/bin/raptor-ram-optimizer
#!/usr/bin/env python3
"""Raptor OS RAM Optimizer v2 — Cortex-class memory manager"""

import gi
gi.require_version("Gtk", "4.0")
gi.require_version("Adw", "1")
from gi.repository import Gtk, Adw, GLib
import subprocess
import threading
import os
import sys

CORTEX_CONFIG = "/etc/raptor/cortex-suspend.conf"
HELPER        = "/usr/lib/raptor/ram-optimize-helper"
GPU_HELPER    = "/usr/lib/raptor/gpu-profile-helper"

ALL_SERVICES = [
    ("Baloo file indexer",       "baloo_file"),
    ("Akonadi server",           "akonadiserver"),
    ("KDE Connect daemon",       "kdeconnectd"),
    ("Thumbnail generator",      "kio_thumbnail"),
    ("Activity manager",         "kactivitymanagerd"),
    ("Evolution data server",    "evolution-data"),
    ("KDE wallet daemon",        "kwalletd"),
    ("Plasma geolocation",       "plasma-geolocation"),
    ("KDE sycoca builder",       "kbuildsycoca"),
    ("Zeitgeist daemon",         "zeitgeist"),
    ("GVFS metadata",            "gvfsd-metadata"),
    ("Colour management",        "colord"),
    ("PipeWire media session",   "pipewire-media-session"),
]

GPU_PROFILES = {
    "performance": "Max Performance",
    "powersave":   "Power Saving",
    "auto":        "Auto (Balanced)",
    "balanced":    "Balanced (No Boost)",
}


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


def get_thp_mode():
    try:
        with open("/sys/kernel/mm/transparent_hugepage/enabled") as f:
            line = f.read()
            import re
            m = re.search(r'\[(\w+)\]', line)
            return m.group(1) if m else "unknown"
    except Exception:
        return "unknown"


def get_gpu_profile():
    try:
        r = subprocess.run(
            ["sudo", GPU_HELPER, "status"],
            capture_output=True, text=True, timeout=5
        )
        parts = r.stdout.strip().split(":")
        raptor = parts[0] if parts else "auto"
        ppctl  = parts[1] if len(parts) > 1 else "?"
        return raptor, ppctl
    except Exception:
        return "unknown", "unknown"


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
            "# Each line is a pgrep -f pattern.\n",
            "# This file is managed by the Raptor RAM Optimizer GUI.\n",
        ]
        for _, pattern in ALL_SERVICES:
            if pattern in patterns:
                lines.append(pattern + "\n")
        with open(CORTEX_CONFIG, "w") as f:
            f.writelines(lines)
    except Exception as e:
        print(f"[raptor] Could not save cortex config: {e}", file=sys.stderr)


class RaptorRAMApp(Adw.Application):
    def __init__(self):
        super().__init__(application_id="io.github.cerberus9dev.RaptorRAM")
        self.connect("activate", self.on_activate)

    def on_activate(self, app):
        self.win = RaptorRAMWindow(application=app)
        self.win.present()


class RaptorRAMWindow(Adw.ApplicationWindow):
    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        self.set_title("Raptor RAM Optimizer")
        self.set_default_size(680, 840)
        self._running = False
        self._suspended_now = []
        self._cortex_patterns = load_cortex_config()
        self._build_ui()
        GLib.timeout_add_seconds(2, self._refresh_stats)
        self._refresh_stats()

    # ─────────────────────────── UI ────────────────────────────────────────────

    def _build_ui(self):
        root = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        self.set_content(root)
        root.append(Adw.HeaderBar())

        scroll = Gtk.ScrolledWindow()
        scroll.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
        scroll.set_vexpand(True)
        root.append(scroll)

        content = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=16)
        content.set_margin_top(20)
        content.set_margin_bottom(20)
        content.set_margin_start(20)
        content.set_margin_end(20)
        scroll.set_child(content)

        # ── Memory stats ───────────────────────────────────────────────────────
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

        self.thp_row = Adw.ActionRow(title="Transparent Hugepages")
        self.thp_label = Gtk.Label(label="…")
        self.thp_label.add_css_class("dim-label")
        self.thp_row.add_suffix(self.thp_label)
        stats_group.add(self.thp_row)

        # ── GPU profile switcher ───────────────────────────────────────────────
        gpu_group = Adw.PreferencesGroup(title="GPU / Power Profile")
        gpu_group.set_description(
            "Switch GPU and CPU power profiles instantly — no login required.")
        content.append(gpu_group)

        self.gpu_status_row = Adw.ActionRow(title="Current Profile")
        self.gpu_status_label = Gtk.Label(label="…")
        self.gpu_status_label.add_css_class("dim-label")
        self.gpu_status_row.add_suffix(self.gpu_status_label)
        gpu_group.add(self.gpu_status_row)

        for key, label in GPU_PROFILES.items():
            btn = Gtk.Button(label=label)
            btn.add_css_class("pill")
            if key == "performance":
                btn.add_css_class("destructive-action")
            elif key == "auto":
                btn.add_css_class("suggested-action")
            btn.connect("clicked", self._on_gpu_profile, key)
            row = Adw.ActionRow(title=label)
            row.set_subtitle({
                "performance": "Boost enabled, maximum GPU power — gaming/rendering",
                "powersave":   "Boost off, GPU in low-power mode — battery/quiet",
                "auto":        "Balanced profile, boost managed by gamemode",
                "balanced":    "Balanced, no boost at all — cool desktop",
            }.get(key, ""))
            row.add_suffix(btn)
            gpu_group.add(row)

        # ── Optimization options ───────────────────────────────────────────────
        opts_group = Adw.PreferencesGroup(title="Optimization Options")
        opts_group.set_description(
            "Choose what to run when you click Optimize Now.")
        content.append(opts_group)

        self.opt_caches = self._switch_row(
            "Drop page/dentry/inode caches",
            "Immediately frees RAM used for file system caches", True)
        opts_group.add(self.opt_caches)

        self.opt_compact = self._switch_row(
            "Memory compaction",
            "Reduces fragmentation — helps after many allocations", True)
        opts_group.add(self.opt_compact)

        self.opt_zram = self._switch_row(
            "zram recompress",
            "Re-squeezes compressed swap pages to save more RAM", True)
        opts_group.add(self.opt_zram)

        self.opt_swap = self._switch_row(
            "Swap pressure flush",
            "Briefly raises swappiness to push cold pages to swap, then restores", True)
        opts_group.add(self.opt_swap)

        self.opt_gaming = self._switch_row(
            "Enable gaming mode (CPU boost + performance profile)",
            "Use before launching a game manually — gamemode handles this automatically", False)
        opts_group.add(self.opt_gaming)

        self.opt_oom = self._switch_row(
            "Adjust OOM scores",
            "Protects KDE shell; makes browsers more killable under memory pressure", True)
        opts_group.add(self.opt_oom)

        self.opt_deep = self._switch_row(
            "Deep Clean (slow — flushes hugepages + NUMA + all slab caches)",
            "Thorough but takes 2–5 seconds; best before a long gaming session", False)
        opts_group.add(self.opt_deep)

        self.opt_thp = self._switch_row(
            "Reset transparent hugepages to madvise",
            "Re-applies madvise mode if something changed it", False)
        opts_group.add(self.opt_thp)

        # ── Cortex ────────────────────────────────────────────────────────────
        cortex_group = Adw.PreferencesGroup(title="Raptor Cortex — Game Mode")
        cortex_group.set_description(
            "Selected services are suspended automatically when any game launches "
            "via gamemode (Steam/Lutris) and resumed when the game exits.")
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

        # ── Result ────────────────────────────────────────────────────────────
        self.result_group = Adw.PreferencesGroup(title="Last Result")
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

        # ── Buttons ───────────────────────────────────────────────────────────
        btn_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
        btn_box.set_halign(Gtk.Align.CENTER)
        content.append(btn_box)

        self.run_btn = Gtk.Button(label="Optimize Now")
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

    # ─────────────────────────── helpers ───────────────────────────────────────

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
        threading.Thread(
            target=save_cortex_config,
            args=(self._cortex_patterns,),
            daemon=True
        ).start()

    def _on_gpu_profile(self, btn, profile_key):
        threading.Thread(
            target=lambda: subprocess.run(
                ["sudo", GPU_HELPER, f"set-{profile_key}"],
                capture_output=True
            ),
            daemon=True
        ).start()
        GLib.timeout_add_seconds(1, self._refresh_stats)

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
            f"{fmt_mb(swap_used)} used / {fmt_mb(swap_total)} total"
            if swap_total > 0 else "No swap configured")

        zram_orig, zram_total, zram_active = get_zram_usage()
        if zram_active:
            if zram_orig > 0:
                ratio = zram_orig / max(zram_total, 1)
                self.zram_label.set_text(
                    f"{fmt_mb(zram_orig)} data → {fmt_mb(zram_total)} slot "
                    f"({ratio:.1f}x compression)")
            else:
                self.zram_label.set_text(f"Active — {fmt_mb(zram_total)} slot, idle")
        else:
            self.zram_label.set_text("zram not active")

        boost = get_cpu_boost()
        if boost is None:
            self.boost_label.set_text("not available")
        else:
            self.boost_label.set_text("Enabled" if boost else "Disabled (saves power)")

        self.thp_label.set_text(get_thp_mode())

        threading.Thread(target=self._refresh_gpu_async, daemon=True).start()

        return True

    def _refresh_gpu_async(self):
        raptor, ppctl = get_gpu_profile()
        label = GPU_PROFILES.get(raptor, raptor)
        GLib.idle_add(
            self.gpu_status_label.set_text, f"{label}  ·  power-profiles: {ppctl}"
        )

    # ─────────────────────────── optimize ──────────────────────────────────────

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
            "gaming":  self.opt_gaming.get_active(),
            "oom":     self.opt_oom.get_active(),
            "deep":    self.opt_deep.get_active(),
            "swap":    self.opt_swap.get_active(),
            "thp":     self.opt_thp.get_active(),
        }
        before_used, before_total = mem_used_mb()
        threading.Thread(
            target=self._do_optimize,
            args=(opts, before_used, before_total),
            daemon=True,
        ).start()

    def _do_optimize(self, opts, before_used, before_total):
        subprocess.run([
            "sudo", HELPER,
            "1" if opts["caches"]  else "0",
            "1" if opts["compact"] else "0",
            "1" if opts["zram"]    else "0",
            "1" if opts["gaming"]  else "0",
            "1" if opts["oom"]     else "0",
            "1" if opts["deep"]    else "0",
            "1" if opts["swap"]    else "0",
            "1" if opts["thp"]     else "0",
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
            target=lambda: subprocess.run(
                ["sudo", GPU_HELPER, "set-auto"], capture_output=True
            ),
            daemon=True,
        ).start()


if __name__ == "__main__":
    app = RaptorRAMApp()
    sys.exit(app.run(sys.argv))
PYEOF
chmod +x /usr/bin/raptor-ram-optimizer

# ── Wrapper launcher ───────────────────────────────────────────────────────────
cat << 'EOF' > /usr/bin/raptor-ram-launcher
#!/bin/bash
export ADW_DISABLE_PORTAL=1
exec /usr/bin/raptor-ram-optimizer "$@"
EOF
chmod +x /usr/bin/raptor-ram-launcher

# ── .desktop entry ─────────────────────────────────────────────────────────────
mkdir -p /usr/share/applications
cat << 'EOF' > /usr/share/applications/raptor-ram-optimizer.desktop
[Desktop Entry]
Version=1.1
Type=Application
Name=Raptor RAM Optimizer
GenericName=Memory Optimizer
Comment=Free memory, suspend bloat, switch GPU profiles — no password required
Exec=/usr/bin/raptor-ram-launcher
Icon=memory
Terminal=false
Categories=X-RaptorOS;
Keywords=ram;memory;optimize;performance;gaming;gpu;profile;raptor;cortex;
StartupNotify=true
X-KDE-SubstituteUID=false
EOF

echo "RAM_OPTIMIZER_READY"
