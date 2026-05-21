#!/bin/bash
set -e

# =============================================================================
# Raptor HUD — F-22 Themed KDE Plasma Shell
# • RaptorOS color scheme (gunmetal + electric blue + amber)
# • Slim Plasma top bar (system tray only)
# • Latte Dock bottom floating dock
# • Monochrome military stencil icon theme
# • Aurorae window decoration
# • Applied at first login via systemd user unit
# =============================================================================

# ── Palette reference ─────────────────────────────────────────────────────────
# Base:       #0d0f12  (near-black, stealth fuselage)
# Surface:    #151a20  (gunmetal dark)
# Panel:      #1c2330  (panel background)
# Border:     #2a3444  (subtle edge)
# Accent:     #1e90ff  (electric blue — HUD glow)
# Warning:    #f5a623  (amber alert)
# Success:    #2ec27e  (green go)
# Text:       #c8d6e8  (cool grey-white)
# Dim text:   #5a6a7e  (muted)

# ── Install Latte Dock ────────────────────────────────────────────────────────
# Latte Dock is installed via rpm-ostree in recipe.yml.
# This script ships its layout + config.

mkdir -p /usr/lib/raptor/hud

# ── RaptorOS KDE Color Scheme ─────────────────────────────────────────────────
# Installed system-wide; user firstboot script symlinks it as active scheme.
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
DecorationFocus=30,144,255
DecorationHover=30,144,255
ForegroundActive=30,144,255
ForegroundInactive=90,106,126
ForegroundLink=30,144,255
ForegroundNegative=220,50,50
ForegroundNeutral=245,166,35
ForegroundNormal=200,214,232
ForegroundPositive=46,194,126
ForegroundVisited=140,100,220

[Colors:Complementary]
BackgroundAlternate=20,28,40
BackgroundNormal=13,15,18
DecorationFocus=30,144,255
DecorationHover=30,144,255
ForegroundActive=30,144,255
ForegroundInactive=90,106,126
ForegroundLink=30,144,255
ForegroundNegative=220,50,50
ForegroundNeutral=245,166,35
ForegroundNormal=200,214,232
ForegroundPositive=46,194,126
ForegroundVisited=140,100,220

[Colors:Header]
BackgroundAlternate=21,26,32
BackgroundNormal=21,26,32
DecorationFocus=30,144,255
DecorationHover=30,144,255
ForegroundActive=30,144,255
ForegroundInactive=90,106,126
ForegroundLink=30,144,255
ForegroundNegative=220,50,50
ForegroundNeutral=245,166,35
ForegroundNormal=200,214,232
ForegroundPositive=46,194,126
ForegroundVisited=140,100,220

[Colors:Selection]
BackgroundAlternate=20,100,200
BackgroundNormal=30,144,255
DecorationFocus=30,144,255
DecorationHover=30,144,255
ForegroundActive=255,255,255
ForegroundInactive=180,200,220
ForegroundLink=180,220,255
ForegroundNegative=220,50,50
ForegroundNeutral=245,166,35
ForegroundNormal=255,255,255
ForegroundPositive=46,194,126
ForegroundVisited=200,170,255

[Colors:Tooltip]
BackgroundAlternate=21,26,32
BackgroundNormal=13,15,18
DecorationFocus=30,144,255
DecorationHover=30,144,255
ForegroundActive=30,144,255
ForegroundInactive=90,106,126
ForegroundLink=30,144,255
ForegroundNegative=220,50,50
ForegroundNeutral=245,166,35
ForegroundNormal=200,214,232
ForegroundPositive=46,194,126
ForegroundVisited=140,100,220

[Colors:View]
BackgroundAlternate=18,24,32
BackgroundNormal=13,15,18
DecorationFocus=30,144,255
DecorationHover=30,144,255
ForegroundActive=30,144,255
ForegroundInactive=90,106,126
ForegroundLink=30,144,255
ForegroundNegative=220,50,50
ForegroundNeutral=245,166,35
ForegroundNormal=200,214,232
ForegroundPositive=46,194,126
ForegroundVisited=140,100,220

[Colors:Window]
BackgroundAlternate=21,26,32
BackgroundNormal=28,35,48
DecorationFocus=30,144,255
DecorationHover=30,144,255
ForegroundActive=30,144,255
ForegroundInactive=90,106,126
ForegroundLink=30,144,255
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
activeBlend=30,144,255
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

