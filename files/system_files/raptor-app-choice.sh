#!/bin/bash
# raptor-app-choice.sh
# First-boot optional-app selection dialog.
# v2.0: fixed declare -A, user stamp path, Wayland-safe (no DISPLAY requirement),
#       additive-only (does NOT re-offer apps already installed by default).
#
# Runs as a user service (raptor-firstboot.service) after plasma-plasmashell.
# Stamp at ~/.local/share/raptor/app-choice-done prevents re-running.

set -euo pipefail

STAMP_FILE="${HOME}/.local/share/raptor/app-choice-done"
LOG_TAG="raptor-app-choice"

log() { logger -t "${LOG_TAG}" -- "$*"; }
err() { logger -t "${LOG_TAG}" -p user.err -- "$*"; }

# ── Guard ─────────────────────────────────────────────────────────────────────
if [[ -f "${STAMP_FILE}" ]]; then
    log "App selection already done — skipping."
    exit 0
fi

# ── Prerequisite check ────────────────────────────────────────────────────────
if ! command -v zenity &>/dev/null; then
    err "zenity not found — cannot show app dialog. Writing stamp to avoid loop."
    mkdir -p "$(dirname "${STAMP_FILE}")" && touch "${STAMP_FILE}"
    exit 0
fi

if ! command -v flatpak &>/dev/null; then
    err "flatpak not found — cannot install optional apps. Writing stamp to avoid loop."
    mkdir -p "$(dirname "${STAMP_FILE}")" && touch "${STAMP_FILE}"
    exit 0
fi

# ── Per-user app configuration ─────────────────────────────────────────────────
# Runs unconditionally — even if the user clicks Skip on the app selection
# dialog below. Handles anything that must live in per-user directories and
# therefore can't be set at image build time (Flatpak user data, ~/.mozilla).
# Previously lived in raptor-appconfig.sh + raptor-appconfig.service; merged
# here to eliminate redundant files and service units.

# Vesktop: write Chromium flags.txt to cap V8 heap and force Wayland-native
VESKTOP_CFG="${HOME}/.var/app/dev.vencord.Vesktop/config/vesktop"
if flatpak info dev.vencord.Vesktop &>/dev/null 2>&1; then
    mkdir -p "${VESKTOP_CFG}"
    cat > "${VESKTOP_CFG}/flags.txt" << 'VESKTOPFLAGS'
# Raptor OS: Vesktop Chromium flags
# Caps memory and forces Wayland-native rendering (avoids ~30 MB XWayland overhead).

--ozone-platform=wayland
--enable-wayland-ime

# V8 old-gen heap: 256 MB (default ~1.4 GB on systems with free RAM)
--max-old-space-size=256
--js-flags=--max-old-space-size=256

# Max 2 renderer processes (~80-120 MB each)
--renderer-process-limit=2

# Share renderer processes across same-site origins
--process-per-site

# Reduce CPU/memory for occluded/background windows
--disable-backgrounding-occluded-windows
--disable-renderer-backgrounding

# Signal allocator to apply more aggressive GC pressure
--memory-model=low

# VA-API hardware video decode (reduces CPU load in video calls/streams)
--enable-features=VaapiVideoDecoder,VaapiVideoEncoder
--disable-features=UseChromeOSDirectVideoDecoder,CrashpadWithBrowserLock
VESKTOPFLAGS

    # Belt-and-suspenders: also set via flatpak user override (env vars are
    # picked up even if the flags.txt path ever changes between Vesktop versions)
    flatpak override --user dev.vencord.Vesktop \
        --env=OZONE_PLATFORM=wayland \
        --env=ELECTRON_OZONE_PLATFORM_HINT=auto \
        2>/dev/null || true
    log "Vesktop: flags.txt and user Flatpak override applied."
else
    log "Vesktop not installed — skipping Vesktop config."
fi

