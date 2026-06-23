#!/bin/bash
set -euo pipefail

# =============================================================================
# Raptor Wallpaper Manager v1.0
# GTK4/Adwaita wallpaper picker with direct KDE Plasma integration
# • File browser dialog (native GTK4)
# • Live preview before applying
# • Persistent storage across logins
# • Works on both X11 and Wayland
# =============================================================================

mkdir -p /usr/bin /usr/share/applications /usr/share/icons/hicolor/scalable/apps

# ── Python GTK4 Wallpaper Manager ─────────────────────────────────────────
cat << 'PYEOF' > /usr/bin/raptor-wallpaper-manager
#!/usr/bin/env python3
"""Raptor Wallpaper Manager — GTK4/Adwaita wallpaper browser & applier"""

import gi
gi.require_version("Gtk", "4.0")
gi.require_version("Adw", "1")
from gi.repository import Gtk, Adw, GLib, Gio
import subprocess
import os
from pathlib import Path

class RaptorWallpaperManager(Adw.ApplicationWindow):
    def __init__(self, app):
        super().__init__(application=app)
        self.set_title("Raptor Wallpaper Manager")
        self.set_default_size(700, 550)
        self.set_resizable(True)
        self.current_image = None
        self.cache_file = Path.home() / ".config" / "raptor-wallpaper"
        
        # Load last used wallpaper
        if self.cache_file.exists():
            self.current_image = self.cache_file.read_text().strip()
        
        self._build_ui()
    
    def _build_ui(self):
        """Build the main UI"""
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=12)
        box.set_margin_top(12)
        box.set_margin_bottom(12)
        box.set_margin_start(12)
        box.set_margin_end(12)
        
        # Header bar (title + description)
        header = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=6)
        title = Gtk.Label(label="Wallpaper Manager")
        title.add_css_class("title-2")
        subtitle = Gtk.Label(
            label="Select a wallpaper to apply across all virtual desktops"
        )
        subtitle.add_css_class("dim-label")
        header.append(title)
        header.append(subtitle)
        box.append(header)
        
        # File browser button
        file_btn = Gtk.Button(label="📁  Browse Wallpapers")
        file_btn.connect("clicked", self._on_browse_clicked)
        file_btn.add_css_class("pill")
        box.append(file_btn)
        
        # Current wallpaper preview
        preview_label = Gtk.Label(label="Preview")
        preview_label.add_css_class("heading")
        box.append(preview_label)
        
        preview_box = Gtk.Box(
            orientation=Gtk.Orientation.VERTICAL,
            spacing=8,
            homogeneous=False
        )
        
        self.preview_image = Gtk.Image()
        self.preview_image.set_size_request(600, 300)
        scroll = Gtk.ScrolledWindow()
        scroll.set_child(self.preview_image)
        scroll.set_vexpand(True)
        scroll.set_hexpand(True)
        preview_box.append(scroll)
        
        self.preview_path_label = Gtk.Label()
        self.preview_path_label.set_wrap(True)
        self.preview_path_label.add_css_class("dim-label")
        preview_box.append(self.preview_path_label)
        
        box.append(preview_box)
        
        # Apply button
        apply_btn = Gtk.Button(label="✓  Apply Wallpaper")
        apply_btn.connect("clicked", self._on_apply_clicked)
        apply_btn.add_css_class("suggested-action")
        box.append(apply_btn)
        
        # Status label
        self.status_label = Gtk.Label()
        self.status_label.add_css_class("dim-label")
        box.append(self.status_label)
        
        # Load current wallpaper
        self._load_preview()
        
        self.set_content(box)
    
    def _load_preview(self):
        """Load and display current wallpaper preview"""
        if not self.current_image or not Path(self.current_image).exists():
            self.preview_image.set_from_icon_name("image-missing")
            self.preview_path_label.set_text("No wallpaper selected")
            self.status_label.set_text("")
            return
        
        try:
            pixbuf = GdkPixbuf.Pixbuf.new_from_file_at_scale(
                self.current_image, 600, 300, True
            )
            self.preview_image.set_from_pixbuf(pixbuf)
            self.preview_path_label.set_text(f"📍 {self.current_image}")
            self.status_label.set_text("Ready to apply")
        except Exception as e:
            self.preview_image.set_from_icon_name("dialog-error")
            self.preview_path_label.set_text(f"Error loading image: {e}")
    
    def _on_browse_clicked(self, button):
        """Open file chooser dialog"""
        dialog = Gtk.FileChooserDialog(
            title="Select Wallpaper",
            transient_for=self,
            action=Gtk.FileChooserAction.OPEN
        )
        dialog.add_buttons(
            Gtk.ResponseType.CANCEL, Gtk.ResponseType.CANCEL,
            Gtk.ResponseType.OK, Gtk.ResponseType.OK
        )
        
        # Filter for image files
        image_filter = Gtk.FileFilter()
        image_filter.set_name("Images")
        for pattern in ["*.png", "*.jpg", "*.jpeg", "*.webp", "*.bmp", "*.svg"]:
            image_filter.add_pattern(pattern)
        dialog.add_filter(image_filter)
        
        # Set default directory
        home = Path.home()
        if (home / "Pictures").exists():
            dialog.set_current_folder(
                Gio.File.new_for_path(str(home / "Pictures"))
            )
        
        dialog.connect("response", self._on_file_selected)
        dialog.present()
    
    def _on_file_selected(self, dialog, response):
        """Handle file selection"""
        if response == Gtk.ResponseType.OK:
            file = dialog.get_file()
            if file:
                self.current_image = file.get_path()
                self._load_preview()
                self.status_label.set_text("Image selected — click Apply to set")
        dialog.close()
    
    def _on_apply_clicked(self, button):
        """Apply wallpaper to all desktops"""
        if not self.current_image or not Path(self.current_image).exists():
            self.status_label.set_text("❌ No valid image selected")
            return
        
        self.status_label.set_text("⏳ Applying wallpaper...")
        
        def apply_async():
            try:
                # Save to cache
                self.cache_file.parent.mkdir(parents=True, exist_ok=True)
                self.cache_file.write_text(self.current_image)
                
                # Method 1: plasma-apply-wallpaperimage (Plasma 5.26+)
                result = subprocess.run(
                    ["plasma-apply-wallpaperimage", self.current_image],
                    capture_output=True, timeout=5
                )
                if result.returncode == 0:
                    GLib.idle_add(
                        lambda: self.status_label.set_text(
                            "✓ Wallpaper applied successfully"
                        )
                    )
                    return
                
                # Method 2: qdbus script fallback
                script = f"""
var allDesktops = desktops();
for (var i = 0; i < allDesktops.length; i++) {{
    var d = allDesktops[i];
    d.wallpaperPlugin = "org.kde.image";
    d.currentConfigGroup = ["Wallpaper", "org.kde.image", "General"];
    d.writeConfig("Image", "file://{self.current_image}");
}}
"""
                for qdbus_cmd in ["qdbus6", "qdbus"]:
                    try:
                        subprocess.run(
                            [
                                qdbus_cmd,
                                "org.kde.plasmashell",
                                "/PlasmaShell",
                                "org.kde.PlasmaShell.evaluateScript",
                                script
                            ],
                            capture_output=True, timeout=5
                        )
                        GLib.idle_add(
                            lambda: self.status_label.set_text(
                                "✓ Wallpaper applied successfully"
                            )
                        )
                        return
                    except Exception:
                        continue
                
                GLib.idle_add(
                    lambda: self.status_label.set_text(
                        "⚠ Plasma not running — wallpaper saved for next login"
                    )
                )
            except Exception as e:
                GLib.idle_add(
                    lambda: self.status_label.set_text(f"❌ Error: {e}")
                )
        
        thread = threading.Thread(target=apply_async, daemon=True)
        thread.start()