# SVG decoration (sharp geometric, stealth dark)
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
    <linearGradient id="btn-close" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0%" stop-color="#8b1a1a"/>
      <stop offset="100%" stop-color="#5c1010"/>
    </linearGradient>
    <linearGradient id="btn-hover" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0%" stop-color="#1e4a7a"/>
      <stop offset="100%" stop-color="#0f2a4a"/>
    </linearGradient>
  </defs>

  <!-- Active titlebar -->
  <g id="decoration">
    <rect width="100" height="30" fill="url(#titlebar-active)"/>
    <!-- Bottom accent line — electric blue -->
    <rect y="29" width="100" height="1" fill="#1e90ff" opacity="0.7"/>
    <!-- Left edge accent -->
    <rect width="2" height="30" fill="#1e90ff" opacity="0.5"/>
  </g>

  <!-- Inactive titlebar -->
  <g id="decoration-inactive">
    <rect width="100" height="30" fill="url(#titlebar-inactive)"/>
    <rect y="29" width="100" height="1" fill="#2a3444"/>
    <rect width="2" height="30" fill="#2a3444"/>
  </g>

  <!-- Close button -->
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

  <!-- Maximize button -->
  <g id="maximize">
    <rect width="18" height="18" rx="1" fill="#1c2330"/>
    <rect x="4" y="4" width="10" height="10" fill="none" stroke="#1e90ff" stroke-width="1.5"/>
  </g>
  <g id="maximize-hover">
    <rect width="18" height="18" rx="1" fill="#1e4a7a"/>
    <rect x="4" y="4" width="10" height="10" fill="none" stroke="#5ab0ff" stroke-width="1.5"/>
  </g>

  <!-- Minimize button -->
  <g id="minimize">
    <rect width="18" height="18" rx="1" fill="#1c2330"/>
    <line x1="4" y1="13" x2="14" y2="13" stroke="#1e90ff" stroke-width="1.5" stroke-linecap="square"/>
  </g>
  <g id="minimize-hover">
    <rect width="18" height="18" rx="1" fill="#1e4a7a"/>
    <line x1="4" y1="13" x2="14" y2="13" stroke="#5ab0ff" stroke-width="1.5" stroke-linecap="square"/>
  </g>
</svg>
SVGEOF

# ── Monochrome Military Icon Theme ────────────────────────────────────────────
# Ships an index.theme that inherits Papirus-Dark (sharp, flat icons)
# and overrides the folder/app colors to monochrome via a colorize hack.
# Papirus-Dark must be installed (added to recipe.yml).
mkdir -p /usr/share/icons/RaptorOS-Icons/apps/scalable
mkdir -p /usr/share/icons/RaptorOS-Icons/places/scalable

cat << 'EOF' > /usr/share/icons/RaptorOS-Icons/index.theme
[Icon Theme]
Name=RaptorOS Icons
Comment=Military monochrome icon theme for Raptor OS
Inherits=Papirus-Dark,breeze-dark,hicolor
Directories=apps/scalable,places/scalable

[apps/scalable]
Size=48
MinSize=16
MaxSize=256
Type=Scalable
Context=Applications

[places/scalable]
Size=48
MinSize=16
MaxSize=256
Type=Scalable
Context=Places
EOF

# Override folder icon with a sharp gunmetal/blue stencil folder
cat << 'SVGEOF' > /usr/share/icons/RaptorOS-Icons/places/scalable/folder.svg
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48">
  <defs>
    <linearGradient id="fg" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0%" stop-color="#2a3c52"/>
      <stop offset="100%" stop-color="#1a2636"/>
    </linearGradient>
  </defs>
  <!-- Folder body — sharp corners, military flat -->
  <path d="M4 14 L4 40 L44 40 L44 18 L22 18 L18 14 Z" fill="url(#fg)"/>
  <!-- Tab -->
  <path d="M4 14 L18 14 L22 18 L4 18 Z" fill="#1e90ff" opacity="0.6"/>
  <!-- Top edge accent -->
  <line x1="4" y1="18" x2="44" y2="18" stroke="#1e90ff" stroke-width="1" opacity="0.4"/>
  <!-- Border -->
  <path d="M4 14 L4 40 L44 40 L44 18 L22 18 L18 14 Z"
        fill="none" stroke="#2a3c52" stroke-width="1"/>
