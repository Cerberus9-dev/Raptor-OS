#!/usr/bin/bash

# Path to the file that tracks if the browser was already chosen
CHOICE_FILE="/var/lib/raptor-browser-choice-done"

# If the choice was already made, exit
if [ -f "$CHOICE_FILE" ]; then
    exit 0
fi

# Present a menu
echo "====================================="
echo "   Raptor OS - Browser Choice       "
echo "====================================="
echo "Please choose your default browser:"
echo "1) Brave"
echo "2) Firefox"
echo "====================================="

read -p "Enter your choice (1 or 2): " choice

case $choice in
    1)
        echo "Installing Brave..."
        rpm-ostree install brave-browser
        ;;
    2)
        echo "Installing Firefox..."
        rpm-ostree install firefox
        ;;
    *)
        echo "Invalid choice. No browser will be installed."
        exit 1
        ;;
esac

# Mark the choice as done
touch "$CHOICE_FILE"
echo "Browser installation complete. Please reboot for changes to take effect."
