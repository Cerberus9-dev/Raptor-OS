#!/bin/bash
# raptor-browser-choice.sh  v3.0
# First-boot browser selection dialog for Raptor OS.
#
# Features:
#  - Three browser options: Firefox (pre-installed), Brave, Chrome
#  - Network connectivity check before attempting Flatpak download
#  - Zenity progress dialog during download (~100-150 MB)
#  - Retry prompt on failure rather than silently falling back
#  - Idempotent — stamp prevents re-running after a successful choice
#  - "Keep Firefox" cancel = valid choice, stamp written, dialog never repeats
#
# Runs as part of raptor-firstboot.service (user service) after Plasma is up.
# Stamp: ~/.local/share/raptor/browser-choice-done

set -euo pipefail

STAMP_FILE="${HOME}/.local/share/raptor/browser-choice-done"
LOG_TAG="raptor-browser-choice"
INSTALL_LOG="/tmp/raptor-browser-install.log"

log()  { logger -t "${LOG_TAG}" -- "$*";              }
err()  { logger -t "${LOG_TAG}" -p user.err -- "$*";  }
info() { logger -t "${LOG_TAG}" -p user.info -- "$*"; }

# ── Guard: already chosen ─────────────────────────────────────────────────────
if [[ -f "${STAMP_FILE}" ]]; then
    log "Browser choice already made — skipping."
    exit 0
fi

# ── Prerequisite: zenity must be available ────────────────────────────────────
if ! command -v zenity &>/dev/null; then
    err "zenity not found — cannot show browser dialog. Writing stamp to avoid loop."
    mkdir -p "$(dirname "${STAMP_FILE}")" && touch "${STAMP_FILE}"
    exit 0
fi

# ── Helper: write stamp and exit cleanly ──────────────────────────────────────
finish() {
    mkdir -p "$(dirname "${STAMP_FILE}")"
    touch "${STAMP_FILE}"
    log "Browser choice complete. Stamp written."
}

# ── Helper: check network before spending time on a doomed download ───────────
check_network() {
    if ! curl --silent --max-time 5 --head https://flathub.org >/dev/null 2>&1; then
        zenity --error \
            --title="No Internet Connection" \
            --text="Raptor OS needs an internet connection to download your chosen browser.\n\nFirefox (already installed) will be kept as the default.\nYou can re-run this setup from the Raptor welcome app later." \
            --width=400 2>/dev/null || true
        return 1
    fi
    return 0
}

# ── Helper: install a Flatpak with a progress dialog ─────────────────────────
install_with_progress() {
    local flatpak_id="$1"
    local display_name="$2"
    local size_hint="$3"   # e.g. "~120 MB"

    info "Starting Flatpak install: ${flatpak_id}"

    # Run the install in the background, pipe progress updates to zenity
    (
        flatpak install -y --noninteractive flathub "${flatpak_id}" \
            >> "${INSTALL_LOG}" 2>&1
        echo "100"
    ) | zenity --progress \
            --title="Installing ${display_name}" \
            --text="Downloading ${display_name} from Flathub (${size_hint})…\n\nThis may take a few minutes depending on your internet speed." \
            --pulsate \
            --auto-close \
            --no-cancel \
            --width=420 2>/dev/null || true

    # Verify install succeeded regardless of the progress dialog result
    if flatpak info "${flatpak_id}" &>/dev/null; then
        info "${flatpak_id} installed successfully"
        return 0
    else
        err "${flatpak_id} install failed — see ${INSTALL_LOG}"
        return 1
    fi
}

# ── Helper: set the XDG default browser ───────────────────────────────────────
set_default_browser() {
    local desktop_id="$1"
    xdg-settings set default-web-browser "${desktop_id}" 2>/dev/null \
        && info "Default browser set to ${desktop_id}" \
        || err "Could not set default browser to ${desktop_id} via xdg-settings"

    # Also set via kwriteconfig6 for KDE's own browser launch button in Plasma
    if command -v kwriteconfig6 &>/dev/null; then
        kwriteconfig6 \
            --file kdeglobals \
            --group "General" \
            --key "BrowserApplication" \
            "${desktop_id}" 2>/dev/null || true
    fi
}

