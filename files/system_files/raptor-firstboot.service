#!/bin/bash
# raptor-update.sh
# BlueBuild script module — installs the Raptor OS Update Manager.
# Writes the Python GUI app, launcher wrapper, icon, and .desktop entry.

set -euo pipefail

# ── Python GUI application ────────────────────────────────────────────────────
cat > /usr/bin/raptor-update << 'PYEOF'
#!/usr/bin/env python3
"""Raptor OS Update Manager — GTK4/libadwaita GUI for rpm-ostree updates."""

import gi
gi.require_version("Gtk", "4.0")
gi.require_version("Adw", "1")
from gi.repository import Gtk, Adw, GLib

import os
import re
import sys
import threading
import subprocess
import urllib.request

# ── Constants ────────────────────────────────────────────────────────────────

APP_ID       = "io.github.cerberus9dev.RaptorUpdate"
CHANGELOG_URL = (
    "https://raw.githubusercontent.com/Cerberus9-dev/Raptor-OS/main/CHANGELOG.md"
)
ANSI_RE = re.compile(r"\x1b(?:\[[0-9;]*[mGKHF]|\][^\x07]*\x07)|\r")


# ── Helpers ──────────────────────────────────────────────────────────────────

def _strip_ansi(text: str) -> str:
    return ANSI_RE.sub("", text)


def fetch_changelog() -> str:
    try:
        with urllib.request.urlopen(CHANGELOG_URL, timeout=10) as resp:
            return resp.read().decode("utf-8")
    except Exception as exc:
        return f"(Could not load changelog: {exc})"


def check_for_updates() -> tuple[bool, str]:
    """Return (has_update, human_readable_message)."""
    try:
        result = subprocess.run(
            ["rpm-ostree", "update", "--check"],
            capture_output=True,
            text=True,
            timeout=90,
        )
        combined = result.stdout + result.stderr
        # rc=77 means "nothing to update" for rpm-ostree
        if result.returncode == 77 or "No updates available" in combined:
            return False, "Your system is up to date."
        if "AvailableUpdate" in combined or result.returncode == 0:
            return True, "A system update is available."
        return False, "Could not determine update status."
    except subprocess.TimeoutExpired:
        return False, "Update check timed out — try again later."
    except FileNotFoundError:
        return False, "rpm-ostree not found on this system."
    except Exception as exc:
        return False, f"Unexpected error: {exc}"


# ── Main window ──────────────────────────────────────────────────────────────

