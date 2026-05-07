#!/bin/bash
CHOICE_FILE="/var/lib/raptor-browser-choice-done"
if [ -f "$CHOICE_FILE" ]; then
    exit 0
fi

CHOICE=$(zenity --list \
  --title="Welcome to Raptor OS" \
  --text="Choose your default browser:" \
  --radiolist \
  --column="" --column="Browser" \
  TRUE "Firefox" \
  FALSE "Brave" \
  --width=300 --height=200)

case $CHOICE in
    "Brave")
        flatpak install -y flathub com.brave.Browser
        xdg-settings set default-web-browser com.brave.Browser.desktop
        ;;
    "Firefox")
        xdg-settings set default-web-browser org.mozilla.firefox.desktop
        ;;
    *)
        exit 0  # user cancelled — not an error
        ;;
esac

touch "$CHOICE_FILE"
