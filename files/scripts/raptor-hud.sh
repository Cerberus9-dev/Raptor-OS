#!/bin/bash
set -e

# =============================================================================
# Raptor HUD v4.2 — F-22 Themed KDE Plasma Shell
# =============================================================================

# ── Palette reference ────────────────────────────────────────────────────────
# Base:    #0d0f12  Surface: #151a20  Panel:   #1c2330  Border:  #2a3444
# Accent:  #33FF33  Warning: #f5a623  Success: #2ec27e  Text:    #c8d6e8

mkdir -p /usr/lib/raptor/hud

# ── RaptorOS KDE Color Scheme ─────────────────────────────────────────────────
mkdir -p /usr/share/color-schemes
cat << 'EOF' > /usr/share/color-schemes/RaptorOS.colors
[ColorEffects:Disabled]
Color=56,68,82
ColorAmount=0.55
ColorEffect=3
ContrastAmount=0.65
ContrastEffect=1
IntensityAmount=0.1
IntensityEffect=2

[ColorEffects:Inactive]
ChangeSelectionColor=true
Color=56,68,82
ColorAmount=0.025
ColorEffect=2
ContrastAmount=0.1
ContrastEffect=2
Enable=false
IntensityAmount=0
IntensityEffect=0

[Colors:Button]
BackgroundAlternate=30,42,58
BackgroundNormal=28,35,48
DecorationFocus=51,255,51
DecorationHover=51,255,51
ForegroundActive=51,255,51
ForegroundInactive=90,106,126
ForegroundLink=51,255,51
ForegroundNegative=220,50,50
ForegroundNeutral=245,166,35
ForegroundNormal=200,214,232
ForegroundPositive=46,194,126
ForegroundVisited=140,100,220

[Colors:Complementary]
BackgroundAlternate=20,28,40
BackgroundNormal=13,15,18
DecorationFocus=51,255,51
DecorationHover=51,255,51
ForegroundActive=51,255,51
ForegroundInactive=90,106,126
ForegroundLink=51,255,51
ForegroundNegative=220,50,50
ForegroundNeutral=245,166,35
ForegroundNormal=200,214,232
ForegroundPositive=46,194,126
ForegroundVisited=140,100,220

[Colors:Header]
BackgroundAlternate=21,26,32
BackgroundNormal=21,26,32
DecorationFocus=51,255,51
DecorationHover=51,255,51
ForegroundActive=51,255,51
ForegroundInactive=90,106,126
ForegroundLink=51,255,51
ForegroundNegative=220,50,50
ForegroundNeutral=245,166,35
ForegroundNormal=200,214,232
ForegroundPositive=46,194,126
ForegroundVisited=140,100,220

[Colors:Selection]
BackgroundAlternate=15,60,15
BackgroundNormal=30,90,30
DecorationFocus=51,255,51
DecorationHover=51,255,51
ForegroundActive=255,255,255
ForegroundInactive=180,200,220
ForegroundLink=150,255,150
ForegroundNegative=220,50,50
ForegroundNeutral=245,166,35
ForegroundNormal=255,255,255
ForegroundPositive=46,194,126
ForegroundVisited=200,170,255

[Colors:Tooltip]
BackgroundAlternate=21,26,32
BackgroundNormal=13,15,18
DecorationFocus=51,255,51
DecorationHover=51,255,51
ForegroundActive=51,255,51
ForegroundInactive=90,106,126
ForegroundLink=51,255,51
ForegroundNegative=220,50,50
ForegroundNeutral=245,166,35
ForegroundNormal=200,214,232
ForegroundPositive=46,194,126
ForegroundVisited=140,100,220

[Colors:View]
BackgroundAlternate=18,24,32
BackgroundNormal=13,15,18
DecorationFocus=51,255,51
DecorationHover=51,255,51
ForegroundActive=51,255,51
ForegroundInactive=90,106,126
ForegroundLink=51,255,51
ForegroundNegative=220,50,50
ForegroundNeutral=245,166,35
ForegroundNormal=200,214,232
ForegroundPositive=46,194,126
ForegroundVisited=140,100,220