# ── Dialog ────────────────────────────────────────────────────────────────────
CHOICE=$(
    zenity \
        --list \
        --title="Welcome to Raptor OS" \
        --text="<b>Choose your default web browser</b>\n\nFirefox is already installed and ready to use.\nBrave and Chrome will be downloaded from Flathub.\n" \
        --radiolist \
        --column="" \
        --column="Browser" \
        --column="Notes" \
        TRUE  "Firefox" "Fast · Private · Already installed — no download needed" \
        FALSE "Brave"   "Chromium · Built-in ad blocker · Privacy-focused (~120 MB)" \
        FALSE "Chrome"  "Google Chrome · Familiar · Widely compatible (~150 MB)" \
        --width=520 --height=310 \
        --ok-label="Confirm" \
        --cancel-label="Keep Firefox" \
        2>/dev/null
) || true

# ── Handle choice ─────────────────────────────────────────────────────────────
case "${CHOICE:-}" in

    # ── Firefox ───────────────────────────────────────────────────────────────
    Firefox|"")
        # Empty string = user dismissed dialog or clicked "Keep Firefox"
        log "Firefox kept as default browser."
        set_default_browser "firefox.desktop"
        finish
        ;;

    # ── Brave ─────────────────────────────────────────────────────────────────
    Brave)
        log "User selected Brave."

        if ! check_network; then
            set_default_browser "firefox.desktop"
            finish
            exit 0
        fi

        if install_with_progress "com.brave.Browser" "Brave" "~120 MB"; then
            set_default_browser "com.brave.Browser.desktop"
            log "Brave installed and set as default."
            zenity --info \
                --title="Brave is Ready" \
                --text="✓ Brave has been installed and set as your default browser." \
                --width=300 2>/dev/null || true
        else
            # Offer retry
            if zenity --question \
                    --title="Installation Failed" \
                    --text="Brave could not be installed.\n\nWould you like to try again?\n\nIf you choose No, Firefox will be kept as the default." \
                    --ok-label="Try Again" \
                    --cancel-label="Keep Firefox" \
                    --width=380 2>/dev/null; then
                # Second attempt — no progress dialog, just wait
                if flatpak install -y --noninteractive flathub com.brave.Browser \
                        >> "${INSTALL_LOG}" 2>&1; then
                    set_default_browser "com.brave.Browser.desktop"
                    log "Brave installed on retry."
                else
                    err "Brave install failed on retry. Keeping Firefox."
                    set_default_browser "firefox.desktop"
                fi
            else
                err "User declined retry. Keeping Firefox."
                set_default_browser "firefox.desktop"
            fi
        fi

        finish
        ;;

    # ── Chrome ────────────────────────────────────────────────────────────────
    Chrome)
        log "User selected Chrome."

        if ! check_network; then
            set_default_browser "firefox.desktop"
            finish
            exit 0
        fi

        if install_with_progress "com.google.Chrome" "Google Chrome" "~150 MB"; then
            set_default_browser "com.google.Chrome.desktop"
            log "Chrome installed and set as default."
            zenity --info \
                --title="Chrome is Ready" \
                --text="✓ Google Chrome has been installed and set as your default browser." \
                --width=300 2>/dev/null || true
        else
            if zenity --question \
                    --title="Installation Failed" \
                    --text="Chrome could not be installed.\n\nWould you like to try again?\n\nIf you choose No, Firefox will be kept as the default." \
                    --ok-label="Try Again" \
                    --cancel-label="Keep Firefox" \
                    --width=380 2>/dev/null; then
                if flatpak install -y --noninteractive flathub com.google.Chrome \
                        >> "${INSTALL_LOG}" 2>&1; then
                    set_default_browser "com.google.Chrome.desktop"
                    log "Chrome installed on retry."
                else
                    err "Chrome install failed on retry. Keeping Firefox."
                    set_default_browser "firefox.desktop"
                fi
            else
                err "User declined retry. Keeping Firefox."
                set_default_browser "firefox.desktop"
            fi
        fi

        finish
        ;;

    # ── Unexpected ────────────────────────────────────────────────────────────
    *)
        err "Unexpected choice value: '${CHOICE}' — keeping Firefox."
        set_default_browser "firefox.desktop"
        finish
        ;;
esac
