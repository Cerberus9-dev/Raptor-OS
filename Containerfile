FROM ghcr.io/ublue-os/bazzite:stable

# 1. Setup Repositories (The "Maps")
# We download the official Brave map file directly to the system
RUN curl -Lo /etc/yum.repos.d/brave-browser.repo https://brave-browser-rpm-release.s3.brave.com/brave-browser.repo

# 2. Install Ordnance (The Apps)
# Brave, Fastfetch (HUD Info), and System Monitor
RUN dnf install -y brave-browser fastfetch plasma-systemmonitor

# 3. Inject HUD DNA (Neon Green Visuals)
RUN mkdir -p /etc/skel/.config && \
    echo -e "[General]\nColorScheme=BreezeDark\nAccentColor=51,255,51" > /etc/skel/.config/kdeglobals

# 4. Cleanup
RUN dnf clean all
