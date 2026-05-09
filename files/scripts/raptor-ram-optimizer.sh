#!/bin/bash
set -e

# =============================================================================
# Raptor OS — RAM Optimizer (Raptor Cortex-class memory manager)
# No-auth optimization, Razer Cortex-style game mode with per-service toggles,
# auto-suspend on game launch via gamemode hooks, auto-resume on game exit.
# =============================================================================

# ── Privileged helper (NOPASSWD via sudoers) ──────────────────────────────────
mkdir -p /usr/lib/raptor
cat << 'EOF' > /usr/lib/raptor/ram-optimize-helper
#!/bin/bash
DO_CACHE="$1"
DO_COMPACT="$2"
DO_ZRAM="$3"
DO_GAMING="$4"
DO_OOM="$5"

if [ "$DO_CACHE" = "1" ]; then
    sync || true
    echo 3 > /proc/sys/vm/drop_caches 2>/dev/null || true
    echo 2 > /proc/sys/vm/drop_caches 2>/dev/null || true
    echo 3 > /proc/sys/vm/drop_caches 2>/dev/null || true
fi

if [ "$DO_COMPACT" = "1" ]; then
    echo 1 > /proc/sys/vm/compact_memory 2>/dev/null || true
fi

if [ "$DO_ZRAM" = "1" ]; then
    echo 3 > /proc/sys/vm/drop_caches 2>/dev/null || true
    echo recompress > /sys/block/zram0/recompress 2>/dev/null || true
    echo writeback > /sys/block/zram0/writeback 2>/dev/null || true
fi

if [ "$DO_GAMING" = "1" ]; then
    echo 1 > /sys/devices/system/cpu/cpufreq/boost 2>/dev/null || true
    powerprofilesctl set performance 2>/dev/null || true
fi

if [ "$DO_OOM" = "1" ]; then
    for proc in plasmashell kwin_wayland kwin_x11; do
        for pid in $(pgrep "$proc" 2>/dev/null || true); do
            echo -500 > /proc/$pid/oom_score_adj 2>/dev/null || true
        done
    done
fi

for proc in plasmashell kwin_wayland kwin_x11 kded6 baloo_file; do
    for pid in $(pgrep "$proc" 2>/dev/null || true); do
        kill -USR1 "$pid" 2>/dev/null || true
    done
done

CURRENT=$(cat /proc/sys/vm/swappiness 2>/dev/null || echo 80)
echo 100 > /proc/sys/vm/swappiness 2>/dev/null || true
sleep 1
echo "$CURRENT" > /proc/sys/vm/swappiness 2>/dev/null || true

exit 0
EOF
chmod +x /usr/lib/raptor/ram-optimize-helper

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
sudo /usr/lib/raptor/ram-optimize-helper 1 1 1 0 0 2>/dev/null || true
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
powerprofilesctl set balanced 2>/dev/null || true
EOF
chmod +x /usr/lib/raptor/gamemode-end

# ── sudoers NOPASSWD for helper ───────────────────────────────────────────────
mkdir -p /etc/sudoers.d
cat << 'EOF' > /etc/sudoers.d/raptor-ram-optimizer
# Raptor OS: allow all users to run the RAM optimizer helper without a password
ALL ALL=(root) NOPASSWD: /usr/lib/raptor/ram-optimize-helper
ALL ALL=(root) NOPASSWD: /usr/lib/raptor/gamemode-start
ALL ALL=(root) NOPASSWD: /usr/lib/raptor/gamemode-end
EOF
chmod 440 /etc/sudoers.d/raptor-ram-optimizer || true
visudo -cf /etc/sudoers.d/raptor-ram-optimizer || true

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
EOF

# ── Update gamemode config to use raptor hooks ────────────────────────────────
mkdir -p /etc/gamemode.d
cat << CONF > /etc/gamemode.d/raptor.ini
[general]
renice=10
inhibit_screensaver=1

[gpu]
apply_gpu_optimisations=accept-responsibility
gpu_device=0

