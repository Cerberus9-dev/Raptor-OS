#!/bin/bash
# raptor-browser-choice.sh
# First-boot browser selection dialog.
# v2.0: stamp moved to user-writable path; Wayland-safe (no DISPLAY needed).
#
# Runs as part of raptor-firstboot.service (user service) after Plasma is up.
# Stamp at ~/.local/share/raptor/browser-choice-done prevents re-running.
# "Decide Later" does NOT write the stamp — dialog re-appears next session.

set -euo pipefail

STAMP_FILE="${HOME}/.local/share/raptor/browser-choice-done"
LOG_TAG="raptor-browser-choice"

log() { logger -t "${LOG_TAG}" -- "$*"; }
err() { logger -t "${LOG_TAG}" -p user.err -- "$*"; }

# ── Guard ─────────────────────────────────────────────────────────────────────
if [[ -f "${STAMP_FILE}" ]]; then
    log "Browser choice already made — skipping."
    exit 0
fi

# ── Prerequisite check ────────────────────────────────────────────────────────
if ! command -v zenity &>/dev/null; then
    err "zenity not found — cannot show browser dialog. Writing stamp to avoid loop."
    mkdir -p "$(dirname "${STAMP_FILE}")" && touch "${STAMP_FILE}"
    exit 0
fi

# ── Dialog ────────────────────────────────────────────────────────────────────
CHOICE=$(
    zenity \
        --list \
        --title="Welcome to Raptor OS" \
        --text="<b>Choose your default web browser:</b>\n\nFirefox is already installed.\nBrave will be downloaded from Flathub (~100 MB)." \
        --radiolist \
        --column="" \
        --column="Browser" \
        --column="Notes" \
        TRUE  "Firefox" "Fast, private, already installed" \
        FALSE "Brave"   "Chromium-based, privacy-focused" \
        --width=440 --height=280 \
        --ok-label="Confirm" \
        --cancel-label="Keep Firefox" \
        2>/dev/null
) || true

case "${CHOICE:-}" in
    Firefox|"")
        # Empty = cancelled/closed dialog = keep Firefox as default
        log "Firefox selected or dialog dismissed — keeping Firefox."
        xdg-settings set default-web-browser firefox.desktop 2>/dev/null \
            || xdg-settings set default-web-browser org.mozilla.firefox.desktop 2>/dev/null \
            || true
        ;;
    Brave)
        log "User selected Brave — installing Flatpak…"
        if ! flatpak install -y --noninteractive flathub com.brave.Browser \
                >> /tmp/raptor-browser-install.log 2>&1; then
            err "Brave Flatpak installation failed."
            zenity --error \
                --title="Browser Installation Failed" \
                --text="Brave could not be installed.\nFirefox has been kept as the default.\n\nCheck your internet connection." \
                --width=340 2>/dev/null || true
            # Write stamp so we don't loop on failure — user can re-select later
            mkdir -p "$(dirname "${STAMP_FILE}")" && touch "${STAMP_FILE}"
            exit 1
        fi
        xdg-settings set default-web-browser com.brave.Browser.desktop 2>/dev/null || true
        log "Brave installed and set as default."
        ;;
    *)
        err "Unexpected choice: '${CHOICE}'"
        exit 1
        ;;
esac

# ── Write stamp ───────────────────────────────────────────────────────────────
mkdir -p "$(dirname "${STAMP_FILE}")"
touch "${STAMP_FILE}"
log "Browser choice complete."