class RaptorUpdateWindow(Adw.ApplicationWindow):

    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        self.set_title("Raptor Update Manager")
        self.set_default_size(720, 640)
        self.set_resizable(True)

        self._update_running  = False
        self._has_update      = False
        self._reboot_cancelled = False

        self._build_ui()
        self._start_check()
        threading.Thread(target=self._load_changelog, daemon=True).start()

    # ── UI construction ──────────────────────────────────────────────────────

    def _build_ui(self):
        root = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        self.set_content(root)

        # Header bar
        header = Adw.HeaderBar()
        root.append(header)

        # Scrollable content area
        scroll = Gtk.ScrolledWindow()
        scroll.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
        scroll.set_vexpand(True)
        root.append(scroll)

        content = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=20)
        content.set_margin_top(28)
        content.set_margin_bottom(28)
        content.set_margin_start(28)
        content.set_margin_end(28)
        scroll.set_child(content)

        # ── Hero banner ──────────────────────────────────────────────────────
        hero = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
        hero.set_halign(Gtk.Align.CENTER)

        self._hero_icon = Gtk.Image.new_from_icon_name(
            "software-update-available-symbolic"
        )
        self._hero_icon.set_pixel_size(72)
        self._hero_icon.add_css_class("accent")
        hero.append(self._hero_icon)

        title_lbl = Gtk.Label(label="<b>Raptor Update Manager</b>")
        title_lbl.set_use_markup(True)
        title_lbl.add_css_class("title-1")
        hero.append(title_lbl)

        self._subtitle_lbl = Gtk.Label(label="Checking for updates…")
        self._subtitle_lbl.add_css_class("dim-label")
        hero.append(self._subtitle_lbl)

        content.append(hero)

        # ── Status card ──────────────────────────────────────────────────────
        status_group = Adw.PreferencesGroup(title="System Status")
        content.append(status_group)

        self._status_row = Adw.ActionRow()
        self._status_row.set_title("Update Status")
        self._status_row.set_subtitle("Checking…")

        self._status_icon = Gtk.Image.new_from_icon_name(
            "emblem-synchronizing-symbolic"
        )
        self._status_icon.add_css_class("accent")
        self._status_row.add_prefix(self._status_icon)

        self._check_spinner = Gtk.Spinner()
        self._check_spinner.start()
        self._status_row.add_suffix(self._check_spinner)

        status_group.add(self._status_row)

        # ── Changelog ────────────────────────────────────────────────────────
        cl_group = Adw.PreferencesGroup(title="Changelog")
        cl_group.set_vexpand(True)
        content.append(cl_group)

        cl_scroll = Gtk.ScrolledWindow()
        cl_scroll.set_policy(Gtk.PolicyType.AUTOMATIC, Gtk.PolicyType.AUTOMATIC)
        cl_scroll.set_min_content_height(180)
        cl_scroll.set_vexpand(True)

        self._cl_view = Gtk.TextView()
        self._cl_view.set_editable(False)
        self._cl_view.set_cursor_visible(False)
        self._cl_view.set_wrap_mode(Gtk.WrapMode.WORD_CHAR)
        self._cl_view.set_margin_top(10)
        self._cl_view.set_margin_bottom(10)
        self._cl_view.set_margin_start(12)
        self._cl_view.set_margin_end(12)
        self._cl_buffer = self._cl_view.get_buffer()
        self._cl_buffer.set_text("Loading changelog…")

        cl_frame = Gtk.Frame()
        cl_frame.set_vexpand(True)
        cl_frame.set_child(cl_scroll)
        cl_scroll.set_child(self._cl_view)
        cl_group.add(cl_frame)

        # ── Update log (hidden until an update runs) ──────────────────────────
        self._log_group = Adw.PreferencesGroup(title="Update Log")
        self._log_group.set_visible(False)
        self._log_group.set_vexpand(True)
        content.append(self._log_group)

        log_scroll = Gtk.ScrolledWindow()
        log_scroll.set_policy(Gtk.PolicyType.AUTOMATIC, Gtk.PolicyType.AUTOMATIC)
        log_scroll.set_min_content_height(180)
        log_scroll.set_vexpand(True)
        self._log_scroll = log_scroll

        self._log_view = Gtk.TextView()
        self._log_view.set_editable(False)
        self._log_view.set_cursor_visible(False)
        self._log_view.set_wrap_mode(Gtk.WrapMode.WORD_CHAR)
        self._log_view.set_margin_top(8)
        self._log_view.set_margin_bottom(8)
        self._log_view.set_margin_start(8)
        self._log_view.set_margin_end(8)
        self._log_view.add_css_class("monospace")
        self._log_buffer = self._log_view.get_buffer()

        log_frame = Gtk.Frame()
        log_frame.set_vexpand(True)
        log_frame.set_child(log_scroll)
        log_scroll.set_child(self._log_view)
        self._log_group.add(log_frame)

        # ── Action buttons ────────────────────────────────────────────────────
        btn_row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
        btn_row.set_halign(Gtk.Align.CENTER)
        content.append(btn_row)

        self._check_btn = Gtk.Button(label="Check Again")
        self._check_btn.add_css_class("pill")
        self._check_btn.set_sensitive(False)
        self._check_btn.connect("clicked", self._on_check_clicked)
        btn_row.append(self._check_btn)

        self._update_btn = Gtk.Button(label="Update & Reboot")
        self._update_btn.add_css_class("suggested-action")
        self._update_btn.add_css_class("pill")
        self._update_btn.set_sensitive(False)
        self._update_btn.connect("clicked", self._on_update_clicked)
        btn_row.append(self._update_btn)

        self._cancel_reboot_btn = Gtk.Button(label="Cancel Reboot")
        self._cancel_reboot_btn.add_css_class("pill")
        self._cancel_reboot_btn.set_visible(False)
        self._cancel_reboot_btn.connect("clicked", self._on_cancel_reboot_clicked)
        btn_row.append(self._cancel_reboot_btn)

        self._update_spinner = Gtk.Spinner()
        btn_row.append(self._update_spinner)

    # ── Changelog ────────────────────────────────────────────────────────────

    def _load_changelog(self):
        text = fetch_changelog()
        GLib.idle_add(self._cl_buffer.set_text, text)

    # ── Update check ─────────────────────────────────────────────────────────

    def _start_check(self):
        self._check_spinner.start()
        self._set_status("Checking…", "emblem-synchronizing-symbolic", "accent")
        threading.Thread(target=self._do_check, daemon=True).start()

    def _on_check_clicked(self, _btn):
        self._check_btn.set_sensitive(False)
        self._update_btn.set_sensitive(False)
        self._subtitle_lbl.set_text("Checking for updates…")
        self._start_check()

    def _do_check(self):
        has_update, msg = check_for_updates()
        GLib.idle_add(self._on_check_done, has_update, msg)

    def _on_check_done(self, has_update: bool, msg: str):
        self._has_update = has_update
        self._check_spinner.stop()
        self._check_btn.set_sensitive(True)

        if has_update:
            self._set_status(msg, "software-update-available-symbolic", "accent")
            self._subtitle_lbl.set_text("An update is ready to install.")
            self._hero_icon.set_from_icon_name("software-update-available-symbolic")
            self._update_btn.set_sensitive(True)
        else:
            self._set_status(msg, "emblem-ok-symbolic", "success")
            self._subtitle_lbl.set_text("Raptor OS is up to date.")
            self._hero_icon.set_from_icon_name("emblem-ok-symbolic")
            self._update_btn.set_sensitive(False)

    def _set_status(self, subtitle: str, icon_name: str, css_class: str):
        self._status_row.set_subtitle(subtitle)
        self._status_icon.set_from_icon_name(icon_name)
        for cls in ("success", "warning", "error", "accent"):
            self._status_icon.remove_css_class(cls)
        self._status_icon.add_css_class(css_class)

    # ── Confirm & run update ──────────────────────────────────────────────────

    def _on_update_clicked(self, _btn):
        if self._update_running:
            return
        dialog = Adw.MessageDialog(
            transient_for=self,
            heading="Update & Reboot?",
            body=(
                "Raptor OS will download and apply the latest update, "
                "then reboot automatically.\n\n"
                "Save any open work before continuing."
            ),
        )
        dialog.add_response("cancel", "Cancel")
        dialog.add_response("go", "Update & Reboot")
        dialog.set_response_appearance("go", Adw.ResponseAppearance.SUGGESTED)
        dialog.connect("response", self._on_confirm_response)
        dialog.present()

    def _on_confirm_response(self, _dialog, response: str):
        if response != "go":
            return
        self._update_running   = True
        self._reboot_cancelled = False
        self._update_btn.set_sensitive(False)
        self._check_btn.set_sensitive(False)
        self._update_spinner.start()
        self._log_group.set_visible(True)
        self._log_buffer.set_text("")
        self._set_status(
            "Updating — do not close this window…",
            "emblem-synchronizing-symbolic",
            "accent",
        )
        self._subtitle_lbl.set_text("Installing update…")
        threading.Thread(target=self._run_update, daemon=True).start()

    # ── Live log output ───────────────────────────────────────────────────────

    def _append_log(self, text: str):
        end_iter = self._log_buffer.get_end_iter()
        self._log_buffer.insert(end_iter, text)
        adj = self._log_scroll.get_vadjustment()
        adj.set_value(adj.get_upper() - adj.get_page_size())

    def _run_update(self):
        try:
            proc = subprocess.Popen(
                ["script", "-q", "-c", "rpm-ostree update", "/dev/null"],
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                text=True,
                bufsize=1,
                env={**os.environ, "TERM": "xterm-256color"},
            )
            for line in proc.stdout:
                clean = _strip_ansi(line)
                if clean:
                    GLib.idle_add(self._append_log, clean)
            proc.stdout.close()
            returncode = proc.wait()
            if returncode == 0:
                GLib.idle_add(self._on_update_success)
            else:
                GLib.idle_add(self._on_update_error, returncode)
        except FileNotFoundError:
            GLib.idle_add(self._append_log, "\nERROR: rpm-ostree not found.\n")
            GLib.idle_add(self._on_update_error, -1)
        except Exception as exc:
            GLib.idle_add(self._append_log, f"\nERROR: {exc}\n")
            GLib.idle_add(self._on_update_error, -1)

    # ── Post-update / reboot countdown ───────────────────────────────────────

    def _on_update_success(self):
        self._update_running = False
        self._update_spinner.stop()
        self._append_log("\n✓ Update complete. Rebooting in 15 seconds…\n")
        self._set_status(
            "Update complete! Rebooting in 15 seconds…",
            "emblem-ok-symbolic",
            "success",
        )
        self._subtitle_lbl.set_text("Update installed successfully.")
        self._cancel_reboot_btn.set_visible(True)
        self._tick_countdown(15)

    def _tick_countdown(self, remaining: int):
        if self._reboot_cancelled:
            return
        if remaining <= 0:
            try:
                subprocess.Popen(["systemctl", "reboot"])
            except Exception as exc:
                GLib.idle_add(self._append_log, f"\nERROR triggering reboot: {exc}\n")
            return
        suffix = "s" if remaining != 1 else ""
        self._set_status(
            f"Rebooting in {remaining} second{suffix}… (click Cancel Reboot to stop)",
            "emblem-ok-symbolic",
            "success",
        )
        GLib.timeout_add_seconds(1, lambda: self._tick_countdown(remaining - 1) or False)

    def _on_cancel_reboot_clicked(self, _btn):
        self._reboot_cancelled = True
        self._cancel_reboot_btn.set_visible(False)
        self._check_btn.set_sensitive(True)
        self._set_status(
            "Reboot cancelled — reboot manually when ready.",
            "emblem-ok-symbolic",
            "success",
        )

    def _on_update_error(self, code: int):
        self._update_running = False
        self._update_spinner.stop()
        self._update_btn.set_sensitive(True)
        self._check_btn.set_sensitive(True)
        self._set_status(
            f"Update failed (exit code {code}). See the log for details.",
            "dialog-error-symbolic",
            "error",
        )
        self._subtitle_lbl.set_text("Something went wrong.")