</svg>
SVGEOF

# ── Latte Dock Layout ─────────────────────────────────────────────────────────
# Installed to /usr/lib/raptor/hud/ and copied to user dir by firstboot script.
mkdir -p /usr/lib/raptor/hud/latte

cat << 'EOF' > /usr/lib/raptor/hud/latte/RaptorHUD.layout.latte
[ActionPlugins][1]
RightButton;NoModifier=org.kde.contextmenu

[Containments][1]
activityId=
byPassWM=false
containmentType=Latte
disablePlasmoidFollowsMouse=false
isMoveFromFinishedAnimation=false
lastScreen=0
location=4
onPrimary=true
plugin=org.kde.latte.containment
wallpaperplugin=org.kde.image

[Containments][1][Applets][2]
immutability=1
plugin=org.kde.latte.plasmoid

[Containments][1][Applets][2][Configuration]
PreloadWeight=0

[Containments][1][Applets][2][Configuration][General]
isInLatteDock=true

[Containments][1][Applets][3]
immutability=1
plugin=org.kde.plasma.taskmanager

[Containments][1][Applets][3][Configuration]
PreloadWeight=0

[Containments][1][Applets][3][Configuration][General]
isInLatteDock=true
launchers=applications:org.kde.dolphin.desktop,applications:org.kde.konsole.desktop,applications:firefox.desktop,applications:com.vscodium.codium.desktop,applications:steam.desktop,applications:raptor-cortex.desktop,applications:raptor-hud.desktop

[Containments][1][General]
advanced=false
alignmentType=10
animationsEnabled=true
appletOrder=2;3
autoDecreaseIconSize=false
backgroundRadius=8
canvasOpacity=80
colorStyle=0
customBackground=true
customBackgroundColor=28,35,48
customBackgroundOpacity=92
customBorderColor=30,144,255
customBorderWidth=1
directRenderingEnabled=true
dockBackgroundStyle=1
glowEnabled=true
glowColor=30,144,255
glowOpacity=45
iconSize=44
iconSpacing=6
inConfigureAppletsMode=false
latteAppletPos=0
maxLength=90
maxLengthPercentage=90
minLength=70
offsetX=0
panelPosition=10
panelSize=56
panelShadowsActive=true
proportionIconSize=-1
screenEdgeMargin=6
shadowColor=0,0,0
shadowOpacity=70
shadowSize=20
showGlow=true
shrinkThickMargins=true
taskbarStyle=0
thicknessMargin=6
useThemePanel=false
visibility=2
zoomFactor=1.15
EOF

# ── Plasma Top Panel Config ───────────────────────────────────────────────────
# Slim system-tray-only top bar applied via kwriteconfig5 in firstboot.
cat << 'EOF' > /usr/lib/raptor/hud/apply-plasma-panel.sh
#!/bin/bash
# Applies the slim Raptor HUD top panel via kwriteconfig5.
# Run as the target USER (not root) from the firstboot service.

KCONF="$HOME/.config/plasmashellrc"

# Remove default panel and create our slim top bar
# (Plasma recreates panels from plasmashellrc on next login)
kwriteconfig5 --file plasmashellrc --group PlasmaViews --group "Panel 1" \
    --key location 3   # 3 = top

kwriteconfig5 --file plasmashellrc --group PlasmaViews --group "Panel 1" \
    --key thickness 28

kwriteconfig5 --file plasmashellrc --group PlasmaViews --group "Panel 1" \
    --key maximumLength 100

kwriteconfig5 --file plasmashellrc --group PlasmaViews --group "Panel 1" \
    --key alignment 2   # center

# Apply color scheme
plasma-apply-colorscheme RaptorOS 2>/dev/null || \
    kwriteconfig5 --file kdeglobals --group General --key ColorScheme RaptorOS

# Apply window decoration
kwriteconfig5 --file kwinrc --group org.kde.kdecoration2 \
    --key library org.kde.kwin.aurorae
kwriteconfig5 --file kwinrc --group org.kde.kdecoration2 \
    --key theme "__aurorae__svg__RaptorOS"

# Apply icon theme
kwriteconfig5 --file kdeglobals --group Icons --key Theme RaptorOS-Icons

