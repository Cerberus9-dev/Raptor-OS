#!/bin/bash
# raptor-app-choice.sh
# First-boot app selection dialog allowing users to choose applications to install.
# Replaces the old browser-only dialog with an expanded package selection system.
#
# Supports: Vesktop (communication), VSCode, Blender, etc.

set -euo pipefail

STAMP_FILE="/var/lib/raptor/app-choice-done"
LOG_TAG="raptor-app-choice"
CONFIG_FILE="/etc/raptor/app-selections.conf"

log()  { logger -t "$LOG_TAG" -- "$*"; }
err()  { logger -t "$LOG_TAG" -p user.err -- "$*"; }

# ── Guard ────────────────────────────────────────────────────────────────────
if [[ -f "$STAMP_FILE" ]]; then
    log "App selection already done — skipping."
    exit 0
fi

# ── Prerequisite check ───────────────────────────────────────────────────────
if ! command -v zenity &>/dev/null; then
    err "zenity not found; cannot show app dialog."
    exit 1
fi

# ── App selection dialog ──────────────────────────────────────────────────────
# Format: TRUE/FALSE for pre-selected, App Name, Description
APPS=$(zenity \
    --list \
    --title="Welcome to Raptor OS — Application Setup" \
    --text="<b>Choose which applications to install on first boot:</b>\n\nSelected apps will be installed from Flathub." \
    --checklist \
    --column="Install" \
    --column="Application" \
    --column="Description" \
    TRUE  "Vesktop"         "Discord client (modern, lightweight)" \
    FALSE "VSCodium"        "Open-source code editor" \
    FALSE "Blender"         "3D modeling and animation" \
    FALSE "Audacity"        "Audio editing" \
    FALSE "Kdenlive"        "Video editing" \
    FALSE "Krita"           "Digital painting" \
    FALSE "Gimp"            "Image editor" \
    FALSE "LibreOffice"     "Office suite" \
    FALSE "OBS Studio"      "Streaming and recording" \
    --width=500 --height=400 \
    --ok-label="Install Selected" \
    --cancel-label="Skip" \
    2>/dev/null) || true

case "${APPS:-}" in
    "")
        # User clicked "Skip" or closed dialog
        log "App selection skipped by user."
        exit 0
        ;;
    *)
        log "User selected apps: $APPS"
        
        # Parse the pipe-delimited list and install selected apps
        IFS='|' read -ra SELECTED_APPS <<< "$APPS"
        
        FLATPAK_INSTALLS=(
            ["Vesktop"]="com.vesktop.Vesktop"
            ["VSCodium"]="com.vscodium.codium"
            ["Blender"]="org.blender.Blender"
            ["Audacity"]="org.audacityteam.Audacity"
            ["Kdenlive"]="org.kde.kdenlive"
            ["Krita"]="org.kde.krita"
            ["Gimp"]="org.gimp.GIMP"
            ["LibreOffice"]="org.libreoffice.LibreOffice"
            ["OBS Studio"]="com.obsproject.Studio"
        )
        
        FAILED_INSTALLS=()
        
        for app in "${SELECTED_APPS[@]}"; do
            app="${app%\"}"  # Remove trailing quote if present
            app="${app#\"}"  # Remove leading quote if present
            
            if [[ -z "$app" ]]; then
                continue
            fi
            
            FLATPAK_ID="${FLATPAK_INSTALLS[$app]:-}"
            if [[ -z "$FLATPAK_ID" ]]; then
                log "Unknown app: $app"
                continue
            fi
            
            log "Installing flatpak: $FLATPAK_ID"
            if ! flatpak install -y --noninteractive "flathub" "$FLATPAK_ID" 2>&1 | tee -a /tmp/raptor-install.log; then
                err "Failed to install $app ($FLATPAK_ID)"
                FAILED_INSTALLS+=("$app")
            else
                log "Successfully installed $app"
            fi
        done
        
        # Show result dialog
        if [[ ${#FAILED_INSTALLS[@]} -eq 0 ]]; then
            zenity --info \
                --title="Installation Complete" \
                --text="All selected applications have been installed successfully!" \
                --width=300 2>/dev/null || true
        else
            FAILED_LIST=$(printf '%s\n' "${FAILED_INSTALLS[@]}")
            zenity --warning \
                --title="Some Installations Failed" \
                --text="The following applications could not be installed:\n\n$FAILED_LIST\n\nCheck your internet connection and try again." \
                --width=350 2>/dev/null || true
        fi
        ;;
esac

# ── Write stamp ──────────────────────────────────────────────────────────────
mkdir -p "$(dirname "$STAMP_FILE")"
touch "$STAMP_FILE"
log "App selection complete."