# Firefox: copy skel user.js to any existing profiles that don't have one yet.
# policies.json (system-wide, from raptor-gaming.sh) handles memory defaults;
# user.js covers GPU compositing, rendering quality, and privacy prefs.
FF_SKEL="/etc/skel/.mozilla/firefox/raptor-default/user.js"
if [[ -f "${FF_SKEL}" ]]; then
    for profdir in \
        "${HOME}/.mozilla/firefox/"*.default        \
        "${HOME}/.mozilla/firefox/"*.default-release \
        "${HOME}/.mozilla/firefox/"*.default-esr;
    do
        [[ -d "${profdir}" ]] || continue
        if [[ ! -f "${profdir}/user.js" ]]; then
            cp "${FF_SKEL}" "${profdir}/user.js"
            log "Firefox user.js deployed to: $(basename "${profdir}")"
        fi
    done
fi

# Flatpak: ensure the user-level Flathub remote exists so app installs below work.
if command -v flatpak &>/dev/null; then
    flatpak remote-add --user --if-not-exists flathub \
        https://dl.flathub.org/repo/flathub.flatpakrepo 2>/dev/null || true
fi

# ── App catalogue ─────────────────────────────────────────────────────────────
# Format: "PRESELECT|DISPLAY_NAME|FLATPAK_ID|DESCRIPTION"
# Only list apps NOT already installed by the default Flatpak list in recipe.yml.
# Mandatory defaults (Vesktop, Heroic, ProtonUp, Bottles, Flatseal, MissionCenter)
# are never shown here — they are always installed.
APP_CATALOGUE=(
    # ── Communication ──────────────────────────────────────────────────────
    "FALSE|Telegram|org.telegram.desktop|Fast, secure messaging"
    "FALSE|Signal|org.signal.Signal|Private, encrypted messaging"
    "FALSE|Slack|com.slack.Slack|Team communication"
    "FALSE|Zoom|us.zoom.Zoom|Video conferencing"
    # ── Productivity ───────────────────────────────────────────────────────
    "TRUE|VSCodium|com.vscodium.codium|Open-source VS Code (no telemetry)"
    "FALSE|ONLYOFFICE|org.onlyoffice.desktopeditors|Office suite — Word/Excel/PowerPoint compat"
    "FALSE|Bitwarden|com.bitwarden.desktop|Open-source password manager"
    "FALSE|Joplin|net.cozic.joplin_desktop|Note-taking app with markdown support"
    "FALSE|MarkText|com.github.marktext.marktext|Clean markdown editor"
    "FALSE|Calibre|com.calibre_ebook.calibre|Ebook library manager"
    # ── Office ────────────────────────────────────────────────────────────
    "FALSE|LibreOffice|org.libreoffice.LibreOffice|Full office suite — Writer, Calc, Impress"
    # ── Creative ───────────────────────────────────────────────────────────
    "FALSE|GIMP|org.gimp.GIMP|Photo editing and image manipulation"
    "FALSE|Inkscape|org.inkscape.Inkscape|Vector graphics editor"
    "FALSE|Krita|org.kde.krita|Digital painting and illustration"
    "FALSE|Darktable|org.darktable.Darktable|RAW photo development and editing"
    "FALSE|Blender|org.blender.Blender|3D modelling, animation, rendering"
    "FALSE|Kdenlive|org.kde.kdenlive|Non-linear video editor (KDE)"
    "FALSE|Shotcut|org.shotcut.Shotcut|Video editor (non-linear)"
    "FALSE|OBS Studio|com.obsproject.Studio|Screen recording and live streaming"
    "FALSE|Audacity|org.audacityteam.Audacity|Audio recording and editing"
    "FALSE|Boatswain|com.feaneron.Boatswain|Elgato Stream Deck controller"
    # ── Development ────────────────────────────────────────────────────────
    "FALSE|Godot Engine|org.godotengine.Godot|Free, open-source game engine"
    "FALSE|GitHub Desktop|io.github.shiftey.Desktop|Git GUI for GitHub repos"
    "FALSE|Pods|com.github.marhkb.Pods|Podman/Docker container GUI"
    # ── Gaming & Media ─────────────────────────────────────────────────────
    "FALSE|Lutris|net.lutris.Lutris|Game launcher for Linux, Wine, emulators"
    "FALSE|Protontricks|com.github.Matoking.protontricks|Configure Steam/Proton games — install DirectX, runtimes, VC++, etc."
    "FALSE|Spotify|com.spotify.Client|Music and podcast streaming"
    "FALSE|Plex|tv.plex.PlexDesktop|Media server desktop client"
    "FALSE|VLC|org.videolan.VLC|Plays virtually any media format/codec"
    # ── Audio ──────────────────────────────────────────────────────────────
    "FALSE|EasyEffects|com.github.wwmm.easyeffects|Headset EQ, bass boost, noise reduction via PipeWire"
    # ── System tools ───────────────────────────────────────────────────────
    "FALSE|Warehouse|io.github.flattool.Warehouse|Browse, manage and clean up installed Flatpak apps"
    "FALSE|Impression|io.gitlab.adhami3310.Impression|Flash OS images to USB drives"
    "FALSE|CoreCtrl|org.corectrl.CoreCtrl|AMD GPU and CPU control — overclocking, fan curves, power limits"
    # ── Communication ──────────────────────────────────────────────────────
    "FALSE|Thunderbird|org.mozilla.Thunderbird|Email and calendar client"
)