# Plasma style — use Breeze Dark as base (closest to our palette without
# a full plasmoid theme build)
kwriteconfig5 --file kdeglobals --group KDE --key LookAndFeelPackage \
    org.kde.breezedark.desktop

# Latte: import and apply layout
if command -v latte-dock &>/dev/null; then
    mkdir -p "$HOME/.config/latte"
    cp /usr/lib/raptor/hud/latte/RaptorHUD.layout.latte \
       "$HOME/.config/latte/RaptorHUD.layout.latte"
    latte-dock --import-layout \
       "$HOME/.config/latte/RaptorHUD.layout.latte" &>/dev/null &
fi

# Reload KWin + Plasma shell
qdbus org.kde.KWin /KWin reconfigure 2>/dev/null || true
kbuildsycoca6 --noincremental 2>/dev/null || true

echo "RAPTOR_HUD_APPLIED"
EOF
chmod +x /usr/lib/raptor/hud/apply-plasma-panel.sh

# ── GTK theme to match (for GTK apps inside KDE) ─────────────────────────────
mkdir -p /usr/share/themes/RaptorOS-GTK/gtk-3.0
mkdir -p /usr/share/themes/RaptorOS-GTK/gtk-4.0

cat << 'EOF' > /usr/share/themes/RaptorOS-GTK/gtk-3.0/gtk.css
/* RaptorOS GTK3 theme — stealth dark + electric blue accents */
@define-color bg_color #151a20;
@define-color fg_color #c8d6e8;
@define-color base_color #0d0f12;
@define-color text_color #c8d6e8;
@define-color selected_bg_color #1e90ff;
@define-color selected_fg_color #ffffff;
@define-color tooltip_bg_color #0d0f12;
@define-color tooltip_fg_color #c8d6e8;
@define-color borders #2a3444;
@define-color warning_color #f5a623;
@define-color success_color #2ec27e;
@define-color error_color #dc3232;
@define-color accent #1e90ff;

* {
    -gtk-icon-style: symbolic;
}

window, .background {
    background-color: @bg_color;
    color: @fg_color;
}

