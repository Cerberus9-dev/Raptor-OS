FROM ghcr.io/ublue-os/bazzite:stable

# 1. Setup Brave repo
RUN curl -Lo /etc/yum.repos.d/brave-browser.repo \
    https://brave-browser-rpm-release.s3.brave.com/brave-browser.repo

# 2. Install apps using rpm-ostree (correct tool for OSTree-based images)
RUN rpm-ostree install -y brave-browser fastfetch plasma-systemmonitor && \
    ostree container commit

# 3. Inject neon green KDE theme
RUN mkdir -p /etc/skel/.config && \
    echo -e "[General]\nColorScheme=BreezeDark\nAccentColor=51,255,51" \
    > /etc/skel/.config/kdeglobals