[Colors:Window]
BackgroundAlternate=21,26,32
BackgroundNormal=28,35,48
DecorationFocus=51,255,51
DecorationHover=51,255,51
ForegroundActive=51,255,51
ForegroundInactive=90,106,126
ForegroundLink=51,255,51
ForegroundNegative=220,50,50
ForegroundNeutral=245,166,35
ForegroundNormal=200,214,232
ForegroundPositive=46,194,126
ForegroundVisited=140,100,220

[General]
ColorScheme=RaptorOS
Name=RaptorOS
shadeSortColumn=true

[KDE]
contrast=5

[WM]
activeBackground=21,26,32
activeBlend=51,255,51
activeForeground=200,214,232
inactiveBackground=13,15,18
inactiveBlend=42,52,68
inactiveForeground=90,106,126
EOF

# ── Aurorae Window Decoration ─────────────────────────────────────────────────
mkdir -p /usr/share/aurorae/themes/RaptorOS
cat << 'EOF' > /usr/share/aurorae/themes/RaptorOS/RaptorOSrc
[General]
ActiveTextColor=200,214,232
Animation=0
BorderBottom=1
BorderLeft=1
BorderRight=1
BorderTop=0
ButtonHeight=18
ButtonMarginTop=6
ButtonSpacing=2
ButtonWidth=18
DecorationPosition=0
DrawButtons=true
DrawSeparator=false
GrabBarBelow=false
InactiveTextColor=90,106,126
OverrideBorderSizes=false
PaddingBottom=4
PaddingLeft=4
PaddingRight=4
PaddingTop=0
ShadowColor=0,0,0
ShadowOpacity=0.8
ShadowSize=30
TitleAlignment=1
TitleEdgeBottom=4
TitleEdgeLeft=6
TitleEdgeRight=6
TitleEdgeTop=6
TitleHeight=24
UseKWinTextColors=true
EOF

cat << 'SVGEOF' > /usr/share/aurorae/themes/RaptorOS/RaptorOS.svg
<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink">
  <defs>
    <linearGradient id="titlebar-active" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0%" stop-color="#1c2330"/>
      <stop offset="100%" stop-color="#151a20"/>
    </linearGradient>
    <linearGradient id="titlebar-inactive" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0%" stop-color="#111418"/>
      <stop offset="100%" stop-color="#0d0f12"/>
    </linearGradient>
  </defs>
  <g id="decoration">
    <rect width="100" height="30" fill="url(#titlebar-active)"/>
    <rect y="29" width="100" height="1" fill="#33FF33" opacity="0.7"/>
    <rect width="2" height="30" fill="#33FF33" opacity="0.5"/>
  </g>
  <g id="decoration-inactive">
    <rect width="100" height="30" fill="url(#titlebar-inactive)"/>
    <rect y="29" width="100" height="1" fill="#2a3444"/>
    <rect width="2" height="30" fill="#2a3444"/>
  </g>
  <g id="close">
    <rect width="18" height="18" rx="1" fill="#3a1515"/>
    <line x1="5" y1="5" x2="13" y2="13" stroke="#cc3333" stroke-width="1.5" stroke-linecap="square"/>
    <line x1="13" y1="5" x2="5" y2="13" stroke="#cc3333" stroke-width="1.5" stroke-linecap="square"/>
  </g>
  <g id="close-hover">
    <rect width="18" height="18" rx="1" fill="#cc3333"/>
    <line x1="5" y1="5" x2="13" y2="13" stroke="white" stroke-width="1.5" stroke-linecap="square"/>
    <line x1="13" y1="5" x2="5" y2="13" stroke="white" stroke-width="1.5" stroke-linecap="square"/>
  </g>
  <g id="maximize">
    <rect width="18" height="18" rx="1" fill="#1c2330"/>
    <rect x="4" y="4" width="10" height="10" fill="none" stroke="#33FF33" stroke-width="1.5"/>
  </g>
  <g id="maximize-hover">
    <rect width="18" height="18" rx="1" fill="#1e4a7a"/>
    <rect x="4" y="4" width="10" height="10" fill="none" stroke="#5ab0ff" stroke-width="1.5"/>
  </g>
  <g id="minimize">
    <rect width="18" height="18" rx="1" fill="#1c2330"/>
    <line x1="4" y1="13" x2="14" y2="13" stroke="#33FF33" stroke-width="1.5" stroke-linecap="square"/>
  </g>
  <g id="minimize-hover">
    <rect width="18" height="18" rx="1" fill="#1e4a7a"/>
    <line x1="4" y1="13" x2="14" y2="13" stroke="#5ab0ff" stroke-width="1.5" stroke-linecap="square"/>
  </g>