# ── Build zenity argument list ────────────────────────────────────────────────
ZENITY_ARGS=()
for entry in "${APP_CATALOGUE[@]}"; do
    IFS='|' read -r preselect name id desc <<< "${entry}"
    ZENITY_ARGS+=("${preselect}" "${name}" "${id}" "${desc}")
done

# ── Show dialog ───────────────────────────────────────────────────────────────
SELECTED=$(
    zenity \
        --list \
        --title="Raptor OS — Optional App Setup" \
        --text="<b>Select optional applications to install from Flathub:</b>\n\nPre-ticked apps are recommended for most users.\nYou can install more later from Discover or the terminal." \
        --checklist \
        --column="Install" \
        --column="Application" \
        --column="Flatpak ID" \
        --column="Description" \
        --print-column="3" \
        --separator="|" \
        "${ZENITY_ARGS[@]}" \
        --width=700 --height=600 \
        --ok-label="Install Selected" \
        --cancel-label="Skip for Now" \
        2>/dev/null
) || true
# zenity exits 1 on "Skip" — that's caught by `|| true`

# ── Always write stamp so we never loop ───────────────────────────────────────
mkdir -p "$(dirname "${STAMP_FILE}")"
touch "${STAMP_FILE}"

if [[ -z "${SELECTED:-}" ]]; then
    log "App selection skipped or nothing selected."
    exit 0
fi

log "User selected Flatpak IDs: ${SELECTED}"

# ── Install selected Flatpaks ─────────────────────────────────────────────────
# declare -A is required for associative arrays — this was missing before.
declare -A ID_TO_NAME
for entry in "${APP_CATALOGUE[@]}"; do
    IFS='|' read -r _pre name id _desc <<< "${entry}"
    ID_TO_NAME["${id}"]="${name}"
done

FAILED=()
IFS='|' read -ra TO_INSTALL <<< "${SELECTED}"

for flatpak_id in "${TO_INSTALL[@]}"; do
    flatpak_id="${flatpak_id//\"/}"   # strip stray quotes zenity may add
    [[ -z "${flatpak_id}" ]] && continue

    app_name="${ID_TO_NAME[${flatpak_id}]:-${flatpak_id}}"
    log "Installing ${app_name} (${flatpak_id})…"

    if flatpak install -y --noninteractive flathub "${flatpak_id}" \
            >> /tmp/raptor-app-install.log 2>&1; then
        log "OK: ${app_name}"
    else
        err "FAILED: ${app_name} (${flatpak_id})"
        FAILED+=("${app_name}")
    fi
done

# ── Result dialog ─────────────────────────────────────────────────────────────
if [[ ${#FAILED[@]} -eq 0 ]]; then
    zenity --info \
        --title="Raptor OS — Setup Complete" \
        --text="All selected applications were installed successfully." \
        --width=340 2>/dev/null || true
else
    FAIL_LIST=$(printf '  • %s\n' "${FAILED[@]}")
    zenity --warning \
        --title="Some Apps Failed to Install" \
        --text="The following could not be installed:\n\n${FAIL_LIST}\n\nCheck your connection and install them later from Discover." \
        --width=380 2>/dev/null || true
fi

log "App selection complete."
