FROM ghcr.io/ublue-os/bazzite:stable

# 1. Add Brave Repo manually (This bypasses the broken dnf commands)
RUN printf "[brave-browser]\nname=Brave Browser\nbaseurl=https://brave-browser-rpm-release.s3.brave.com/x86_64/\nenabled=1\ngpgcheck=0" > /etc/yum.repos.d/brave.repo

# 2. Install Ordnance (Verified package names only)
RUN dnf install -y brave-browser fastfetch plasma-systemmonitor

# 3. Inject HUD Visuals
RUN mkdir -p /etc/skel/.config && \
    echo -e "[General]\nColorScheme=BreezeDark\nAccentColor=51,255,51" > /etc/skel/.config/kdeglobals

# 4. Cleanup to save space
RUN dnf clean all
