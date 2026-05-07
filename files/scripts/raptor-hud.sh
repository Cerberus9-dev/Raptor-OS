#!/bin/bash
set -oue pipefail
 
# Apply Neon Green Visuals system-wide
mkdir -p /etc/skel/.config
cat << 'EOF' > /etc/skel/.config/kdeglobals
[General]
ColorScheme=BreezeDark
AccentColor=51,255,51
accentColorFromWallpaper=false
EOF
 
# Also apply to existing users
for dir in /root /home/*; do
    if [ -d "$dir" ]; then
        mkdir -p "$dir/.config"
        cat << 'EOF' > "$dir/.config/kdeglobals"
[General]
ColorScheme=BreezeDark
AccentColor=51,255,51
accentColorFromWallpaper=false
EOF
    fi
done
 
# KDE theme autostart fix
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
 
# Create theme apply script
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
 
# Copy autostart to existing users
for dir in /root /home/*; do
    if [ -d "$dir" ]; then
        mkdir -p "$dir/.config/autostart"
        cp /etc/skel/.config/autostart/raptor-theme.desktop "$dir/.config/autostart/" 2>/dev/null || true
    fi
done
 
# Create profile switcher script
cat << 'EOF' > /usr/bin/raptor-profile-switcher.sh
#!/bin/bash
 
CURRENT_GPU="Auto"
[ -f /etc/raptor-force-performance ] && CURRENT_GPU="Max Performance"
[ -f /etc/raptor-force-powersave ] && CURRENT_GPU="Power Saving"
 
CHOICE=$(zenity --list \
  --title="Raptor OS Profile Switcher" \
  --text="Current GPU profile: $CURRENT_GPU\n\nSelect a new profile:" \
  --radiolist \
  --column="" --column="Profile" --column="Description" \
  TRUE "Auto" "Automatically detect and optimize for your GPU" \
  FALSE "Max Performance" "Maximum GPU performance, higher power usage" \
  FALSE "Power Saving" "Reduced GPU usage, better battery life" \
  --width=600 --height=350)
 
if [ "$CHOICE" = "Max Performance" ]; then
    sudo touch /etc/raptor-force-performance
    sudo rm -f /etc/raptor-force-powersave
    /usr/bin/raptor-gpu-profile.sh
    zenity --question --title="Raptor OS" --text="Max Performance profile applied.\nLog out now to apply changes?" && qdbus org.kde.ksmserver /KSMServer logout 0 0 0
 
elif [ "$CHOICE" = "Power Saving" ]; then
    sudo touch /etc/raptor-force-powersave
    sudo rm -f /etc/raptor-force-performance
    /usr/bin/raptor-gpu-profile.sh
    zenity --question --title="Raptor OS" --text="Power Saving profile applied.\nLog out now to apply changes?" && qdbus org.kde.ksmserver /KSMServer logout 0 0 0
 
elif [ "$CHOICE" = "Auto" ]; then
    sudo rm -f /etc/raptor-force-performance
    sudo rm -f /etc/raptor-force-powersave
    /usr/bin/raptor-gpu-profile.sh
    zenity --question --title="Raptor OS" --text="Auto profile applied.\nLog out now to apply changes?" && qdbus org.kde.ksmserver /KSMServer logout 0 0 0
fi
EOF
chmod +x /usr/bin/raptor-profile-switcher.sh
 
# Create app menu entry for profile switcher
mkdir -p /usr/share/applications
cat << 'EOF' > /usr/share/applications/raptor-profile-switcher.desktop
[Desktop Entry]
Type=Application
Name=Raptor Profile Switcher
Comment=Switch between GPU performance profiles
Exec=/usr/bin/raptor-profile-switcher.sh
Icon=preferences-system-performance
Terminal=false
Categories=System;Settings;
Keywords=gpu;performance;power;profile;
EOF
 
# Create RAM optimizer script
cat << 'EOF' > /usr/bin/raptor-ram-optimizer.sh
#!/bin/bash
 
BEFORE=$(free -h | grep Mem | awk '{print $3}')
 
zenity --question \
  --title="Raptor RAM Optimizer" \
  --text="Current RAM usage: $BEFORE\n\nThis will:\n• Clear page cache\n• Compact memory\n• Free up inactive RAM\n\nContinue?" \
  --width=350
 
if [ $? != 0 ]; then exit 0; fi
 
# Clear page cache
sync
echo 3 | sudo tee /proc/sys/vm/drop_caches > /dev/null
 
# Compact memory
echo 1 | sudo tee /proc/sys/vm/compact_memory > /dev/null 2>/dev/null || true
 
zenity --question \
  --title="Raptor RAM Optimizer" \
  --text="Would you like to free up RAM by suspending background apps?" \
  --width=350
 
if [ $? = 0 ]; then
    pkill -STOP -f "baloo" 2>/dev/null || true
    pkill -STOP -f "tracker" 2>/dev/null || true
fi
 
AFTER=$(free -h | grep Mem | awk '{print $3}')
 
zenity --info \
  --title="Raptor RAM Optimizer" \
  --text="Done!\n\nBefore: $BEFORE\nAfter:  $AFTER" \
  --width=300
EOF
chmod +x /usr/bin/raptor-ram-optimizer.sh
 
# Create app menu entry for RAM optimizer
cat << 'EOF' > /usr/share/applications/raptor-ram-optimizer.desktop
[Desktop Entry]
Type=Application
Name=Raptor RAM Optimizer
Comment=Free up RAM and optimize memory usage
Exec=/usr/bin/raptor-ram-optimizer.sh
Icon=preferences-system-performance
Terminal=false
Categories=System;Settings;
Keywords=ram;memory;optimize;performance;
EOF
 
# Create GPU profile script
cat << 'EOF' > /usr/bin/raptor-gpu-profile.sh
#!/bin/bash
if lspci | grep -i "VGA\|3D\|Display" | grep -qi "nvidia"; then
    GPU_VENDOR="nvidia"
elif lspci | grep -i "VGA\|3D\|Display" | grep -qi "amd\|radeon\|ati"; then
    GPU_VENDOR="amd"
elif lspci | grep -i "VGA\|3D\|Display" | grep -qi "intel"; then
    GPU_VENDOR="intel"
else
    GPU_VENDOR="unknown"
fi
 
IS_IGPU=false
if lspci | grep -i "VGA\|3D\|Display" | grep -qi "intel"; then
    IS_IGPU=true
fi
if lspci -v | grep -i "VGA\|3D\|Display" -A5 | grep -qi \
    "cezanne\|renoir\|lucienne\|rembrandt\|mendocino\|integrated\|apu"; then
    IS_IGPU=true
fi
 
mkdir -p /etc/environment.d
 
COMMON_UNITY_VARS="WINE_LARGE_ADDRESS_AWARE=1
PROTON_FORCE_LARGE_ADDRESS_AWARE=1
STAGING_SHARED_MEMORY=1"
 
if [ -f /etc/raptor-force-performance ]; then
    cat << ENVEOF > /etc/environment.d/raptor-gpu.conf
RADV_PERFTEST=gpl
AMD_VULKAN_ICD=RADV
mesa_glthread=true
MESA_SHADER_CACHE_DISABLE=false
__GL_SHADER_DISK_CACHE=1
__GL_SHADER_DISK_CACHE_SKIP_CLEANUP=1
PROTON_ENABLE_NVAPI=1
$COMMON_UNITY_VARS
ENVEOF
 
elif [ -f /etc/raptor-force-powersave ]; then
    cat << ENVEOF > /etc/environment.d/raptor-gpu.conf
mesa_glthread=false
MESA_SHADER_CACHE_DISABLE=true
$COMMON_UNITY_VARS
ENVEOF
 
elif [ "$GPU_VENDOR" = "nvidia" ]; then
    cat << ENVEOF > /etc/environment.d/raptor-gpu.conf
__GL_SHADER_DISK_CACHE=1
__GL_SHADER_DISK_CACHE_SKIP_CLEANUP=1
PROTON_ENABLE_NVAPI=1
__NV_PRIME_RENDER_OFFLOAD=1
$COMMON_UNITY_VARS
ENVEOF
 
elif [ "$GPU_VENDOR" = "amd" ] && [ "$IS_IGPU" = true ]; then
    cat << ENVEOF > /etc/environment.d/raptor-gpu.conf
AMD_VULKAN_ICD=RADV
mesa_glthread=true
MESA_SHADER_CACHE_DISABLE=false
$COMMON_UNITY_VARS
ENVEOF
 
elif [ "$GPU_VENDOR" = "amd" ]; then
    cat << ENVEOF > /etc/environment.d/raptor-gpu.conf
RADV_PERFTEST=gpl
AMD_VULKAN_ICD=RADV
mesa_glthread=true
MESA_SHADER_CACHE_DISABLE=false
$COMMON_UNITY_VARS
ENVEOF
 
elif [ "$GPU_VENDOR" = "intel" ]; then
    cat << ENVEOF > /etc/environment.d/raptor-gpu.conf
MESA_LOADER_DRIVER_OVERRIDE=iris
LIBGL_DRI3_DISABLE=0
vblank_mode=0
mesa_glthread=true
$COMMON_UNITY_VARS
ENVEOF
 
else
    cat << ENVEOF > /etc/environment.d/raptor-gpu.conf
mesa_glthread=true
MESA_SHADER_CACHE_DISABLE=false
$COMMON_UNITY_VARS
ENVEOF
fi
EOF
chmod +x /usr/bin/raptor-gpu-profile.sh
 
# Create systemd service for GPU detection at boot
cat << 'EOF' > /usr/lib/systemd/system/raptor-gpu-profile.service
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
EOF
 
# Make browser choice script executable
chmod +x /usr/bin/raptor-browser-choice.sh 2>/dev/null || true
 
# ─────────────────────────────────────────────────────────────
# Raptor Update Center
# ─────────────────────────────────────────────────────────────
 
cat << 'PYEOF' > /usr/bin/raptor-update
#!/usr/bin/env python3
"""Raptor OS Update Center — GUI updater using ujust update"""
 
import gi
gi.require_version("Gtk", "4.0")
gi.require_version("Adw", "1")
from gi.repository import Gtk, Adw, GLib, Pango
import subprocess
import threading
import sys
 
class RaptorUpdateApp(Adw.Application):
    def __init__(self):
        super().__init__(application_id="io.github.cerberus9dev.RaptorUpdate")
        self.connect("activate", self.on_activate)
 
    def on_activate(self, app):
        self.win = RaptorUpdateWindow(application=app)
        self.win.present()
 
 
class RaptorUpdateWindow(Adw.ApplicationWindow):
    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        self.set_title("Raptor Update Center")
        self.set_default_size(700, 520)
        self._update_running = False
        self._build_ui()
 
    def _build_ui(self):
        root = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        self.set_content(root)
 
        header = Adw.HeaderBar()
        root.append(header)
 
        content = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=16)
        content.set_margin_top(24)
        content.set_margin_bottom(24)
        content.set_margin_start(24)
        content.set_margin_end(24)
        root.append(content)
 
        # Hero
        banner = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=6)
        banner.set_halign(Gtk.Align.CENTER)
        icon = Gtk.Image.new_from_icon_name("software-update-available-symbolic")
        icon.set_pixel_size(64)
        icon.add_css_class("accent")
        banner.append(icon)
        title = Gtk.Label(label="<b>Raptor Update Center</b>")
        title.set_use_markup(True)
        title.add_css_class("title-1")
        banner.append(title)
        sub = Gtk.Label(label="Keep your system up to date with one click")
        sub.add_css_class("dim-label")
        banner.append(sub)
        content.append(banner)
 
        # Status card
        group = Adw.PreferencesGroup()
        content.append(group)
        self.status_row = Adw.ActionRow()
        self.status_row.set_title("System Status")
        self.status_row.set_subtitle("Ready to check for updates")
        self.status_icon = Gtk.Image.new_from_icon_name("emblem-ok-symbolic")
        self.status_icon.add_css_class("success")
        self.status_row.add_prefix(self.status_icon)
        self.spinner = Gtk.Spinner()
        self.spinner.set_visible(False)
        self.status_row.add_suffix(self.spinner)
        group.add(self.status_row)
 
        # Log
        log_frame = Gtk.Frame()
        log_frame.set_vexpand(True)
        log_scroll = Gtk.ScrolledWindow()
        log_scroll.set_policy(Gtk.PolicyType.AUTOMATIC, Gtk.PolicyType.AUTOMATIC)
        log_scroll.set_min_content_height(180)
        self.log_view = Gtk.TextView()
        self.log_view.set_editable(False)
        self.log_view.set_cursor_visible(False)
        self.log_view.set_wrap_mode(Gtk.WrapMode.WORD_CHAR)
        self.log_view.set_margin_top(8)
        self.log_view.set_margin_bottom(8)
        self.log_view.set_margin_start(8)
        self.log_view.set_margin_end(8)
        self.log_view.add_css_class("monospace")
        self.log_view.override_font(Pango.FontDescription.from_string("Monospace 9"))
        self.log_buffer = self.log_view.get_buffer()
        self._append_log("Welcome to Raptor Update Center.\nClick 'Check & Update' to begin.\n")
        log_scroll.set_child(self.log_view)
        log_frame.set_child(log_scroll)
        content.append(log_frame)
 
        # Buttons
        btn_row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
        btn_row.set_halign(Gtk.Align.CENTER)
        content.append(btn_row)
 
        self.update_btn = Gtk.Button(label="Check & Update")
        self.update_btn.add_css_class("suggested-action")
        self.update_btn.add_css_class("pill")
        self.update_btn.connect("clicked", self.on_update_clicked)
        btn_row.append(self.update_btn)
 
        self.reboot_btn = Gtk.Button(label="Reboot Now")
        self.reboot_btn.add_css_class("pill")
        self.reboot_btn.set_sensitive(False)
        self.reboot_btn.set_visible(False)
        self.reboot_btn.connect("clicked", self.on_reboot_clicked)
        btn_row.append(self.reboot_btn)
 
        clear_btn = Gtk.Button(label="Clear Log")
        clear_btn.add_css_class("pill")
        clear_btn.connect("clicked", lambda _: self.log_buffer.set_text(""))
        btn_row.append(clear_btn)
 
    def _append_log(self, text):
        end = self.log_buffer.get_end_iter()
        self.log_buffer.insert(end, text)
        adj = self.log_view.get_parent().get_vadjustment()
        GLib.idle_add(lambda: adj.set_value(adj.get_upper()) or False)
 
    def _set_status(self, title, subtitle, icon_name, css_class):
        GLib.idle_add(self._do_set_status, title, subtitle, icon_name, css_class)
 
    def _do_set_status(self, title, subtitle, icon_name, css_class):
        self.status_row.set_title(title)
        self.status_row.set_subtitle(subtitle)
        self.status_icon.set_from_icon_name(icon_name)
        for cls in ["success", "warning", "error", "accent"]:
            self.status_icon.remove_css_class(cls)
        self.status_icon.add_css_class(css_class)
 
    def on_update_clicked(self, btn):
        if self._update_running:
            return
        self._update_running = True
        self.update_btn.set_sensitive(False)
        self.reboot_btn.set_visible(False)
        self.spinner.set_visible(True)
        self.spinner.start()
        self._set_status("Updating...", "This may take several minutes", "emblem-synchronizing-symbolic", "accent")
        GLib.idle_add(self._append_log, "\n─────────────────────────────────────\n")
        GLib.idle_add(self._append_log, "Starting Raptor OS update...\n")
        GLib.idle_add(self._append_log, "─────────────────────────────────────\n\n")
        threading.Thread(target=self._run_update, daemon=True).start()
 
    def _run_update(self):
        try:
            process = subprocess.Popen(
                ["ujust", "update"],
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                text=True,
                bufsize=1
            )
            for line in iter(process.stdout.readline, ""):
                GLib.idle_add(self._append_log, line)
            process.stdout.close()
            rc = process.wait()
            if rc == 0:
                GLib.idle_add(self._on_update_success)
            else:
                GLib.idle_add(self._on_update_error, rc)
        except FileNotFoundError:
            GLib.idle_add(self._append_log, "\nERROR: 'ujust' not found. Are you on Raptor OS?\n")
            GLib.idle_add(self._on_update_error, -1)
        except Exception as e:
            GLib.idle_add(self._append_log, f"\nERROR: {e}\n")
            GLib.idle_add(self._on_update_error, -1)
 
    def _on_update_success(self):
        self._update_running = False
        self.spinner.stop()
        self.spinner.set_visible(False)
        self.update_btn.set_sensitive(True)
        self._append_log("\n─────────────────────────────────────\n")
        self._append_log("✓ Update complete! Reboot to apply changes.\n")
        self._append_log("─────────────────────────────────────\n")
        self._set_status("Update Complete", "Reboot to apply the latest Raptor OS image", "emblem-ok-symbolic", "success")
        self.reboot_btn.set_visible(True)
        self.reboot_btn.set_sensitive(True)
 
    def _on_update_error(self, code):
        self._update_running = False
        self.spinner.stop()
        self.spinner.set_visible(False)
        self.update_btn.set_sensitive(True)
        self._append_log(f"\n─────────────────────────────────────\n")
        self._append_log(f"✗ Update failed (exit code {code}).\n")
        self._append_log("─────────────────────────────────────\n")
        self._set_status("Update Failed", f"Something went wrong (exit code {code})", "dialog-error-symbolic", "error")
 
    def on_reboot_clicked(self, btn):
        dialog = Adw.MessageDialog(
            transient_for=self,
            heading="Reboot Now?",
            body="Your system will reboot to apply the update. Save any open work first."
        )
        dialog.add_response("cancel", "Cancel")
        dialog.add_response("reboot", "Reboot")
        dialog.set_response_appearance("reboot", Adw.ResponseAppearance.DESTRUCTIVE)
        dialog.connect("response", lambda d, r: subprocess.Popen(["systemctl", "reboot"]) if r == "reboot" else None)
        dialog.present()
 
 
if __name__ == "__main__":
    app = RaptorUpdateApp()
    sys.exit(app.run(sys.argv))
PYEOF
chmod +x /usr/bin/raptor-update
 
# Desktop entry for Raptor Update Center
cat << 'EOF' > /usr/share/applications/raptor-update.desktop
[Desktop Entry]
Name=Raptor Update Center
Comment=Check and install Raptor OS system updates
Exec=raptor-update
Icon=software-update-available
Terminal=false
Type=Application
Categories=System;Settings;
Keywords=update;upgrade;system;raptor;
StartupNotify=true
EOF
 
echo "HUD_READY"
