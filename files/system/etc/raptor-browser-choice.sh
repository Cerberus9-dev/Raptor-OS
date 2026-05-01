#!/bin/bash

# Only run once
DONE_FILE="$HOME/.config/raptor-browser-choice-done"
[ -f "$DONE_FILE" ] && exit 0

CHOICE=$(zenity --list \
  --title="Welcome to Raptor OS" \
  --text="Choose your default browser:" \
  --radiolist \
  --column="" --column="Browser" \
  TRUE "Firefox" \
  FALSE "Brave" \
  --width=300 --height=200)

if [ "$CHOICE" = "Brave" ]; then
  flatpak install -y flathub com.brave.Browser
  xdg-settings set default-web-browser com.brave.Browser.desktop
elif [ "$CHOICE" = "Firefox" ]; then
  xdg-settings set default-web-browser org.mozilla.firefox.desktop
fi

touch "$DONE_FILE"