headerbar {
    background: linear-gradient(to bottom, #1c2330, #151a20);
    border-bottom: 1px solid #1e90ff;
    padding: 4px 8px;
    min-height: 36px;
}

headerbar .title {
    font-weight: 600;
    color: @fg_color;
    letter-spacing: 0.04em;
}

button {
    background: #1c2330;
    border: 1px solid @borders;
    color: @fg_color;
    border-radius: 2px;
    padding: 4px 12px;
    transition: all 120ms ease;
}

button:hover {
    background: #1e4a7a;
    border-color: @accent;
    color: white;
}

button.suggested-action {
    background: @accent;
    border-color: @accent;
    color: white;
}

button.destructive-action {
    background: #8b1a1a;
    border-color: #cc3333;
    color: white;
}

entry {
    background: @base_color;
    border: 1px solid @borders;
    color: @fg_color;
    border-radius: 2px;
    padding: 4px 8px;
    caret-color: @accent;
}

entry:focus {
    border-color: @accent;
    box-shadow: 0 0 0 1px @accent;
}

treeview.view:selected,
row:selected {
    background-color: @selected_bg_color;
    color: @selected_fg_color;
}

scrollbar slider {
    background-color: #2a3444;
    border-radius: 2px;
    min-width: 6px;
    min-height: 6px;
}

scrollbar slider:hover {
    background-color: @accent;
}

tooltip {
    background-color: @tooltip_bg_color;
    border: 1px solid @borders;
    color: @tooltip_fg_color;
    border-radius: 2px;
}

menubar, .menubar {
    background-color: #1c2330;
    border-bottom: 1px solid @borders;
}

menu, .menu {
    background-color: #151a20;
    border: 1px solid @borders;
}

menu menuitem:hover {
    background-color: @accent;
    color: white;
}

notebook header {
    background-color: #1c2330;
    border-bottom: 1px solid @borders;
}

notebook header tab:checked {
    background-color: @base_color;
    border-bottom: 2px solid @accent;
}

progressbar progress {
    background-color: @accent;
    border-radius: 2px;
}

checkbutton check,
radiobutton radio {
    background: @base_color;
    border: 1px solid @borders;
}

checkbutton check:checked,
radiobutton radio:checked {
    background-color: @accent;
    border-color: @accent;
}

scale trough {
    background-color: #2a3444;
    border-radius: 2px;
    min-height: 4px;
}

scale highlight {
    background-color: @accent;
    border-radius: 2px;
}
EOF

# GTK4 uses the same palette via settings
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
IconTheme=RaptorOS-Icons
CursorTheme=Adwaita
ButtonLayout=close,minimize,maximize:

[KDE]
WidgetStyle=kvantum
EOF

# ── Kvantum theme (Qt app styling) ───────────────────────────────────────────
mkdir -p /usr/share/Kvantum/RaptorOS
cat << 'EOF' > /usr/share/Kvantum/RaptorOS/RaptorOS.kvconfig
[%General]
author=RaptorOS
comment=F-22 Raptor stealth dark theme
x11drag=all
alt_mnemonic=true
left_tabs=true
attach_last_tab=false
composite=true
menu_shadow_depth=6
spread_menuitems=false
tooltip_shadow_depth=4
popup_blurring=true
opaque=kaffeine,kmplayer
vertical_spin_indicators=false
spin_button_width=16
fill_rubberband=false
groupbox_top_label=false
button_width_from_label=true
contrast=1.0
intensity=1.0
saturation=1.0
no_window_pattern=false
reduce_window_opacity=0
reduce_menu_opacity=0

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
highlight.color=#1e90ff
inactive.highlight.color=#2a3444
text.color=#c8d6e8
window.text.color=#c8d6e8
button.text.color=#c8d6e8
disabled.text.color=#5a6a7e
tooltip.base.color=#0d0f12
tooltip.text.color=#c8d6e8
link.color=#1e90ff
link.visited.color=#8c64dc
progress.indicator.text.color=#ffffff

[Hacks]
transparent_ktitle_label=true
transparent_dolphin_view=false
blur_konsole=true
transparent_pcmanfm_view=false
transparent_pcmanfm_sidepane=false
lxqtmainmenu_iconsize=0
normal_default_pushbutton=false
single_top_toolbar=false
tint_on_mouseover=0
no_selection_tint=false
no_focus_rect=false
iconless_pushbutton=false
iconless_menu=false
kinetic_scrolling=false
middle_click_scroll=false
EOF

cat << 'EOF' > /usr/share/Kvantum/RaptorOS/RaptorOS.svg
<!-- Minimal Kvantum SVG — inherits panel geometry from kvconfig -->
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 200 200">
  <rect width="200" height="200" fill="#1c2330"/>
</svg>
EOF

# ── Firstboot user service ────────────────────────────────────────────────────
# Runs apply-plasma-panel.sh once as the user on first login.
mkdir -p /usr/lib/systemd/user
cat << 'EOF' > /usr/lib/systemd/user/raptor-hud-apply.service
[Unit]
Description=Raptor HUD — Apply KDE theme on first login
After=plasma-plasmashell.service
ConditionPathExists=!/var/lib/raptor-hud-applied

[Service]
Type=oneshot
ExecStart=/usr/lib/raptor/hud/apply-plasma-panel.sh
ExecStartPost=/bin/touch /var/lib/raptor-hud-applied
RemainAfterExit=yes

[Install]
WantedBy=default.target
EOF

# Enable the user service system-wide
systemctl --global enable raptor-hud-apply.service 2>/dev/null || true

# ── Konsole profile (terminal to match) ──────────────────────────────────────
mkdir -p /usr/share/konsole
cat << 'EOF' > /usr/share/konsole/RaptorOS.profile
[Appearance]
ColorScheme=RaptorOS
Font=JetBrains Mono,11,-1,5,50,0,0,0,0,0
LineSpacing=2
UseFontLineChararacters=false

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

# Konsole color scheme matching RaptorOS palette
mkdir -p /usr/share/konsole
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
Color=30,144,255

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
Wallpaper=
WallpaperOpacity=1
EOF

# ── recipe.yml additions reminder ────────────────────────────────────────────
cat << 'EOF'
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  ADD TO recipe.yml rpm-ostree install block:
    - latte-dock
    - kvantum
    - kvantum-qt5
    - papirus-icon-theme   # base for RaptorOS-Icons inheritance
    - jetbrains-mono-fonts # Konsole font

  ADD TO recipe.yml scripts block:
    - raptor-hud.sh
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EOF

echo "RAPTOR_HUD_READY"
