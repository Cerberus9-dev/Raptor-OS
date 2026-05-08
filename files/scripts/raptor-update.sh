#!/bin/bash
set -oue pipefail

# ═══════════════════════════════════════════════════════════════════════════════
# Raptor OS — Update Manager installer
# Installs the Python GUI, wrapper launcher, custom icon, and .desktop entry.
# Must run AFTER raptor-hud.sh (which creates the X-RaptorOS menu category).
# ═══════════════════════════════════════════════════════════════════════════════

# ── Python GUI ─────────────────────────────────────────────────────────────────
cat << 'PYEOF' > /usr/bin/raptor-update
#!/usr/bin/env python3
"""Raptor OS Update Manager — GUI updater using ujust update"""

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
        self.set_title("Raptor Update Manager")
        self.set_default_size(720, 560)
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

        # ── Hero banner ────────────────────────────────────────────────────────
        banner = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=6)
        banner.set_halign(Gtk.Align.CENTER)

        icon = Gtk.Image.new_from_icon_name("raptor-update")
        icon.set_pixel_size(72)
        icon.add_css_class("accent")
        banner.append(icon)

        title = Gtk.Label(label="<b>Raptor Update Manager</b>")
        title.set_use_markup(True)
        title.add_css_class("title-1")
        banner.append(title)

        sub = Gtk.Label(label="Keep your Raptor OS image up to date with one click")
        sub.add_css_class("dim-label")
        banner.append(sub)

        content.append(banner)

        # ── Status card ────────────────────────────────────────────────────────
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

        # ── Log output ─────────────────────────────────────────────────────────
        log_frame = Gtk.Frame()
        log_frame.set_vexpand(True)

        log_scroll = Gtk.ScrolledWindow()
        log_scroll.set_policy(Gtk.PolicyType.AUTOMATIC, Gtk.PolicyType.AUTOMATIC)
        log_scroll.set_min_content_height(200)

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
        self._append_log("Welcome to Raptor Update Manager.\nClick 'Check & Update' to begin.\n")

        log_scroll.set_child(self.log_view)
        log_frame.set_child(log_scroll)
        content.append(log_frame)

        # ── Buttons ────────────────────────────────────────────────────────────
        btn_row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
        btn_row.set_halign(Gtk.Align.CENTER)
        content.append(btn_row)

        self.update_btn = Gtk.Button(label="Check & Update")
        self.update_btn.add_css_class("suggested-action")
        self.update_btn.add_css_class("pill")
        self.update_btn.connect("clicked", self.on_update_clicked)
        btn_row.append(self.update_btn)

        self.reboot_btn = Gtk.Button(label="Reboot Now")
        self.reboot_btn.add_css_class("destructive-action")
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
        self._set_status(
            "Updating...",
            "This may take several minutes - do not close this window",
            "emblem-synchronizing-symbolic",
            "accent",
        )
        GLib.idle_add(self._append_log, "\n-------------------------------------\n")
        GLib.idle_add(self._append_log, "Starting Raptor OS update (ujust update)...\n")
        GLib.idle_add(self._append_log, "-------------------------------------\n\n")
        threading.Thread(target=self._run_update, daemon=True).start()

    def _run_update(self):
        try:
            process = subprocess.Popen(
                ["ujust", "update"],
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                text=True,
                bufsize=1,
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
            GLib.idle_add(self._append_log,
                "\nERROR: 'ujust' not found. Are you running Raptor OS?\n")
            GLib.idle_add(self._on_update_error, -1)
        except Exception as e:
            GLib.idle_add(self._append_log, f"\nERROR: {e}\n")
            GLib.idle_add(self._on_update_error, -1)

    def _on_update_success(self):
        self._update_running = False
        self.spinner.stop()
        self.spinner.set_visible(False)
        self.update_btn.set_sensitive(True)
        self._append_log("\n-------------------------------------\n")
        self._append_log("Update complete! Reboot to apply changes.\n")
        self._append_log("-------------------------------------\n")
        self._set_status(
            "Update Complete",
            "Reboot to apply the latest Raptor OS image",
            "emblem-ok-symbolic",
            "success",
        )
        self.reboot_btn.set_visible(True)
        self.reboot_btn.set_sensitive(True)

    def _on_update_error(self, code):
        self._update_running = False
        self.spinner.stop()
        self.spinner.set_visible(False)
        self.update_btn.set_sensitive(True)
        self._append_log("\n-------------------------------------\n")
        self._append_log(f"Update failed (exit code {code}).\n")
        self._append_log("-------------------------------------\n")
        self._set_status(
            "Update Failed",
            f"Something went wrong (exit code {code}). Check the log above.",
            "dialog-error-symbolic",
            "error",
        )

    def on_reboot_clicked(self, btn):
        dialog = Adw.MessageDialog(
            transient_for=self,
            heading="Reboot Now?",
            body="Your system will reboot to apply the update.\nSave any open work first.",
        )
        dialog.add_response("cancel", "Cancel")
        dialog.add_response("reboot", "Reboot")
        dialog.set_response_appearance("reboot", Adw.ResponseAppearance.DESTRUCTIVE)
        dialog.connect(
            "response",
            lambda d, r: subprocess.Popen(["systemctl", "reboot"]) if r == "reboot" else None,
        )
        dialog.present()


if __name__ == "__main__":
    app = RaptorUpdateApp()
    sys.exit(app.run(sys.argv))
PYEOF
chmod +x /usr/bin/raptor-update

# ── Wrapper launcher ───────────────────────────────────────────────────────────
# Avoids inline env= parsing bugs in KDE Plasma's Exec= handler.
# Does NOT force GDK_BACKEND — let GTK4 auto-detect Wayland vs X11.
# ADW_DISABLE_PORTAL stops libadwaita trying to talk to a GNOME portal
# that doesn't exist on Plasma, which caused silent launch failures.
cat << 'EOF' > /usr/bin/raptor-update-launcher
#!/bin/bash
export ADW_DISABLE_PORTAL=1
exec /usr/bin/raptor-update "$@"
EOF
chmod +x /usr/bin/raptor-update-launcher

# ── Custom icon ────────────────────────────────────────────────────────────────
mkdir -p /usr/share/icons/hicolor/scalable/apps
cat << 'EOF' > /usr/share/icons/hicolor/scalable/apps/raptor-update.svg
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="64" height="64">
  <circle cx="32" cy="32" r="30" fill="#1a1a2e" stroke="#33ff33" stroke-width="2"/>
  <line x1="32" y1="14" x2="32" y2="42" stroke="#33ff33" stroke-width="5" stroke-linecap="round"/>
  <polyline points="20,30 32,44 44,30" stroke="#33ff33" stroke-width="5"
            stroke-linecap="round" stroke-linejoin="round" fill="none"/>
  <rect x="18" y="48" width="28" height="4" rx="2" fill="#33ff33"/>
</svg>
EOF

mkdir -p /usr/share/icons/hicolor/48x48/apps \
         /usr/share/icons/hicolor/256x256/apps
ln -sf /usr/share/icons/hicolor/scalable/apps/raptor-update.svg \
       /usr/share/icons/hicolor/48x48/apps/raptor-update.svg
ln -sf /usr/share/icons/hicolor/scalable/apps/raptor-update.svg \
       /usr/share/icons/hicolor/256x256/apps/raptor-update.svg

gtk-update-icon-cache -f /usr/share/icons/hicolor/ 2>/dev/null || true

# ── .desktop entry ─────────────────────────────────────────────────────────────
# Categories=X-RaptorOS; only — no extra standard categories.
# raptor-hud.sh already created the X-RaptorOS menu so this will appear there.
mkdir -p /usr/share/applications
cat << 'EOF' > /usr/share/applications/raptor-update.desktop
[Desktop Entry]
Version=1.1
Type=Application
Name=Raptor Update Manager
GenericName=System Update Manager
Comment=Check and install Raptor OS system updates
Exec=/usr/bin/raptor-update-launcher
Icon=raptor-update
Terminal=false
Categories=X-RaptorOS;
Keywords=update;upgrade;system;raptor;ostree;bazzite;
StartupNotify=true
X-KDE-SubstituteUID=false
EOF

echo "UPDATE_MANAGER_READY"