</svg>
SVGEOF

# ── Application menu category registration ────────────────────────────────────
# Every Raptor app (Cortex, GPU Profiler, Wallpaper, Update Manager) is tagged
# Categories=X-RaptorOS;... in its .desktop file, but that tag alone does
# nothing — KDE (and any freedesktop.org menu-spec compliant launcher) only
# creates a visible menu section for a category if it's been explicitly
# registered via a .directory file (name/icon/comment for the section) plus
# a menu XML fragment matching that category. Without this, X-RaptorOS was
# simply ignored and every app fell back into its other listed categories
# (System/Settings) instead of getting its own grouping.
mkdir -p /usr/share/desktop-directories /etc/xdg/menus/applications-merged

cat << 'EOF' > /usr/share/desktop-directories/raptor-os.directory
[Desktop Entry]
Type=Directory
Name=Raptor OS
Comment=Raptor OS performance and system tools
Icon=raptor-os-category
EOF

cat << 'EOF' > /etc/xdg/menus/applications-merged/raptor-os.menu
<!DOCTYPE Menu PUBLIC "-//freedesktop//DTD Menu 1.0//EN"
 "http://www.freedesktop.org/standards/menu-spec/1.0/menu.dtd">
<Menu>
  <Name>Applications</Name>
  <Menu>
    <Name>Raptor OS</Name>
    <Directory>raptor-os.directory</Directory>
    <Include>
      <Category>X-RaptorOS</Category>
    </Include>
  </Menu>
</Menu>
EOF

# Category folder icon — same purple radial badge / dashed ring / cardinal
# tick visual family as Cortex, GPU Profiler, and Wallpaper, but with a
# generic "R" monogram rather than borrowing any one specific app's glyph,
# since this icon represents the OS/brand grouping, not any single app.
mkdir -p /usr/share/icons/hicolor/scalable/places
cat << 'SVGEOF' > /usr/share/icons/hicolor/scalable/places/raptor-os-category.svg
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64">
  <defs>
    <radialGradient id="bg" cx="50%" cy="50%" r="50%">
      <stop offset="0%" stop-color="#7c3aed"/>
      <stop offset="100%" stop-color="#4c1d95"/>
    </radialGradient>
  </defs>
  <circle cx="32" cy="32" r="30" fill="url(#bg)"/>
  <circle cx="32" cy="32" r="24" fill="none" stroke="#a78bfa" stroke-width="1.5"
          stroke-dasharray="12 4" stroke-linecap="round"/>
  <line x1="32" y1="10" x2="32" y2="18" stroke="#c4b5fd" stroke-width="2" stroke-linecap="round"/>
  <line x1="32" y1="46" x2="32" y2="54" stroke="#c4b5fd" stroke-width="2" stroke-linecap="round"/>
  <line x1="10" y1="32" x2="18" y2="32" stroke="#c4b5fd" stroke-width="2" stroke-linecap="round"/>
  <line x1="46" y1="32" x2="54" y2="32" stroke="#c4b5fd" stroke-width="2" stroke-linecap="round"/>
  <line x1="16.7" y1="16.7" x2="22.4" y2="22.4" stroke="#c4b5fd" stroke-width="1.5" stroke-linecap="round"/>
  <line x1="41.6" y1="41.6" x2="47.3" y2="47.3" stroke="#c4b5fd" stroke-width="1.5" stroke-linecap="round"/>
  <line x1="47.3" y1="16.7" x2="41.6" y2="22.4" stroke="#c4b5fd" stroke-width="1.5" stroke-linecap="round"/>
  <line x1="22.4" y1="41.6" x2="16.7" y2="47.3" stroke="#c4b5fd" stroke-width="1.5" stroke-linecap="round"/>
  <!-- "R" monogram -->
  <text x="32" y="42" font-family="sans-serif" font-weight="bold" font-size="26"
        fill="white" text-anchor="middle">R</text>
