#!/bin/bash
set -oue pipefail

# ── DNS ───────────────────────────────────────────────────────────────────────
mkdir -p /etc/systemd/resolved.conf.d
cat << 'CONF' > /etc/systemd/resolved.conf.d/dns.conf
[Resolve]
DNS=1.1.1.1 1.0.0.1
FallbackDNS=8.8.8.8 8.8.4.4
CONF

# ── WiFi power management ─────────────────────────────────────────────────────
mkdir -p /etc/NetworkManager/conf.d
cat << 'CONF' > /etc/NetworkManager/conf.d/raptor-wifi.conf
[connection]
wifi.powersave=2
[device]
wifi.scan-rand-mac-address=no
CONF

# ── Firefox memory optimization ───────────────────────────────────────────────
mkdir -p /usr/lib/firefox/defaults/pref \
         /usr/lib64/firefox/defaults/pref

for FIREFOX_DIR in /usr/lib/firefox /usr/lib64/firefox; do
    [ -d "$FIREFOX_DIR" ] || continue
    cat << 'CONF' > "$FIREFOX_DIR/mozilla.cfg"
// Firefox memory optimization
lockPref("browser.cache.memory.capacity", 16384);
lockPref("browser.cache.memory.max_entry_size", 256);
lockPref("browser.sessionhistory.max_entries", 3);
lockPref("browser.sessionhistory.max_total_viewers", 0);
lockPref("browser.tabs.unloadOnLowMemory", true);
lockPref("browser.low_commit_space_threshold_mb", 512);
lockPref("javascript.options.mem.max", 256);
lockPref("javascript.options.mem.gc_incremental_slice_ms", 5);
lockPref("javascript.options.mem.high_water_mark", 128);
lockPref("javascript.options.mem.gc_high_frequency_time_limit_ms", 500);
lockPref("browser.tabs.firefox-view", false);
lockPref("toolkit.telemetry.enabled", false);
lockPref("toolkit.telemetry.unified", false);
lockPref("gfx.webrender.all", true);
lockPref("media.hardware-video-decoding.enabled", true);
lockPref("media.ffmpeg.vaapi.enabled", true);
lockPref("browser.backgroundt
