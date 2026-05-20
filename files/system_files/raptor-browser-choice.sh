#!/bin/bash
# raptor-browser-choice.sh
# Presents a first-boot browser selection dialog and sets the default browser.
# Runs once; guarded by a stamp file so it never re-runs.
#
# Supported choices: Firefox (pre-installed RPM), Brave (Flatpak on demand)

set -euo pipefail

STAMP_FILE="/var/lib/raptor/browser-choice-done"
LOG_TAG="raptor-browser-choice"

log()  { logger -t "$LOG_TAG" -- "$*"; }
err()  { logger -t "$LOG_TAG" -p user.err -- "$*"; }

# ── Guard ────────────────────────────────────────────────────────────────────
if [[ -f "$STAMP_FILE" ]]; then
    log "Browser choice already made — skipping."
    exit 0
fi

# ── Prerequisite check ───────────────────────────────────────────────────────
if ! command -v zenity &>/dev/null; then
    err "zenity not found; cannot show browser dialog."
    exit 1
fi

# ── Dialog ───────────────────────────────────────────────────────────────────
CHOICE=$(zenity \
    --list \
    --title="Welcome to Raptor OS" \
    --text="<b>Choose your default web browser:</b>\n\nFirefox is already installed.\nBrave will be downloaded from Flathub." \
    --radiolist \
    --column="" \
    --column="Browser" \
    --column="Notes" \
    TRUE  "Firefox" "Fast, private, pre-installed" \
    FALSE "Brave"   "Chromium-based, privacy-focused" \
    --width=420 --height=260 \
    --ok-label="Confirm" \
    --cancel-label="Decide Later" \
    2>/dev/null) || true

case "${CHOICE:-}" in
    Firefox)
        log "User selected Firefox."
        xdg-settings set default-web-browser org.mozilla.firefox.desktop
        ;;
    Brave)
        log "User selected Brave — installing Flatpak…"
        if ! flatpak install -y --noninteractive flathub com.brave.Browser; then
            err "Brave Flatpak installation failed."
            zenity --error \
                --title="Installation Failed" \
                --text="Brave could not be installed.\nFirefox has been kept as the default." \
                --width=320 2>/dev/null || true
            exit 1
        fi
        xdg-settings set default-web-browser com.brave.Browser.desktop
        log "Brave installed and set as default."
        ;;
    "")
        # User clicked "Decide Later" or closed the dialog — not an error.
        # Do NOT write the stamp file so the dialog appears next session.
        log "Browser choice deferred by user."
        exit 0
        ;;
    *)
        err "Unexpected choice value: '${CHOICE}'"
        exit 1
        ;;
esac

# ── Write stamp ──────────────────────────────────────────────────────────────
mkdir -p "$(dirname "$STAMP_FILE")"
touch "$STAMP_FILE"
log "Browser choice complete."