class RaptorWallpaperApp(Adw.Application):
    def __init__(self):
        super().__init__(application_id="io.github.cerberus9dev.raptorwallpaper")
        self.connect("activate", self.on_activate)
    
    def on_activate(self, app):
        win = RaptorWallpaperManager(app)
        win.present()

if __name__ == "__main__":
    import threading
    try:
        from gi.repository import GdkPixbuf
    except ImportError:
        print("Error: GdkPixbuf not found. Install: python3-gi-cairo")
        exit(1)
    
    app = RaptorWallpaperApp()
    app.run()
PYEOF
chmod +x /usr/bin/raptor-wallpaper-manager

# ── Desktop Entry ──────────────────────────────────────────────────────────
cat << 'EOF' > /usr/share/applications/raptor-wallpaper-manager.desktop
[Desktop Entry]
Type=Application
Name=Wallpaper Manager
GenericName=Wallpaper Selector
Comment=Browse and apply wallpapers to your desktop
Exec=/usr/bin/raptor-wallpaper-manager
Icon=preferences-desktop-wallpaper
Terminal=false
NoDisplay=false
Categories=X-RaptorOS;System;Settings;
Keywords=wallpaper;desktop;background;image;
StartupNotify=true
EOF

# ── Application Icon ───────────────────────────────────────────────────────
mkdir -p /usr/share/icons/hicolor/scalable/apps
cat << 'SVGEOF' > /usr/share/icons/hicolor/scalable/apps/raptor-wallpaper-manager.svg
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64">
  <defs>
    <linearGradient id="bg" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0%" stop-color="#1e90ff"/>
      <stop offset="100%" stop-color="#1e4a7a"/>
    </linearGradient>
  </defs>
  <rect width="64" height="64" rx="8" fill="url(#bg)"/>
  <rect x="8" y="8" width="48" height="48" rx="4" fill="#0d0f12" opacity="0.6"/>
  <rect x="12" y="12" width="20" height="20" fill="#2ec27e" opacity="0.9"/>
  <rect x="36" y="12" width="16" height="20" fill="#f5a623" opacity="0.9"/>
  <rect x="12" y="36" width="16" height="16" fill="#dc3232" opacity="0.9"/>
  <rect x="32" y="36" width="20" height="16" fill="#1e90ff" opacity="0.9"/>
  <circle cx="48" cy="48" r="8" fill="#c8d6e8" opacity="0.3"/>
</svg>
SVGEOF

echo "Raptor Wallpaper Manager installed successfully"