[custom]
start=/usr/lib/raptor/gamemode-start
end=/usr/lib/raptor/gamemode-end
CONF

# ── Python GUI ────────────────────────────────────────────────────────────────
cat << 'PYEOF' > /usr/bin/raptor-ram-optimizer
#!/usr/bin/env python3
"""Raptor OS RAM Optimizer — Cortex-class memory manager"""

import gi
gi.require_version("Gtk", "4.0")
gi.require_version("Adw", "1")
from gi.repository import Gtk, Adw, GLib
import subprocess
import threading
import os
import sys

CORTEX_CONFIG = "/etc/raptor/cortex-suspend.conf"
HELPER = "/usr/lib/raptor/ram-optimize-helper"

ALL_SERVICES = [
    ("Baloo file indexer",    "baloo_file"),
    ("Akonadi server",        "akonadiserver"),
    ("KDE Connect",           "kdeconnectd"),
    ("Thumbnail generator",   "kio_thumbnail"),
    ("Activity manager",      "kactivitymanagerd"),
    ("Evolution data server", "evolution-data"),
    ("KDE wallet daemon",     "kwalletd"),
    ("Plasma geolocation",    "plasma-geolocation"),
    ("KDE sycoca builder",    "kbuildsycoca"),
    ("Zeitgeist daemon",      "zeitgeist"),
    ("GVFS metadata",         "gvfsd-metadata"),
]


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
    return f"{mb/1024:.1f} GB" if mb >= 1024 else f"{mb} MB"

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
        content = "".join(lines)
        subprocess.run(
            ["sudo", "tee", CORTEX_CONFIG],
            input=content, text=True, capture_output=True
        )
    except Exception:
        pass


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
        self.set_default_size(700, 760)
        self._running = False
        self._suspended_now = []
        self._cortex_patterns = load_cortex_config()
        self._build_ui()
        self._refresh_stats()
        GLib.timeout_add_seconds(3, self._refresh_stats)

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

        banner = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
        banner.set_halign(Gtk.Align.CENTER)
        ico = Gtk.Image.new_from_icon_name("memory")
        ico.set_pixel_size(56)
        ico.add_css_class("accent")
        banner.append(ico)
        lbl = Gtk.Label(label="<b>Raptor RAM Optimizer</b>")
        lbl.set_use_markup(True)
        lbl.add_css_class("title-1")
        banner.append(lbl)
        sub = Gtk.Label(label="Free memory, suspend bloat, and boost game performance")
        sub.add_css_class("dim-label")
        banner.append(sub)
        content.append(banner)

        stats_group = Adw.PreferencesGroup(title="Memory Status")
        content.append(stats_group)

        self.ram_row = Adw.ActionRow()
        self.ram_row.set_title("RAM Usage")
        self.ram_bar = Gtk.LevelBar()
        self.ram_bar.set_min_value(0)
        self.ram_bar.set_max_value(1)
        self.ram_bar.set_size_request(200, -1)
        self.ram_bar.set_valign(Gtk.Align.CENTER)
        self.ram_label = Gtk.Label()
        self.ram_label.set_width_chars(14)
        self.ram_label.set_xalign(1)
        self.ram_row.add_suffix(self.ram_bar)
        self.ram_row.add_suffix(self.ram_label)
        stats_group.add(self.ram_row)

        self.swap_row = Adw.ActionRow()
        self.swap_row.set_title("Swap / zram")
        self.swap_label = Gtk.Label()
        self.swap_label.add_css_class("dim-label")
        self.swap_row.add_suffix(self.swap_label)
        stats_group.add(self.swap_row)

        self.zram_row = Adw.ActionRow()
        self.zram_row.set_title("zram Compression")
        self.zram_label = Gtk.Label()
        self.zram_label.add_css_class("dim-label")
        self.zram_row.add_suffix(self.zram_label)
        stats_group.add(self.zram_row)

        opts_group = Adw.PreferencesGroup(title="Optimization Options")
        content.append(opts_group)

        self.opt_caches = self._switch_row(
            "Clear page/slab/inode caches",
            "Frees memory held by the kernel for recently-used files", True)
        opts_group.add(self.opt_caches)

        self.opt_compact = self._switch_row(
            "Compact physical memory",
            "Reduces fragmentation so large allocations succeed", True)
        opts_group.add(self.opt_compact)

        self.opt_zram = self._switch_row(
            "Recompress zram pages",
            "Re-runs compression on zram to reclaim physical RAM", True)
        opts_group.add(self.opt_zram)

        self.opt_gaming = self._switch_row(
            "Gaming mode boost",
            "Sets power profile to performance and enables CPU boost", False)
        opts_group.add(self.opt_gaming)

        self.opt_oom = self._switch_row(
            "Adjust OOM scores",
            "Makes the kernel protect your desktop session from being killed", False)
        opts_group.add(self.opt_oom)

        cortex_group = Adw.PreferencesGroup(title="Raptor Cortex — Game Mode")
        cortex_group.set_description(
            "Selected services are suspended automatically when any game launches "
            "via gamemode (Steam/Lutris) and resumed when the game exits. "
            "Toggle each service to include or exclude it.")
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
                    f"{fmt_mb(zram_orig)} data → {fmt_mb(zram_total)} allocated "
                    f"({ratio:.1f}x compression)")
            else:
                self.zram_label.set_text(
                    f"Active — {fmt_mb(zram_total)} allocated, idle")
        else:
            self.zram_label.set_text("zram not active")

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
            "gaming":  self.opt_gaming.get_active(),
            "oom":     self.opt_oom.get_active(),
        }
        before_used, before_total = mem_used_mb()
        threading.Thread(
            target=self._do_optimize,
            args=(opts, before_used, before_total),
            daemon=True
        ).start()

    def _do_optimize(self, opts, before_used, before_total):
        subprocess.run([
            "sudo", HELPER,
            "1" if opts["caches"]  else "0",
            "1" if opts["compact"] else "0",
            "1" if opts["zram"]    else "0",
            "1" if opts["gaming"]  else "0",
            "1" if opts["oom"]     else "0",
        ], capture_output=True)

        suspended = []
        for name, pattern in ALL_SERVICES:
            if pattern not in self._cortex_patterns:
                continue
            result = subprocess.run(
                ["pgrep", "-f", pattern], capture_output=True, text=True)
            if result.returncode == 0:
                subprocess.run(["pkill", "-STOP", "-f", pattern],
                                capture_output=True)
                suspended.append(name)

        self._suspended_now = suspended
        after_used, _ = mem_used_mb()
        freed = max(0, before_used - after_used)
        GLib.idle_add(self._show_result, before_used, before_total,
                      after_used, freed, suspended)

    def _show_result(self, before, total, after, freed, suspended):
        self._running = False
        self.run_btn.set_sensitive(True)
        self.spinner.stop()
        self._refresh_stats()

        self.result_group.set_visible(True)
        self.result_row.set_title(f"Freed {fmt_mb(freed)}")
        self.result_row.set_subtitle(
            f"Before: {fmt_mb(before)} / {fmt_mb(total)}   "
            f"After: {fmt_mb(after)} / {fmt_mb(total)}")

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
        for name, pattern in ALL_SERVICES:
            if pattern in self._cortex_patterns:
                subprocess.run(["pkill", "-CONT", "-f", pattern],
                                capture_output=True)
        self._suspended_now.clear()
        self.resume_btn.set_sensitive(False)
        self.sus_group.set_visible(False)
        subprocess.run(["powerprofilesctl", "set", "balanced"],
                       capture_output=True, check=False)


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
Comment=Free memory, suspend bloat, and boost game performance
Exec=/usr/bin/raptor-ram-launcher
Icon=memory
Terminal=false
Categories=X-RaptorOS;
Keywords=ram;memory;optimize;performance;gaming;raptor;cortex;
StartupNotify=true
X-KDE-SubstituteUID=false
EOF

echo "RAM_OPTIMIZER_READY"
