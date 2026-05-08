#!/bin/bash
set -oue pipefail

# =============================================================================
# Raptor OS — Update Manager
# Simple Windows-style GUI: check for updates, show changelog, update + reboot
# =============================================================================

cat << 'PYEOF' > /usr/bin/raptor-update
#!/usr/bin/env python3
"""Raptor OS Update Manager"""

import gi
gi.require_version("Gtk", "4.0")
gi.require_version("Adw", "1")
from gi.repository import Gtk, Adw, GLib
import subprocess
import threading
import sys
import urllib.request

CHANGELOG_URL = "https://raw.githubusercontent.com/Cerberus9-dev/Raptor-OS/main/changelog.md"


def fetch_changelog():
    try:
        with urllib.request.urlopen(CHANGELOG_URL, timeout=8) as r:
            return r.read().decode("utf-8")
    except Exception as e:
        return f"Could not load changelog: {e}"


def check_for_updates():
    """Returns (has_update: bool, status_text: str)"""
    try:
        result = subprocess.run(
            ["rpm-ostree", "update", "--check"],
            capture_output=True, text=True, timeout=60
        )
        output = result.stdout + result.stderr
        if "No updates available" in output or result.returncode == 77:
            return False, "Your system is up to date."
        elif result.returncode == 0 or "AvailableUpdate" in output:
            return True, "A system update is available."
        else:
            return False, f"Could not determine update status."
    except subprocess.TimeoutExpired:
        return False, "Update check timed out."
    except FileNotFoundError:
        return False, "rpm-ostree not found."
    except Exception as e:
        return False, f"Error: {e}"


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
        self.set_default_size(700, 580)
        self._update_running = False
        self._has_update = False
        self._build_ui()
        # Auto-check on launch
        threading.Thread(target=self._do_check, daemon=True).start()
        # Load changelog in background
        threading.Thread(target=self._load_changelog, daemon=True).start()

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

        # ── Banner ─────────────────────────────────────────────────────────────
        banner = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=6)
        banner.set_halign(Gtk.Align.CENTER)

        self.banner_icon = Gtk.Image.new_from_icon_name("software-update-available-symbolic")
        self.banner_icon.set_pixel_size(64)
        self.banner_icon.add_css_class("accent")
        banner.append(self.banner_icon)

        title = Gtk.Label(label="<b>Raptor Update Manager</b>")
        title.set_use_markup(True)
        title.add_css_class("title-1")
        banner.append(title)

        self.subtitle = Gtk.Label(label="Checking for updates…")
        self.subtitle.add_css_class("dim-label")
        banner.append(self.subtitle)

        content.append(banner)

        # ── Status card ────────────────────────────────────────────────────────
        group = Adw.PreferencesGroup()
        content.append(group)

        self.status_row = Adw.ActionRow()
        self.status_row.set_title("System Status")
        self.status_row.set_subtitle("Checking…")

        self.status_icon = Gtk.Image.new_from_icon_name("emblem-synchronizing-symbolic")
        self.status_icon.add_css_class("accent")
        self.status_row.add_prefix(self.status_icon)

        self.check_spinner = Gtk.Spinner()
        self.check_spinner.start()
        self.status_row.add_suffix(self.check_spinner)

        group.add(self.status_row)

        # ── Changelog ──────────────────────────────────────────────────────────
        cl_group = Adw.PreferencesGroup(title="Changelog")
        cl_group.set_vexpand(True)
        content.append(cl_group)

        cl_frame = Gtk.Frame()
        cl_frame.set_vexpand(True)

        cl_scroll = Gtk.ScrolledWindow()
        cl_scroll.set_policy(Gtk.PolicyType.AUTOMATIC, Gtk.PolicyType.AUTOMATIC)
        cl_scroll.set_min_content_height(180)
        cl_scroll.set_vexpand(True)

        self.cl_view = Gtk.TextView()
        self.cl_view.set_editable(False)
        self.cl_view.set_cursor_visible(False)
        self.cl_view.set_wrap_mode(Gtk.WrapMode.WORD_CHAR)
        self.cl_view.set_margin_top(10)
        self.cl_view.set_margin_bottom(10)
        self.cl_view.set_margin_start(10)
        self.cl_view.set_margin_end(10)
        self.cl_buffer = self.cl_view.get_buffer()
        self.cl_buffer.set_text("Loading changelog…")

        cl_scroll.set_child(self.cl_view)
        cl_frame.set_child(cl_scroll)
        cl_group.add(cl_frame)

        # ── Log output ─────────────────────────────────────────────────────────
        self.log_group = Adw.PreferencesGroup(title="Update Log")
        self.log_group.set_visible(False)
        content.append(self.log_group)

        log_frame = Gtk.Frame()

        log_scroll = Gtk.ScrolledWindow()
        log_scroll.set_policy(Gtk.PolicyType.AUTOMATIC, Gtk.PolicyType.AUTOMATIC)
        log_scroll.set_min_content_height(120)

        self.log_view = Gtk.TextView()
        self.log_view.set_editable(False)
        self.log_view.set_cursor_visible(False)
        self.log_view.set_wrap_mode(Gtk.WrapMode.WORD_CHAR)
        self.log_view.set_margin_top(8)
        self.log_view.set_margin_bottom(8)
        self.log_view.set_margin_start(8)
        self.log_view.set_margin_end(8)
        self.log_view.add_css_class("monospace")
        self.log_buffer = self.log_view.get_buffer()

        log_scroll.set_child(self.log_view)
        log_frame.set_child(log_scroll)
        self.log_group.add(log_frame)

        # ── Buttons ────────────────────────────────────────────────────────────
        btn_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
        btn_box.set_halign(Gtk.Align.CENTER)
        content.append(btn_box)

        self.check_btn = Gtk.Button(label="Check Again")
        self.check_btn.add_css_class("pill")
        self.check_btn.set_sensitive(False)
        self.check_btn.connect("clicked", self.on_check_clicked)
        btn_box.append(self.check_btn)

        self.update_btn = Gtk.Button(label="Update & Reboot")
        self.update_btn.add_css_class("suggested-action")
        self.update_btn.add_css_class("pill")
        self.update_btn.set_sensitive(False)
        self.update_btn.connect("clicked", self.on_update_clicked)
        btn_box.append(self.update_btn)

        self.update_spinner = Gtk.Spinner()
        btn_box.append(self.update_spinner)

    # ── Changelog loader ───────────────────────────────────────────────────────

    def _load_changelog(self):
        text = fetch_changelog()
        GLib.idle_add(self.cl_buffer.set_text, text)

    # ── Update check ──────────────────────────────────────────────────────────

    def on_check_clicked(self, btn):
        self.check_btn.set_sensitive(False)
        self.update_btn.set_sensitive(False)
        self.check_spinner.start()
        self._set_status("Checking…", "emblem-synchronizing-symbolic", "accent")
        self.subtitle.set_text("Checking for updates…")
        threading.Thread(target=self._do_check, daemon=True).start()

    def _do_check(self):
        has_update, msg = check_for_updates()
        GLib.idle_add(self._on_check_done, has_update, msg)

    def _on_check_done(self, has_update, msg):
        self._has_update = has_update
        self.check_spinner.stop()
        self.check_btn.set_sensitive(True)

        if has_update:
            self._set_status(msg, "software-update-available-symbolic", "accent")
            self.subtitle.set_text("An update is ready to install.")
            self.banner_icon.set_from_icon_name("software-update-available-symbolic")
            self.update_btn.set_sensitive(True)
            self.update_btn.set_label("Update & Reboot")
        else:
            self._set_status(msg, "emblem-ok-symbolic", "success")
            self.subtitle.set_text("Your Raptor OS is up to date.")
            self.banner_icon.set_from_icon_name("emblem-ok-symbolic")
            self.update_btn.set_sensitive(False)

    def _set_status(self, subtitle, icon_name, css):
        self.status_row.set_subtitle(subtitle)
        self.status_icon.set_from_icon_name(icon_name)
        for c in ["success", "warning", "error", "accent"]:
            self.status_icon.remove_css_class(c)
        self.status_icon.add_css_class(css)

    # ── Update + reboot ───────────────────────────────────────────────────────

    def on_update_clicked(self, btn):
        if self._update_running:
            return

        dialog = Adw.MessageDialog(
            transient_for=self,
            heading="Update & Reboot?",
            body="Raptor OS will update and automatically reboot when complete. Save any open work first.",
        )
        dialog.add_response("cancel", "Cancel")
        dialog.add_response("go", "Update & Reboot")
        dialog.set_response_appearance("go", Adw.ResponseAppearance.SUGGESTED)
        dialog.connect("response", self._on_confirm_response)
        dialog.present()

    def _on_confirm_response(self, dialog, response):
        if response != "go":
            return
        self._update_running = True
        self.update_btn.set_sensitive(False)
        self.check_btn.set_sensitive(False)
        self.update_spinner.start()
        self.log_group.set_visible(True)
        self.log_buffer.set_text("")
        self._set_status("Updating — do not close this window…",
                         "emblem-synchronizing-symbolic", "accent")
        self.subtitle.set_text("Installing update…")
        threading.Thread(target=self._run_update, daemon=True).start()

    def _append_log(self, text):
        end = self.log_buffer.get_end_iter()
        self.log_buffer.insert(end, text)
        adj = self.log_view.get_parent().get_vadjustment()
        GLib.idle_add(lambda: adj.set_value(adj.get_upper()) or False)

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
            GLib.idle_add(self._append_log, "\nERROR: ujust not found.\n")
            GLib.idle_add(self._on_update_error, -1)
        except Exception as e:
            GLib.idle_add(self._append_log, f"\nERROR: {e}\n")
            GLib.idle_add(self._on_update_error, -1)

    def _on_update_success(self):
        self._update_running = False
        self.update_spinner.stop()
        self._set_status("Update complete! Rebooting in 10 seconds…",
                         "emblem-ok-symbolic", "success")
        self.subtitle.set_text("Update installed successfully.")
        self._append_log("\nUpdate complete. Rebooting in 10 seconds…\n")
        self._countdown(10)

    def _countdown(self, secs):
        if secs <= 0:
            subprocess.Popen(["systemctl", "reboot"])
            return
        self._set_status(
            f"Rebooting in {secs} second{'s' if secs != 1 else ''}… (close window to cancel)",
            "emblem-ok-symbolic", "success")
        GLib.timeout_add_seconds(1, lambda: self._countdown(secs - 1) or False)

    def _on_update_error(self, code):
        self._update_running = False
        self.update_spinner.stop()
        self.update_btn.set_sensitive(True)
        self.check_btn.set_sensitive(True)
        self._set_status(f"Update failed (exit code {code}). Check the log.",
                         "dialog-error-symbolic", "error")
        self.subtitle.set_text("Something went wrong.")


if __name__ == "__main__":
    app = RaptorUpdateApp()
    sys.exit(app.run(sys.argv))
PYEOF
chmod +x /usr/bin/raptor-update

# ── Wrapper launcher ───────────────────────────────────────────────────────────
cat << 'EOF' > /usr/bin/raptor-update-launcher
#!/bin/bash
export ADW_DISABLE_PORTAL=1
export DBUS_SESSION_BUS_ADDRESS="${DBUS_SESSION_BUS_ADDRESS:-unix:path=/run/user/$(id -u)/bus}"
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
