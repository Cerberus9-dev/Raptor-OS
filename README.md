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

> If you already have Raptor OS installed, just run `rpm-ostree update` and reboot to get the latest version.

If you already have Bazzite installed and want to switch without reinstalling:

**Step 1:**
```
rpm-ostree rebase ostree-unverified-registry:ghcr.io/cerberus9-dev/raptor-os:latest
```
**Step 2:**
```
systemctl reboot
```
**Step 3:**
```
rpm-ostree rebase ostree-image-signed:docker://ghcr.io/cerberus9-dev/raptor-os:latest
```
**Step 4:**
```
systemctl reboot
```

## What's Included

**Browsers & Communication**
- Firefox or Brave Browser (optional, chosen at first boot), Discord, Thunderbird

**Gaming**
- Steam, Lutris, Heroic Games Launcher, ProtonUp-Qt, Bottles, Wine, Winetricks, Gamemode, GOverlay

**Creative**
- GIMP, Inkscape, Krita, Kdenlive, Shotcut, OBS Studio, Darktable, Audacity, Blender

**Productivity**
- LibreOffice, Joplin, MarkText, Calibre, KCalc, Boatswain

**Development**
- VSCodium, Git, GitHub CLI, Node.js, Python 3, GCC, CMake, Neovim, Podman, Pods

**System Tools**
- Fastfetch, BleachBit, Filelight, Mission Center, Flatseal, Variety, Kamoso

**Performance**
- Automatic GPU detection and optimization (AMD/NVIDIA/Intel/iGPU)
- Raptor Profile Switcher — switch between Auto, Max Performance and Power Saving
- RAM spike protection for large game maps
- Unity/Proton memory fixes — 32-bit address space expansion and shared memory for games like Unturned
- OOM kill tuning — kernel targets the leaking process instead of unrelated victims
- WiFi stability fixes
- zram memory compression with optimized kernel tunables
- Cloudflare DNS for faster browsing
- Aggressive Firefox memory optimization

## Built With

- [BlueBuild](https://blue-build.org) — custom image build system
- [Bazzite](https://bazzite.gg) — base image

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for the full changelog.