</svg>
SVGEOF
gtk-update-icon-cache /usr/share/icons/hicolor 2>/dev/null || true

# ── Baloo: filename-only indexing, 1-thread, low priority ─────────────────────
mkdir -p /etc/xdg
cat << 'BALOORCEOF' > /etc/xdg/baloofilerc
[Basic Settings]
Indexing-Enabled=true
Only from Cache=false

[General]
# Disable full-text content indexing — filename search only
exclude filters=*~,*.part,*.tmp,*.log,*.o,*.la,*.lo,*.loT,*.moc,moc_*.cpp,qrc_*.cpp,ui_*.h,cmake_install.cmake,CMakeCache.txt,CTestTestfile.cmake,libtool,config.status,confdefs.h,autom4te,conftest,confstat,Makefile.am,*.gcode,.hg,.git,.svn,.bzr,_darcs,.deps,.libs,.sconf_temp,.DS_Store,socket_*
dbPath[$e]=$HOME/.local/share/baloo
# 1 thread: prevents Baloo from competing with game loading/shader compilation
max threads=1
BALOORCEOF

# Also write /etc/xdg/kwinrc at build time for system-wide window decoration defaults.
cat << 'SYSKWINRC' > /etc/xdg/kwinrc
[org.kde.kdecoration2]
ButtonsOnLeft=M
ButtonsOnRight=IAX

[Windows]
TitlebarDoubleClickCommand=Maximize
ClickRaise=true
ElectricBorderMaximize=true
ElectricBorderTiling=true
FocusPolicy=ClickToFocus

[Compositing]
AnimationSpeed=3
LatencyPolicy=0
HiddenPreviews=4
SYSKWINRC

# Also write system-wide kdeglobals defaults for color scheme and icons
cat << 'SYSKDEGLOBALS' > /etc/xdg/kdeglobals
[General]
ColorScheme=RaptorOS

[Icons]
Theme=breeze-dark

[KDE]
LookAndFeelPackage=org.kde.breezedark.desktop
SingleClick=false
SYSKDEGLOBALS

# ── GTK theme ──────────────────────────────────────────────────────────────────
mkdir -p /usr/share/themes/RaptorOS-GTK/gtk-3.0
mkdir -p /usr/share/themes/RaptorOS-GTK/gtk-4.0

cat << 'EOF' > /usr/share/themes/RaptorOS-GTK/gtk-3.0/gtk.css
@define-color bg_color #151a20;
@define-color fg_color #c8d6e8;
@define-color base_color #0d0f12;
@define-color text_color #c8d6e8;
@define-color selected_bg_color #33FF33;
@define-color selected_fg_color #ffffff;
@define-color tooltip_bg_color #0d0f12;
@define-color tooltip_fg_color #c8d6e8;
@define-color borders #2a3444;
@define-color warning_color #f5a623;
@define-color success_color #2ec27e;
@define-color error_color #dc3232;
@define-color accent #33FF33;

