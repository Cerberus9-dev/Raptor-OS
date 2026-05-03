# Raptor OS

A custom Bazzite-based Linux distribution with a neon green KDE theme, gaming tools, and productivity apps.

> ⚠️ **HEAVY W.I.P — Feedback is appreciated!**

> ℹ️ **This is NOT a live OS.** It requires a separate drive, replacing your current OS, or dual booting. For dual booting, make sure you have 40-50GB available. If you don't have space or time, it can be run in a VM for testing first.

## Installation

Download the latest ISO from [Internet Archive](https://archive.org/details/raptor-os_202605), then flash it to a USB drive using one of the following:

- [Rufus](https://rufus.ie/en/) — when prompted, select **DD image mode** and **GPT** partition scheme
- [Ventoy](https://www.ventoy.net)
- [Fedora Media Writer](https://github.com/FedoraQt/MediaWriter) — guaranteed to work if others fail

## Rebasing to Raptor OS

If you already have Bazzite installed and want to switch to Raptor OS without reinstalling, run these commands one at a time:
rpm-ostree rebase ostree-unverified-registry:ghcr.io/cerberus9-dev/raptor-os:latest
systemctl reboot
rpm-ostree rebase ostree-image-signed:docker://ghcr.io/cerberus9-dev/raptor-os:latest
systemctl reboot

## What's Included

- **Firefox** — default web browser with performance tweaks
- **Brave Browser** — optional, chosen on first boot
- **Fastfetch** — system info display
- **Plasma System Monitor** — KDE system monitoring
- **Neon Green KDE Theme** — custom Breeze Dark theme with green accents
- **Discord, VSCodium, Heroic Games Launcher** — communication and gaming
- **LibreOffice, Thunderbird** — office and email
- **Kdenlive, GIMP, Inkscape, Krita** — creative tools
- **VLC, OBS Studio** — media and streaming
- **Wine, Winetricks** — Windows app compatibility
- **Variety** — wallpaper changer
- **Development Tools** — Git, GitHub CLI, Node.js, Python 3, GCC, Make

## Built With

- [BlueBuild](https://blue-build.org) — custom image build system
- [Bazzite](https://bazzite.gg) — base image

## Changelog

See https://github.com/Cerberus9-dev/Raptor-OS/blob/main/changelog.md for the full changelog.