# ── Application ───────────────────────────────────────────────────────────────

class RaptorUpdateApp(Adw.Application):
    def __init__(self):
        super().__init__(application_id=APP_ID)
        self.connect("activate", self._on_activate)

    def _on_activate(self, app):
        win = RaptorUpdateWindow(application=app)
        win.present()


if __name__ == "__main__":
    sys.exit(RaptorUpdateApp().run(sys.argv))
PYEOF
chmod +x /usr/bin/raptor-update

# ── Launcher wrapper (fixes portal / D-Bus issues on some desktops) ───────────
cat > /usr/bin/raptor-update-launcher << 'EOF'
#!/bin/bash
export ADW_DISABLE_PORTAL=1
export DBUS_SESSION_BUS_ADDRESS="${DBUS_SESSION_BUS_ADDRESS:-unix:path=/run/user/$(id -u)/bus}"
exec /usr/bin/raptor-update "$@"
EOF
chmod +x /usr/bin/raptor-update-launcher

# ── App icon (SVG) ────────────────────────────────────────────────────────────
ICON_DIR="/usr/share/icons/hicolor/scalable/apps"
mkdir -p "$ICON_DIR"

cat > "$ICON_DIR/raptor-update.svg" << 'EOF'
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="64" height="64">
  <!-- Background circle -->
  <circle cx="32" cy="32" r="30" fill="#1a1a2e" stroke="#4a9eff" stroke-width="2"/>
  <!-- Down-arrow shaft -->
  <line x1="32" y1="12" x2="32" y2="40"
        stroke="#4a9eff" stroke-width="5" stroke-linecap="round"/>
  <!-- Down-arrow head -->
  <polyline points="20,28 32,42 44,28"
            stroke="#4a9eff" stroke-width="5"
            stroke-linecap="round" stroke-linejoin="round" fill="none"/>
  <!-- Base bar -->
  <rect x="18" y="48" width="28" height="4" rx="2" fill="#4a9eff"/>
</svg>
EOF

# Symlink to raster sizes (icon themes fall back to SVG automatically)
for size in 48x48 128x128 256x256; do
    mkdir -p "/usr/share/icons/hicolor/${size}/apps"
    ln -sf "$ICON_DIR/raptor-update.svg" \
           "/usr/share/icons/hicolor/${size}/apps/raptor-update.svg"
done

gtk-update-icon-cache -f /usr/share/icons/hicolor/ 2>/dev/null || true

# ── .desktop entry ────────────────────────────────────────────────────────────
mkdir -p /usr/share/applications
cat > /usr/share/applications/raptor-update.desktop << 'EOF'
[Desktop Entry]
Version=1.1
Type=Application
Name=Raptor Update Manager
GenericName=System Updater
Comment=Check for and install Raptor OS system updates
Exec=/usr/bin/raptor-update-launcher
Icon=raptor-update
Terminal=false
Categories=System;Settings;X-RaptorOS;
Keywords=update;upgrade;system;raptor;ostree;bazzite;
StartupNotify=true
X-KDE-SubstituteUID=false
EOF

echo "raptor-update: installation complete."