* { -gtk-icon-style: symbolic; }
window, .background { background-color: @bg_color; color: @fg_color; }
headerbar { background: linear-gradient(to bottom, #1c2330, #151a20); border-bottom: 1px solid #33FF33; padding: 4px 8px; min-height: 36px; }
headerbar .title { font-weight: 600; color: @fg_color; letter-spacing: 0.04em; }
button { background: #1c2330; border: 1px solid @borders; color: @fg_color; border-radius: 2px; padding: 4px 12px; transition: all 120ms ease; }
button:hover { background: #1e4a7a; border-color: @accent; color: white; }
button.suggested-action   { background: @accent; border-color: @accent; color: white; }
button.destructive-action { background: #8b1a1a; border-color: #cc3333; color: white; }
entry { background: @base_color; border: 1px solid @borders; color: @fg_color; border-radius: 2px; padding: 4px 8px; caret-color: @accent; }
entry:focus { border-color: @accent; box-shadow: 0 0 0 1px @accent; }
treeview.view:selected, row:selected { background-color: @selected_bg_color; color: @selected_fg_color; }
scrollbar slider { background-color: #2a3444; border-radius: 2px; min-width: 6px; min-height: 6px; }
scrollbar slider:hover { background-color: @accent; }
tooltip { background-color: @tooltip_bg_color; border: 1px solid @borders; color: @tooltip_fg_color; border-radius: 2px; }
menubar, .menubar { background-color: #1c2330; border-bottom: 1px solid @borders; }
menu, .menu { background-color: #151a20; border: 1px solid @borders; }
menu menuitem:hover { background-color: @accent; color: white; }
notebook header { background-color: #1c2330; border-bottom: 1px solid @borders; }
notebook header tab:checked { background-color: @base_color; border-bottom: 2px solid @accent; }
progressbar progress { background-color: @accent; border-radius: 2px; }
checkbutton check, radiobutton radio { background: @base_color; border: 1px solid @borders; }
checkbutton check:checked, radiobutton radio:checked { background-color: @accent; border-color: @accent; }
scale trough { background-color: #2a3444; border-radius: 2px; min-height: 4px; }
scale highlight { background-color: @accent; border-radius: 2px; }
EOF

cp /usr/share/themes/RaptorOS-GTK/gtk-3.0/gtk.css \
   /usr/share/themes/RaptorOS-GTK/gtk-4.0/gtk.css

cat << 'EOF' > /usr/share/themes/RaptorOS-GTK/index.theme
[Desktop Entry]
Type=X-GNOME-Metatheme
Name=RaptorOS-GTK
Comment=F-22 Raptor themed GTK style
Encoding=UTF-8

[X11 Properties]
GtkTheme=RaptorOS-GTK
MetacityTheme=RaptorOS-GTK
IconTheme=breeze-dark
CursorTheme=Adwaita
ButtonLayout=close,minimize,maximize:

[KDE]
WidgetStyle=kvantum
EOF

# ── Kvantum theme ─────────────────────────────────────────────────────────────
mkdir -p /usr/share/Kvantum/RaptorOS
cat << 'EOF' > /usr/share/Kvantum/RaptorOS/RaptorOS.kvconfig
[%General]
author=RaptorOS
comment=F-22 Raptor stealth dark theme
x11drag=all
composite=true
menu_shadow_depth=6
tooltip_shadow_depth=4
popup_blurring=true

[GeneralColors]
window.color=#1c2330
base.color=#0d0f12
alt.base.color=#151a20
button.color=#1c2330
light.color=#2a3a4e
mid.light.color=#1e2d3e
mid.color=#151a20
dark.color=#0a0c0f
shadow.color=#000000
highlight.color=#33FF33
inactive.highlight.color=#2a3444
text.color=#c8d6e8
window.text.color=#c8d6e8
button.text.color=#c8d6e8
disabled.text.color=#5a6a7e
tooltip.base.color=#0d0f12
tooltip.text.color=#c8d6e8
link.color=#33FF33
link.visited.color=#8c64dc
progress.indicator.text.color=#ffffff

[Hacks]
transparent_ktitle_label=true
blur_konsole=true
EOF

cat << 'EOF' > /usr/share/Kvantum/RaptorOS/RaptorOS.svg
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 200 200">
  <rect width="200" height="200" fill="#1c2330"/>
</svg>
EOF

# ── Konsole profile ────────────────────────────────────────────────────────────
mkdir -p /usr/share/konsole
cat << 'EOF' > /usr/share/konsole/RaptorOS.profile
[Appearance]
ColorScheme=RaptorOS
Font=JetBrains Mono,11,-1,5,50,0,0,0,0,0
LineSpacing=2

[General]
Command=/bin/bash
Icon=utilities-terminal
Name=RaptorOS
Parent=FALLBACK/
TerminalColumns=120
TerminalRows=36

[Scrolling]
HistoryMode=2
HistorySize=10000
ScrollBarPosition=2

[Terminal Features]
BlinkingCursorEnabled=true
CursorShape=1
EOF

cat << 'EOF' > /usr/share/konsole/RaptorOS.colorscheme
[Background]
Color=13,15,18

[BackgroundIntense]
Color=21,26,32

[Color0]
Color=21,26,32

[Color0Intense]
Color=42,52,68

[Color1]
Color=180,50,50

[Color1Intense]
Color=220,80,80

[Color2]
Color=46,160,100

[Color2Intense]
Color=46,194,126

[Color3]
Color=200,130,30

[Color3Intense]
Color=245,166,35

[Color4]
Color=30,100,200

[Color4Intense]
Color=0,200,200

[Color5]
Color=100,60,180

[Color5Intense]
Color=140,100,220

[Color6]
Color=30,140,180

[Color6Intense]
Color=30,180,220

[Color7]
Color=160,180,200

[Color7Intense]
Color=200,214,232

[Foreground]
Color=200,214,232

[ForegroundIntense]
Color=230,240,255

[General]
Anchor=0.5,0.5
Blur=true
BlurRadius=12
ColorRandomization=false
Description=RaptorOS
Opacity=0.92
EOF

# ── One-time migration: clean up leftover RaptorOS theme reference ────────────
# This build no longer writes /etc/xdg/plasmarc or the desktoptheme/RaptorOS
# package — but a user upgrading from a build that DID write them may still
# have "name=RaptorOS" sitting in their own ~/.config/plasmarc, which always
# takes priority over system defaults and is untouched by any system rebuild.
# This runs once per user, checks for that specific stale line, removes it
# if found, and restarts plasmashell so the fix is visible immediately —
# using the same detached-subshell restart proven safe earlier (never
# systemctl restart plasma-plasmashell.service, which caused a reboot hang).
mkdir -p /usr/lib/raptor
cat << 'MIGRATIONEOF' > /usr/lib/raptor/cleanup-legacy-panel-theme.sh
#!/bin/bash
set -euo pipefail

STAMP_DIR="$HOME/.local/share/raptor"
STAMP="$STAMP_DIR/legacy-panel-theme-cleaned"
[ -f "$STAMP" ] && exit 0

CHANGED=0
PLASMARC="$HOME/.config/plasmarc"

if [ -f "$PLASMARC" ] && grep -q "^name=RaptorOS$" "$PLASMARC" 2>/dev/null; then
    sed -i '/^name=RaptorOS$/d' "$PLASMARC"
    CHANGED=1
    logger -t raptor-cleanup "Removed stale 'name=RaptorOS' from $PLASMARC"
fi

# Nothing this script can do about /usr — it's read-only on OSTree — but log
# it for visibility if the old theme package is somehow still present.
if [ -d /usr/share/plasma/desktoptheme/RaptorOS ]; then
    logger -t raptor-cleanup \
        "Note: /usr/share/plasma/desktoptheme/RaptorOS still exists on this deployment. A fresh rebase to a build without it should clear this."
fi

if [ "$CHANGED" = "1" ]; then
    plasma-apply-colorscheme BreezeDark 2>/dev/null || true
    (
        sleep 2
        killall plasmashell 2>/dev/null || true
        sleep 2
        WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-0}" \
        DBUS_SESSION_BUS_ADDRESS="${DBUS_SESSION_BUS_ADDRESS:-unix:path=${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/bus}" \
        plasmashell --replace &>/dev/null &
        disown
    ) &>/dev/null &
    disown
fi

mkdir -p "$STAMP_DIR"
touch "$STAMP"
MIGRATIONEOF
chmod +x /usr/lib/raptor/cleanup-legacy-panel-theme.sh

cat << 'EOF' > /etc/xdg/autostart/raptor-cleanup-legacy-theme.desktop
[Desktop Entry]
Type=Application
Name=Raptor OS Legacy Theme Cleanup
Comment=One-time removal of the deprecated RaptorOS panel theme reference
Exec=/usr/lib/raptor/cleanup-legacy-panel-theme.sh
Terminal=false
Hidden=false
X-KDE-autostart-phase=1
NoDisplay=true
EOF

echo "RAPTOR_HUD_READY"
echo ""
echo "Raptor OS — Using KDE Plasma Default Taskbar"
echo "The custom HUD theme (F-22 cockpit aesthetic) is applied through:"
echo "  - Color scheme (RaptorOS)"
echo "  - Window decoration (Aurorae with green accents)"
echo "  - Plasma theme (neon glow effects)"
echo ""
echo "All taskbar configurations are now KDE defaults."
echo "Categories should display properly with full scroll support."
