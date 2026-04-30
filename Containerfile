FROM ghcr.io/ublue-os/bazzite:stable

# 1. Install Ordnance
RUN dnf install -y https://brave-browser-rpm-release.s3.brave.com/x86_64/brave-browser.rpm && \
    dnf install -y fastfetch plasma-systemmonitor firewalld

# 2. Inject HUD Visuals
RUN mkdir -p /etc/skel/.config
RUN echo -e "[General]\nColorScheme=BreezeDark\nAccentColor=51,255,51" > /etc/skel/.config/kdeglobals

RUN dnf clean all
