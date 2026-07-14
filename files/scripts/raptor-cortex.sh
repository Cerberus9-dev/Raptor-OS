#!/bin/bash
set -e

# =============================================================================
# Raptor Cortex v4.1 — Unified Memory & Performance Management
# • RAM optimization with page cache management, compaction, zram recompress
# • Background service trimming/restoring for gaming
# • Seamless performance mode switching (no login required)
# • Game mode auto-suspend/resume via Cortex patterns
# • CPU boost management (complements GPU Profiler)
# • Per-mode kernel tuning (power/balanced/performance)
# • Battery slider passthrough via power-profiles-daemon
# • PCIe ASPM, NVMe power states, USB autosuspend, runtime PM
# =============================================================================

# ── Custom icon ───────────────────────────────────────────────────────────────
mkdir -p /usr/share/icons/hicolor/scalable/apps
cat << 'SVGEOF' > /usr/share/icons/hicolor/scalable/apps/raptor-cortex.svg
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64">
  <defs>
    <radialGradient id="bg" cx="50%" cy="50%" r="50%">
      <stop offset="0%" stop-color="#7c3aed"/>
      <stop offset="100%" stop-color="#4c1d95"/>
    </radialGradient>
    <radialGradient id="core" cx="50%" cy="50%" r="50%">
      <stop offset="0%" stop-color="#c4b5fd"/>
      <stop offset="100%" stop-color="#7c3aed"/>
    </radialGradient>
  </defs>
  <circle cx="32" cy="32" r="30" fill="url(#bg)"/>
  <circle cx="32" cy="32" r="24" fill="none" stroke="#a78bfa" stroke-width="1.5"
          stroke-dasharray="12 4" stroke-linecap="round"/>
  <line x1="32" y1="10" x2="32" y2="18" stroke="#c4b5fd" stroke-width="2" stroke-linecap="round"/>
  <line x1="32" y1="46" x2="32" y2="54" stroke="#c4b5fd" stroke-width="2" stroke-linecap="round"/>
  <line x1="10" y1="32" x2="18" y2="32" stroke="#c4b5fd" stroke-width="2" stroke-linecap="round"/>
  <line x1="46" y1="32" x2="54" y2="32" stroke="#c4b5fd" stroke-width="2" stroke-linecap="round"/>
  <line x1="16.7" y1="16.7" x2="22.4" y2="22.4" stroke="#c4b5fd" stroke-width="1.5" stroke-linecap="round"/>
  <line x1="41.6" y1="41.6" x2="47.3" y2="47.3" stroke="#c4b5fd" stroke-width="1.5" stroke-linecap="round"/>
  <line x1="47.3" y1="16.7" x2="41.6" y2="22.4" stroke="#c4b5fd" stroke-width="1.5" stroke-linecap="round"/>
  <line x1="22.4" y1="41.6" x2="16.7" y2="47.3" stroke="#c4b5fd" stroke-width="1.5" stroke-linecap="round"/>
  <circle cx="32" cy="32" r="9" fill="url(#core)"/>
  <path d="M 29 26 L 35 26 L 33 31 L 36 31 L 29 40 L 31 33 L 28 33 Z"
        fill="white" opacity="0.95"/>
</svg>
SVGEOF

gtk-update-icon-cache /usr/share/icons/hicolor 2>/dev/null || true

# ── Privileged helper ─────────────────────────────────────────────────────────
mkdir -p /usr/lib/raptor

cat << 'EOF' > /usr/lib/raptor/cortex-helper
#!/bin/bash
# Args: CACHE COMPACT ZRAM OOM DEEP SWAP THP CPU | trim-background |
#       restore-background | set-mode <power_saving|balanced|performance>
ACTION="${1:-help}"

# ── Hardware power helpers ────────────────────────────────────────────────────

_apply_pcie_aspm() {
    # powersave | performance | default
    local P="$1"
    [ -f /sys/module/pcie_aspm/parameters/policy ] && \
        echo "$P" > /sys/module/pcie_aspm/parameters/policy 2>/dev/null || true
}

_apply_nvme_power() {
    # min_power | max_performance | auto
    local S="$1"
    for f in /sys/class/nvme/nvme*/power/control \
              /sys/bus/pci/devices/*/nvme/nvme*/power/control; do
        [ -f "$f" ] && echo "$S" > "$f" 2>/dev/null || true
    done
}

_apply_usb_autosuspend() {
    # 1 = enable (power save), 0 = disable (performance)
    if [ "$1" = "1" ]; then
        for d in /sys/bus/usb/devices/*/power/autosuspend_delay_ms; do
            echo 2000 > "$d" 2>/dev/null || true
        done
        for c in /sys/bus/usb/devices/*/power/control; do
            echo auto > "$c" 2>/dev/null || true
        done
    else
        for c in /sys/bus/usb/devices/*/power/control; do
            echo on > "$c" 2>/dev/null || true
        done
    fi
}

_apply_runtime_pm() {
    # auto | on
    local P="$1"
    for f in /sys/bus/pci/devices/*/power/control; do
        echo "$P" > "$f" 2>/dev/null || true
    done
}

_apply_sata_link_power() {
    # min_power | medium_power | max_performance
    local P="$1"
    for f in /sys/class/scsi_host/host*/link_power_management_policy; do
        echo "$P" > "$f" 2>/dev/null || true
    done
}

_apply_epp() {
    # energy_performance_preference: power | balance_power | balance_performance | performance
    # This is the biggest single battery saver on Intel HWP and AMD P-state systems.
    # Sets a hardware-level hint that goes directly to the processor's internal
    # P-state controller, separate from the software governor.
    local EPP="$1"
    for cpu_pol in /sys/devices/system/cpu/cpufreq/policy*; do
        local f="$cpu_pol/energy_performance_preference"
        if [ -f "$f" ]; then
            echo "$EPP" > "$f" 2>/dev/null || true
        fi
    done
    # Intel energy_perf_bias: 0=performance, 15=power (legacy interface)
    if [ -f /sys/devices/system/cpu/cpu0/power/energy_perf_bias ]; then
        case "$EPP" in
            power)               BIAS=15 ;;
            balance_power)       BIAS=10 ;;
            balance_performance) BIAS=6  ;;
            performance)         BIAS=0  ;;
            *)                   BIAS=6  ;;
        esac
        for f in /sys/devices/system/cpu/cpu*/power/energy_perf_bias; do
            echo "$BIAS" > "$f" 2>/dev/null || true
        done
    fi
}

_apply_cpu_max_freq_pct() {
    # Cap scaling_max_freq to a percentage of cpuinfo_max_freq.
    # Pass 100 to restore to physical maximum.
    local PCT="$1"
    for pol in /sys/devices/system/cpu/cpufreq/policy*; do
        MAX=$(cat "$pol/cpuinfo_max_freq" 2>/dev/null || echo 0)
        if [ "$MAX" -gt 0 ]; then
            if [ "$PCT" -eq 100 ]; then
                echo "$MAX" > "$pol/scaling_max_freq" 2>/dev/null || true
            else
                TARGET=$(( MAX * PCT / 100 ))
                echo "$TARGET" > "$pol/scaling_max_freq" 2>/dev/null || true
            fi
        fi
    done
}

_apply_platform_profile() {
    # low-power | balanced | performance
    # Firmware-level power coordination: fan curves, VRM limits, thermal targets.
    # More effective than software tuning alone on supported laptops.
    local PROF="$1"
    if [ -f /sys/firmware/acpi/platform_profile ]; then
        # Map our names to platform_profile values
        case "$PROF" in
            power_saving) echo "low-power"    > /sys/firmware/acpi/platform_profile 2>/dev/null || true ;;
            balanced)     echo "balanced"     > /sys/firmware/acpi/platform_profile 2>/dev/null || true ;;
            performance)  echo "performance"  > /sys/firmware/acpi/platform_profile 2>/dev/null || true ;;
        esac
    fi
}

_apply_net_runtime_pm() {
    # Enable runtime power management for network devices.
    # This powers down the NIC hardware when idle — does NOT disconnect WiFi.
    # The driver keeps the association; the radio powers down between packets.
    local MODE="$1"   # auto | on
    for dev in /sys/class/net/*/device/power/control; do
        echo "$MODE" > "$dev" 2>/dev/null || true
    done
}

_apply_audio_powersave() {
    # 1 or 0
    for f in /sys/module/snd_hda_intel/parameters/power_save \
              /sys/module/snd_ac97_codec/parameters/power_save; do
        [ -f "$f" ] && echo "$1" > "$f" 2>/dev/null || true
    done
}

# ── cgroup v2 memory.reclaim — the actual "free RAM now" lever ────────────────
# drop_caches only touches kernel-internal page/dentry/inode caches, which on
# a freshly-booted system are often small (tens of MB). The vast majority of
# "used" RAM on a gaming desktop is ANONYMOUS memory held by running apps —
# Firefox tabs, Discord/Vesktop, Steam, etc. memory.reclaim (kernel 5.10+,
# present on all Fedora/Bazzite kernels) asks the kernel to walk the LRU of
# every process in a cgroup, write back dirty pages, drop clean pages, and
# swap out cold anonymous pages to zram. This is what actually moves the
# "Freed XXX MB" number in the Cortex UI.
#
# NEVER write to the root cgroup's memory.reclaim — that walks ALL processes
# including system services and can reclaim pages a game is actively using.
# Scoped to user.slice: covers Firefox/Vesktop/Steam/etc., not the kernel
# or system daemons.
_reclaim_user_slice() {
    local amount="${1:-1073741824}"  # bytes; default 1 GiB request
    local wrote=0
    for f in /sys/fs/cgroup/user.slice/memory.reclaim \
             /sys/fs/cgroup/user.slice/user-*.slice/memory.reclaim \
             /sys/fs/cgroup/user.slice/user-*.slice/user@*.service/memory.reclaim; do
        if [ -w "$f" ]; then
            echo "$amount" > "$f" 2>/dev/null && wrote=1
        fi
    done
    return 0
}

# FIX: clear Powerdevil session action so switching to power-saver
# doesn't trigger a logout/suspend. Patches every user's config and
# tells the running daemon to reload.
_clear_powerdevil_session_action() {
    while IFS=: read -r _ _ uid _ _ home _; do
        [ "$uid" -lt 1000 ] && continue
        [ -d "$home" ] || continue
        PPRC="$home/.config/powermanagementprofilesrc"
        [ -f "$PPRC" ] || continue
        [ -f "${PPRC}.raptorbak" ] || cp "$PPRC" "${PPRC}.raptorbak"
        for grp in "Battery][SuspendSession" "LowBattery][SuspendSession" \
                   "AC][SuspendSession"; do
            if grep -q "\[$grp\]" "$PPRC" 2>/dev/null; then
                sed -i "/\[$grp\]/,/^\[/ s/^idleTime=.*/idleTime=0/"     "$PPRC" 2>/dev/null || true
                sed -i "/\[$grp\]/,/^\[/ s/^suspendType=.*/suspendType=0/" "$PPRC" 2>/dev/null || true
            fi
        done
        if grep -q "\[Battery\]\[HandleButtonEvents\]" "$PPRC" 2>/dev/null; then
            sed -i "/\[Battery\]\[HandleButtonEvents\]/,/^\[/ s/^powerButtonAction=.*/powerButtonAction=0/" \
                "$PPRC" 2>/dev/null || true
        fi
    done < /etc/passwd
    # Tell Powerdevil daemon to reload
    for uid in $(loginctl list-users --no-legend 2>/dev/null | awk '{print $1}' || true); do
        # sudo + env: reliably passes the session bus path to the target user.
        # runuser does not inherit the session environment consistently on
        # Bazzite; bare env-prefix (VAR=x sudo ...) is not interpreted by sudo.
        RUNTIME_DIR="/run/user/$uid"
        if [ -d "$RUNTIME_DIR" ]; then
            sudo -u "#$uid" \
                env DBUS_SESSION_BUS_ADDRESS="unix:path=$RUNTIME_DIR/bus" \
                dbus-send --session \
                    --dest=org.kde.Solid.PowerManagement \
                    /org/kde/Solid/PowerManagement \
                    org.kde.Solid.PowerManagement.refreshStatus \
                    2>/dev/null || true
        fi
    done
}

case "$ACTION" in
    # ── RAM optimization flags ─────────────────────────────────────────────
    0|1|2|3|4|5|6|7|8)
        DO_CACHE="${1:-0}";  DO_COMPACT="${2:-0}"; DO_ZRAM="${3:-0}"
        DO_OOM="${4:-0}";    DO_DEEP="${5:-0}";    DO_SWAP="${6:-0}"
        DO_THP="${7:-0}";    DO_CPU="${8:-0}"

        if [ "$DO_CACHE" = "1" ]; then
            sync || true
            echo 3 > /proc/sys/vm/drop_caches 2>/dev/null || true
            echo 2 > /proc/sys/vm/drop_caches 2>/dev/null || true
            echo 1 > /proc/sys/vm/drop_caches 2>/dev/null || true
            # Reclaim ~1 GiB from running user apps (Firefox, Vesktop, Steam, etc.)
            _reclaim_user_slice 1073741824
        fi
        [ "$DO_COMPACT" = "1" ] && echo 1 > /proc/sys/vm/compact_memory 2>/dev/null || true
        if [ "$DO_ZRAM" = "1" ]; then
            echo 3 > /proc/sys/vm/drop_caches 2>/dev/null || true
            echo recompress > /sys/block/zram0/recompress 2>/dev/null || true
            echo writeback   > /sys/block/zram0/writeback   2>/dev/null || true
        fi
        if [ "$DO_OOM" = "1" ]; then
            for proc in plasmashell kwin_wayland kwin_x11 ksmserver kded6; do
                for pid in $(pgrep -x "$proc" 2>/dev/null || true); do
                    echo -800 > /proc/$pid/oom_score_adj 2>/dev/null || true
                done
            done
            for proc in chrome chromium brave firefox; do
                for pid in $(pgrep -x "$proc" 2>/dev/null || true); do
                    echo 300 > /proc/$pid/oom_score_adj 2>/dev/null || true
                done
            done
        fi
        if [ "$DO_DEEP" = "1" ]; then
            echo never > /sys/kernel/mm/transparent_hugepage/enabled 2>/dev/null || true
            sleep 0.5
            echo madvise > /sys/kernel/mm/transparent_hugepage/enabled 2>/dev/null || true
            echo 1 > /proc/sys/kernel/numa_balancing 2>/dev/null || true
            echo 3 > /proc/sys/vm/drop_caches 2>/dev/null || true
            echo 1 > /proc/sys/vm/compact_memory 2>/dev/null || true
            # Deep clean: request a much larger reclaim (~3 GiB). The kernel
            # reclaims at most what's actually reclaimable — over-requesting
            # is harmless, it just means "give back everything you can".
            _reclaim_user_slice 3221225472
        fi
        if [ "$DO_SWAP" = "1" ]; then
            CURRENT=$(cat /proc/sys/vm/swappiness 2>/dev/null || echo 80)
            echo 100 > /proc/sys/vm/swappiness 2>/dev/null || true
            sleep 1
            echo "$CURRENT" > /proc/sys/vm/swappiness 2>/dev/null || true
        fi
        if [ "$DO_THP" = "1" ]; then
            echo madvise       > /sys/kernel/mm/transparent_hugepage/enabled 2>/dev/null || true
            echo defer+madvise > /sys/kernel/mm/transparent_hugepage/defrag  2>/dev/null || true
        fi
        [ "$DO_CPU" = "1" ] && echo 1 > /sys/devices/system/cpu/cpufreq/boost 2>/dev/null || true
        ;;

    # ── Per-mode kernel tuning ─────────────────────────────────────────────
    set-mode)
        MODE="${2:-balanced}"

        # ── Unconditional reset BEFORE applying the target mode ──────────────
        # Guards against drift: if a previous mode switch partially failed to
        # restore EPP / max frequency / platform profile (e.g. one sysfs write
        # silently failed), the system could stay stuck throttled even after
        # switching to Performance or Balanced. This block always runs first,
        # bringing the CPU to a full-power known state, before the target
        # mode's case below applies whatever throttling IT wants. This means
        # every mode switch is a full reset + reapply, never an incremental
        # patch on top of unknown prior state.
        _apply_cpu_max_freq_pct 100
        _apply_epp balance_performance
        echo 1 > /sys/devices/system/cpu/cpufreq/boost 2>/dev/null || true

        case "$MODE" in
            power_saving)
                # FIX: clear Powerdevil logout action BEFORE switching profile
                _clear_powerdevil_session_action

                echo 180  > /proc/sys/vm/swappiness                2>/dev/null || true
                echo 5    > /proc/sys/vm/dirty_ratio               2>/dev/null || true
                echo 2    > /proc/sys/vm/dirty_background_ratio    2>/dev/null || true
                # Longer writeback: 150 s means fewer storage controller wake-ups.
                # Storage (especially NVMe) goes into deep low-power states between
                # writes; longer intervals = more time in deep sleep.
                echo 15000 > /proc/sys/vm/dirty_writeback_centisecs 2>/dev/null || true
                echo 60000 > /proc/sys/vm/dirty_expire_centisecs    2>/dev/null || true
                # laptop_mode=5: more aggressive disk caching, even less frequent
                # actual writes to storage (5 is max useful value on modern kernels)
                echo 5    > /proc/sys/vm/laptop_mode                2>/dev/null || true

                # CPU: governor + turbo off
                echo 0 > /sys/devices/system/cpu/cpufreq/boost      2>/dev/null || true
                for gov in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
                    echo powersave > "$gov" 2>/dev/null || true
                done

                # EPP = power: tells the HWP/AMD-pstate hardware controller to
                # strongly prefer efficiency. This is the single biggest battery
                # saver on Intel (12th gen+) and AMD (Ryzen 4000+) — can cut CPU
                # power draw 20-40% vs governor alone. powersave governor without
                # EPP still lets the CPU hit high P-states under burst load.
                _apply_epp power

                # Cap max frequency to 65% of physical max — prevents high-freq
                # bursts under light loads. Restore with _apply_cpu_max_freq_pct 100
                _apply_cpu_max_freq_pct 65

                # Firmware-level power profile: coordinates fan curves, VRM limits,
                # and thermal targets at the ACPI/EC level. More effective than any
                # single software setting on supported laptops (ThinkPad, ASUS, etc.)
                _apply_platform_profile power_saving

                echo never > /sys/kernel/mm/transparent_hugepage/enabled 2>/dev/null || true

                _apply_pcie_aspm       powersave
                _apply_nvme_power      min_power
                _apply_usb_autosuspend 1
                _apply_runtime_pm      auto
                _apply_sata_link_power min_power
                _apply_audio_powersave 1

                # HDA audio powersave controller: separate from power_save flag.
                # Allows the HD-audio controller itself (not just the codec) to
                # power down — saves ~0.5-1 W on systems with HDA audio hardware.
                echo Y > /sys/module/snd_hda_intel/parameters/power_save_controller                     2>/dev/null || true

                # Network device runtime PM: powers down NIC hardware between packets.
                # Does NOT disconnect WiFi — the driver keeps the association alive;
                # only the radio hardware powers down during idle periods.
                _apply_net_runtime_pm auto

                powerprofilesctl set power-saver 2>/dev/null || true
                ;;

            balanced)
                # swappiness=30: lean toward keeping anonymous memory in RAM
                # while still allowing some swapping for memory pressure relief.
                echo 30   > /proc/sys/vm/swappiness                2>/dev/null || true
                echo 20   > /proc/sys/vm/dirty_ratio               2>/dev/null || true
                echo 8    > /proc/sys/vm/dirty_background_ratio    2>/dev/null || true
                echo 1500 > /proc/sys/vm/dirty_writeback_centisecs 2>/dev/null || true
                echo 1500 > /proc/sys/vm/dirty_expire_centisecs    2>/dev/null || true
                echo 0    > /proc/sys/vm/laptop_mode               2>/dev/null || true

                echo 0 > /sys/devices/system/cpu/cpufreq/boost     2>/dev/null || true
                for gov in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
                    echo schedutil > "$gov" 2>/dev/null || true
                done

                # Restore EPP and max_freq if coming from power_saving
                _apply_epp              balance_power
                _apply_cpu_max_freq_pct 100
                _apply_platform_profile balanced

                echo madvise       > /sys/kernel/mm/transparent_hugepage/enabled 2>/dev/null || true
                echo defer+madvise > /sys/kernel/mm/transparent_hugepage/defrag  2>/dev/null || true

                _apply_pcie_aspm       default
                _apply_nvme_power      auto
                _apply_usb_autosuspend 1
                _apply_runtime_pm      auto
                _apply_sata_link_power medium_power
                _apply_audio_powersave 1

                # Restore audio controller to on (balanced doesn't need it saving power)
                echo N > /sys/module/snd_hda_intel/parameters/power_save_controller                     2>/dev/null || true
                _apply_net_runtime_pm on

                powerprofilesctl set balanced 2>/dev/null || true
                ;;

            performance)
                # swappiness=5: strongly prefer keeping all game data in RAM.
                # dirty_ratio=25: buffer up to 25% of RAM as dirty pages before
                # any synchronous write stall — games write saves/logs rarely so
                # a large dirty window avoids I/O stalls during gameplay.
                echo 5   > /proc/sys/vm/swappiness                 2>/dev/null || true
                echo 25  > /proc/sys/vm/dirty_ratio                2>/dev/null || true
                echo 10  > /proc/sys/vm/dirty_background_ratio     2>/dev/null || true
                echo 500 > /proc/sys/vm/dirty_writeback_centisecs  2>/dev/null || true
                echo 500 > /proc/sys/vm/dirty_expire_centisecs     2>/dev/null || true
                echo 0   > /proc/sys/vm/laptop_mode                2>/dev/null || true

                # EPP = performance: full hardware P-state performance mode
                _apply_epp              performance
                # Restore max freq to physical maximum (in case power_saving capped it)
                _apply_cpu_max_freq_pct 100
                _apply_platform_profile performance

                # Restore audio controller and net PM to full power
                echo N > /sys/module/snd_hda_intel/parameters/power_save_controller                     2>/dev/null || true
                _apply_net_runtime_pm on
                echo 500 > /proc/sys/vm/dirty_writeback_centisecs  2>/dev/null || true
                echo 500 > /proc/sys/vm/dirty_expire_centisecs     2>/dev/null || true
                echo 0   > /proc/sys/vm/laptop_mode                2>/dev/null || true

                echo 1 > /sys/devices/system/cpu/cpufreq/boost     2>/dev/null || true
                for gov in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
                    echo performance > "$gov" 2>/dev/null || true
                done
                echo madvise       > /sys/kernel/mm/transparent_hugepage/enabled 2>/dev/null || true
                echo defer+madvise > /sys/kernel/mm/transparent_hugepage/defrag  2>/dev/null || true

                _apply_pcie_aspm       performance
                _apply_nvme_power      max_performance
                _apply_usb_autosuspend 0
                _apply_runtime_pm      on
                _apply_sata_link_power max_performance
                _apply_audio_powersave 0

                sync || true
                echo 1 > /proc/sys/vm/drop_caches    2>/dev/null || true
                echo 1 > /proc/sys/vm/compact_memory 2>/dev/null || true

                powerprofilesctl set performance 2>/dev/null || true
                ;;
        esac
        ;;

    # ── Background trimming for gaming ─────────────────────────────────────
    trim-background)
        sync || true
        echo 1 > /proc/sys/vm/drop_caches    2>/dev/null || true
        echo 1 > /proc/sys/vm/compact_memory 2>/dev/null || true
        # Reclaim ~1.5 GiB from background apps before the game starts —
        # frees real RAM the game can use, not just kernel caches.
        _reclaim_user_slice 1610612736
        # irqbalance: switch to per-CPU interrupt affinity for gaming.
        # Stops irqbalance from moving NIC/audio IRQs away from the CPU
        # the game is running on mid-frame.
        systemctl stop irqbalance.service 2>/dev/null || true
        # Hold /dev/cpu_dma_latency open for the duration of gaming.
        # IMPORTANT: closing the file descriptor immediately releases the PM
        # QoS constraint — a one-shot `echo 0 | tee` opens, writes, and closes
        # the FD in the same instant, so the constraint was released before
        # the game even started. This was a complete no-op in earlier versions.
        # Fixed: a backgrounded subshell holds the FD open via `exec`, keeping
        # the constraint active (CPU stays at C1 or shallower, ~100-300µs less
        # wake latency) until resume-background removes the sentinel file.
        rm -f /run/raptor-cpu-dma-latency-held
        (
            exec 9<>/dev/cpu_dma_latency
            echo 0 >&9
            touch /run/raptor-cpu-dma-latency-held
            while [ -f /run/raptor-cpu-dma-latency-held ]; do
                sleep 5
            done
        ) &>/dev/null &
        disown
        BACKGROUND_PROCS=(
            "tracker-miner" "tracker-store" "tracker3"
            "baloo_file" "baloo_file_extractor" "akonadi"
            "kded" "kdeconnectd" "gvfs" "zeitgeist"
            "tumblerd" "packagekitd" "apt-get" "dpkg"
            "updatedb" "mlocate" "snapd" "unattended-upgrade"
            "evolution" "gnome-software"
        )
        for proc in "${BACKGROUND_PROCS[@]}"; do
            pkill -STOP "$proc" 2>/dev/null || true
        done
        for proc in baloo tracker zeitgeist; do
            for pid in $(pgrep -x "$proc" 2>/dev/null); do
                ionice -c 3 -p "$pid" 2>/dev/null || true
                renice +15 -p "$pid" 2>/dev/null || true
            done
        done
        systemctl stop snapd.service   2>/dev/null || true
        systemctl stop fstrim.service  2>/dev/null || true
        balooctl6 suspend 2>/dev/null || balooctl suspend 2>/dev/null || true
        echo 6000 > /proc/sys/vm/dirty_writeback_centisecs 2>/dev/null || true
        ;;

    # ── Background restoration after gaming ────────────────────────────────
    restore-background)
        BACKGROUND_PROCS=(
            "tracker-miner" "tracker-store" "tracker3"
            "baloo_file" "baloo_file_extractor" "akonadi"
            "kded" "kdeconnectd" "gvfs" "zeitgeist"
            "tumblerd" "packagekitd" "evolution"
        )
        for proc in "${BACKGROUND_PROCS[@]}"; do
            pkill -CONT "$proc" 2>/dev/null || true
        done
        balooctl6 resume 2>/dev/null || balooctl resume 2>/dev/null || true
        systemctl start snapd.service  2>/dev/null || true
        # Restart irqbalance so it can redistribute IRQs across cores normally
        systemctl start irqbalance.service 2>/dev/null || true
        # Release the cpu_dma_latency hold — removes the sentinel file, which
        # the held-open subshell is polling for; it then exits and closes the
        # FD, releasing the PM QoS constraint so the CPU can idle normally again.
        rm -f /run/raptor-cpu-dma-latency-held
        echo 500 > /proc/sys/vm/dirty_writeback_centisecs 2>/dev/null || true
        ;;

    *)
        echo "Usage: cortex-helper [CACHE COMPACT ZRAM OOM DEEP SWAP THP CPU] | set-mode <power_saving|balanced|performance> | trim-background | restore-background"
        exit 1
        ;;
esac
exit 0
EOF
chmod +x /usr/lib/raptor/cortex-helper

# ── Sudoers ───────────────────────────────────────────────────────────────────
mkdir -p /etc/sudoers.d
cat << 'EOF' > /etc/sudoers.d/raptor-cortex
ALL ALL=(root) NOPASSWD: /usr/lib/raptor/cortex-helper
EOF
chmod 440 /etc/sudoers.d/raptor-cortex || true
visudo -cf /etc/sudoers.d/raptor-cortex || true

# ── Cortex suspend config ─────────────────────────────────────────────────────
mkdir -p /etc/raptor
cat << 'EOF' > /etc/raptor/cortex-suspend.conf
# Raptor Cortex — services to suspend during gaming
baloo_file
tracker
akonadiserver
kwalletd
kdeconnectd
kio_thumbnail
kactivitymanagerd
plasma-geolocation
kbuildsycoca
zeitgeist
evolution-data
gvfsd-metadata
colord
pipewire-media-session
EOF

# ── Gamemode hooks ────────────────────────────────────────────────────────────
cat << 'EOF' > /usr/lib/raptor/gamemode-start
#!/bin/bash
sudo /usr/lib/raptor/cortex-helper 1 1 1 1 0 0 0 1 2>/dev/null || true
sudo /usr/lib/raptor/cortex-helper trim-background 2>/dev/null || true
CONFIG=/etc/raptor/cortex-suspend.conf
[ -f "$CONFIG" ] || exit 0
while IFS= read -r pattern; do
    [ -z "$pattern" ] && continue
    case "$pattern" in "#"*) continue ;; esac
    pgrep -f "$pattern" > /dev/null 2>&1 && pkill -STOP -f "$pattern" 2>/dev/null || true
done < "$CONFIG"
EOF
chmod +x /usr/lib/raptor/gamemode-start

cat << 'EOF' > /usr/lib/raptor/gamemode-end
#!/bin/bash
CONFIG=/etc/raptor/cortex-suspend.conf
[ -f "$CONFIG" ] || exit 0
while IFS= read -r pattern; do
    [ -z "$pattern" ] && continue
    case "$pattern" in "#"*) continue ;; esac
    pkill -CONT -f "$pattern" 2>/dev/null || true
done < "$CONFIG"
sudo /usr/lib/raptor/cortex-helper restore-background 2>/dev/null || true
EOF
chmod +x /usr/lib/raptor/gamemode-end

# ── Gamemode config ───────────────────────────────────────────────────────────
mkdir -p /etc/gamemode.d
cat << 'EOF' > /etc/gamemode.d/raptor-cortex.ini
[general]
renice=10
inhibit_screensaver=1
softrealtime=auto
reaper_freq=5

[gpu]
apply_gpu_optimisations=accept-responsibility
gpu_device=0
amd_performance_level=high

[custom]
start=/usr/lib/raptor/gamemode-start
end=/usr/lib/raptor/gamemode-end
EOF

# ── Python GUI ────────────────────────────────────────────────────────────────
cat << 'PYEOF' > /usr/bin/raptor-cortex
#!/usr/bin/env python3
"""Raptor Cortex v4.2 — Unified memory & performance management for Raptor OS"""

import gi
gi.require_version("Gtk", "4.0")
gi.require_version("Adw", "1")
from gi.repository import Gtk, Adw, GLib

import subprocess
import threading
import os
import sys

CORTEX_CONFIG  = "/etc/raptor/cortex-suspend.conf"
HELPER         = "/usr/lib/raptor/cortex-helper"
MODE_STATE_FILE = os.path.expanduser("~/.config/raptor-cortex-mode")

ALL_SERVICES = [
    # ── KDE / indexing ────────────────────────────────────────────────────────
    ("Baloo file indexer",      "baloo_file"),
    ("Akonadi server",          "akonadiserver"),
    ("KDE Connect daemon",      "kdeconnectd"),
    ("Thumbnail generator",     "kio_thumbnail"),
    ("Activity manager",        "kactivitymanagerd"),
    ("KDE wallet daemon",       "kwalletd"),
    ("Plasma geolocation",      "plasma-geolocation"),
    ("KDE sycoca builder",      "kbuildsycoca"),
    # ── GNOME / cross-desktop ─────────────────────────────────────────────────
    ("Evolution data server",   "evolution-data"),
    ("Zeitgeist daemon",        "zeitgeist"),
    ("GVFS metadata",           "gvfsd-metadata"),
    ("Colour management",       "colord"),
    # ── System daemons safe to pause while gaming ─────────────────────────────
    ("Package manager daemon",  "packagekitd"),      # apt/dnf background checks
    ("KDE crash handler",       "drkonqi"),           # crash reporter, unneeded in-game
    ("Bluetooth OBEX",          "obexd"),             # BT file transfer daemon
    ("Smart card daemon",       "pcscd"),             # rarely used on gaming desktops
    ("Printer discovery",       "cups-browsed"),      # network printer scan
    # ── Audio session (suspend last — restoring audio can be slow) ────────────
    ("PipeWire media session",  "pipewire-media-session"),
]

PERFORMANCE_MODES = {
    "power_saving": (
        "Power Saving",
        "Reduces CPU governor, dirty writeback, PCIe ASPM on, NVMe min power. Battery slider works normally.",
        "battery-low-symbolic",
        "#f5c211",
    ),
    "balanced": (
        "Balanced",
        "Moderate tuning with schedutil governor, USB autosuspend, medium SATA power.",
        "media-playlist-shuffle-symbolic",
        "#3584e4",
    ),
    "performance": (
        "Performance",
        "CPU boost on, performance governor, PCIe/NVMe max performance, background trimmed.",
        "starred-symbolic",
        "#2ec27e",
    ),
}


def detect_system_mode() -> str:
    """Read the persisted Cortex mode from ~/.config/raptor-cortex-mode.
    Falls back to 'balanced' if not set."""
    try:
        with open(MODE_STATE_FILE) as f:
            mode = f.read().strip()
            if mode in PERFORMANCE_MODES:
                return mode
    except Exception:
        pass
    return "balanced"


def persist_mode(mode: str) -> None:
    """Write the current mode to ~/.config/raptor-cortex-mode."""
    try:
        os.makedirs(os.path.dirname(MODE_STATE_FILE), exist_ok=True)
        with open(MODE_STATE_FILE, "w") as f:
            f.write(mode + "\n")
    except Exception as e:
        print(f"[cortex] Could not persist mode: {e}", file=sys.stderr)


def read_meminfo():
    info = {}
    try:
        with open("/proc/meminfo") as f:
            for line in f:
                parts = line.split()
                if len(parts) >= 2:
                    key = parts[0].rstrip(":")
                    info[key] = int(parts[1]) // 1024
    except Exception:
        pass
    return info


def mem_used_mb():
    m = read_meminfo()
    total = m.get("MemTotal", 0)
    avail = m.get("MemAvailable", 0)
    return total - avail, total


def fmt_mb(mb):
    return f"{mb / 1024:.1f} GB" if mb >= 1024 else f"{mb} MB"


def get_zram_usage():
    try:
        if not os.path.exists("/sys/block/zram0"):
            return 0, 0, False
        with open("/sys/block/zram0/disksize") as f:
            total_mb = int(f.read().strip()) // (1024 * 1024)
        try:
            with open("/sys/block/zram0/mm_stat") as f:
                orig_mb = int(f.read().split()[0]) // (1024 * 1024)
        except Exception:
            orig_mb = 0
        return orig_mb, total_mb, total_mb > 0
    except Exception:
        return 0, 0, False


def get_swap_usage():
    m = read_meminfo()
    total = m.get("SwapTotal", 0)
    free  = m.get("SwapFree", 0)
    return total - free, total


def get_cpu_boost():
    try:
        with open("/sys/devices/system/cpu/cpufreq/boost") as f:
            return f.read().strip() == "1"
    except Exception:
        return None


def get_cpu_temp():
    """Return CPU temperature in °C, or None if unavailable."""
    # Try x86_pkg_temp first (most accurate on Intel/AMD)
    for zone in sorted(os.listdir("/sys/class/thermal")):
        path = f"/sys/class/thermal/{zone}"
        try:
            with open(f"{path}/type") as f:
                t = f.read().strip()
            if t in ("x86_pkg_temp", "k10temp", "acpitz", "cpu-thermal"):
                with open(f"{path}/temp") as f:
                    return int(f.read().strip()) // 1000
        except Exception:
            continue
    # Fall back: first thermal zone that looks sane
    try:
        with open("/sys/class/thermal/thermal_zone0/temp") as f:
            t = int(f.read().strip()) // 1000
            return t if 10 < t < 120 else None
    except Exception:
        return None


def get_gpu_temp():
    """Return GPU temperature in °C from hwmon or AMD sysfs."""
    # AMD: check hwmon for devices advertising 'amdgpu'
    try:
        for hwmon in sorted(os.listdir("/sys/class/hwmon")):
            name_path = f"/sys/class/hwmon/{hwmon}/name"
            with open(name_path) as f:
                name = f.read().strip()
            if name in ("amdgpu", "radeon"):
                for label_cand in ("temp1_input", "temp2_input"):
                    tp = f"/sys/class/hwmon/{hwmon}/{label_cand}"
                    if os.path.exists(tp):
                        with open(tp) as f:
                            return int(f.read().strip()) // 1000
    except Exception:
        pass
    # NVIDIA: try nvidia-smi
    try:
        r = subprocess.run(
            ["nvidia-smi", "--query-gpu=temperature.gpu", "--format=csv,noheader,nounits"],
            capture_output=True, text=True, timeout=2
        )
        if r.returncode == 0:
            return int(r.stdout.strip())
    except Exception:
        pass
    return None


def get_cpu_freq_mhz():
    """Return current CPU frequency in MHz (core 0), or None."""
    try:
        with open("/sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq") as f:
            return int(f.read().strip()) // 1000
    except Exception:
        return None


def load_persistent_settings():
    """Load persistent Cortex settings from ~/.config/raptor-cortex-settings.json."""
    defaults = {
        "auto_apply_mode_on_boot": True,
        "auto_performance_on_game": False,
        "auto_restore_after_game": False,
        "sched_cleanup_enabled": False,
        "sched_cleanup_interval_min": 30,
    }
    settings_file = os.path.expanduser("~/.config/raptor-cortex-settings.json")
    try:
        import json
        with open(settings_file) as f:
            loaded = json.load(f)
        defaults.update(loaded)
    except Exception:
        pass
    return defaults


def save_persistent_settings(settings: dict):
    """Save persistent Cortex settings."""
    import json
    settings_file = os.path.expanduser("~/.config/raptor-cortex-settings.json")
    try:
        os.makedirs(os.path.dirname(settings_file), exist_ok=True)
        with open(settings_file, "w") as f:
            json.dump(settings, f, indent=2)
    except Exception as e:
        print(f"[cortex] Could not save settings: {e}", file=sys.stderr)


def load_cortex_config():
    patterns = set()
    try:
        with open(CORTEX_CONFIG) as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith("#"):
                    patterns.add(line)
    except Exception:
        pass
    return patterns


def save_cortex_config(patterns):
    try:
        lines = [
            "# Raptor Cortex — services to suspend during gaming\n",
            "# This file is managed by the Raptor Cortex GUI.\n",
        ]
        for _, pattern in ALL_SERVICES:
            if pattern in patterns:
                lines.append(pattern + "\n")
        with open(CORTEX_CONFIG, "w") as f:
            f.writelines(lines)
    except Exception as e:
        print(f"[cortex] Could not save config: {e}", file=sys.stderr)


class RaptorCortexApp(Adw.Application):
    def __init__(self):
        super().__init__(application_id="io.github.cerberus9dev.RaptorCortex")
        self.connect("activate", self.on_activate)

    def on_activate(self, app):
        self.win = RaptorCortexWindow(application=app)
        self.win.present()


class RaptorCortexWindow(Adw.ApplicationWindow):
    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        self.set_title("Raptor Cortex")
        self.set_default_size(700, 940)
        self._running = False
        self._suspended_now = []
        self._cortex_patterns = load_cortex_config()
        # Read the persisted mode and persistent settings
        self._current_mode = detect_system_mode()
        self._settings = load_persistent_settings()
        self._sched_cleanup_id = None   # GLib timer handle
        self._mode_btns = {}
        self._toast_overlay = None
        self._build_ui()
        GLib.timeout_add_seconds(2, self._refresh_stats)
        self._refresh_stats()

    def _build_ui(self):
        root = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        self.set_content(root)
        root.append(Adw.HeaderBar())

        # Toast overlay wraps the scrollable content
        self._toast_overlay = Adw.ToastOverlay()
        self._toast_overlay.set_vexpand(True)
        root.append(self._toast_overlay)

        scroll = Gtk.ScrolledWindow()
        scroll.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
        scroll.set_vexpand(True)
        self._toast_overlay.set_child(scroll)

        content = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=16)
        content.set_margin_top(20)
        content.set_margin_bottom(20)
        content.set_margin_start(20)
        content.set_margin_end(20)
        scroll.set_child(content)

        self.mode_banner = Adw.Banner()
        self.mode_banner.set_revealed(True)
        self._update_mode_banner()
        content.append(self.mode_banner)

        stats_group = Adw.PreferencesGroup(title="System Memory")
        content.append(stats_group)

        ram_row = Adw.ActionRow(title="RAM Usage")
        self.ram_bar = Gtk.LevelBar()
        self.ram_bar.set_min_value(0)
        self.ram_bar.set_max_value(1)
        self.ram_bar.set_size_request(200, -1)
        self.ram_bar.set_valign(Gtk.Align.CENTER)
        self.ram_label = Gtk.Label(label="…")
        self.ram_label.add_css_class("dim-label")
        ram_row.add_suffix(self.ram_label)
        ram_row.add_suffix(self.ram_bar)
        stats_group.add(ram_row)

        self.swap_row = Adw.ActionRow(title="Swap / zram")
        self.swap_label = Gtk.Label(label="…")
        self.swap_label.add_css_class("dim-label")
        self.swap_row.add_suffix(self.swap_label)
        stats_group.add(self.swap_row)

        self.zram_row = Adw.ActionRow(title="zram compression")
        self.zram_label = Gtk.Label(label="…")
        self.zram_label.add_css_class("dim-label")
        self.zram_row.add_suffix(self.zram_label)
        stats_group.add(self.zram_row)

        self.boost_row = Adw.ActionRow(title="CPU Boost")
        self.boost_label = Gtk.Label(label="…")
        self.boost_label.add_css_class("dim-label")
        self.boost_row.add_suffix(self.boost_label)
        stats_group.add(self.boost_row)

        self.cpu_temp_row = Adw.ActionRow(title="CPU Temperature")
        self.cpu_temp_label = Gtk.Label(label="…")
        self.cpu_temp_label.add_css_class("dim-label")
        self.cpu_temp_row.add_suffix(self.cpu_temp_label)
        stats_group.add(self.cpu_temp_row)

        self.gpu_temp_row = Adw.ActionRow(title="GPU Temperature")
        self.gpu_temp_label = Gtk.Label(label="…")
        self.gpu_temp_label.add_css_class("dim-label")
        self.gpu_temp_row.add_suffix(self.gpu_temp_label)
        stats_group.add(self.gpu_temp_row)

        self.cpu_freq_row = Adw.ActionRow(title="CPU Frequency")
        self.cpu_freq_label = Gtk.Label(label="…")
        self.cpu_freq_label.add_css_class("dim-label")
        self.cpu_freq_row.add_suffix(self.cpu_freq_label)
        stats_group.add(self.cpu_freq_row)

        mode_group = Adw.PreferencesGroup(title="Performance Mode")
        mode_group.set_description(
            "Applies kernel tuning instantly — CPU, PCIe ASPM, NVMe, SATA, USB, audio power. "
            "Battery tray slider remains functional.")
        content.append(mode_group)

        ICON_FALLBACKS = {
            "power_saving": "battery-low-symbolic",
            "balanced":     "media-playlist-shuffle-symbolic",
            "performance":  "starred-symbolic",
        }

        for key, (label, desc, _, color) in PERFORMANCE_MODES.items():
            icon = Gtk.Image.new_from_icon_name(ICON_FALLBACKS[key])
            icon.set_pixel_size(20)
            icon.set_valign(Gtk.Align.CENTER)
            icon.set_margin_end(4)

            check = Gtk.Image.new_from_icon_name("object-select-symbolic")
            check.set_pixel_size(16)
            check.set_valign(Gtk.Align.CENTER)

            row = Adw.ActionRow(title=label)
            row.set_subtitle(desc)
            row.set_activatable(True)
            row.connect("activated", self._on_mode_switch, key)
            row.add_prefix(icon)
            row.add_suffix(check)
            mode_group.add(row)

            self._mode_btns[key] = (row, icon, check)

        self._refresh_mode_buttons()

        opts_group = Adw.PreferencesGroup(title="Manual Optimization Options")
        opts_group.set_description("Choose what to run when you click Optimize Memory Now.")
        content.append(opts_group)

        self.opt_caches  = self._switch_row("Drop caches + reclaim app memory",
                                             "Frees kernel caches AND asks running apps (Firefox, Vesktop, Steam) to release cold pages",
                                             True)
        opts_group.add(self.opt_caches)
        self.opt_compact = self._switch_row("Memory compaction",                 "Reduces fragmentation",                          True)
        opts_group.add(self.opt_compact)
        self.opt_zram    = self._switch_row("zram recompress",                   "Re-squeeze compressed swap pages",               True)
        opts_group.add(self.opt_zram)
        self.opt_swap    = self._switch_row("Swap pressure flush",               "Push cold pages to ZRAM swap (aggressive — use before gaming)",
                                             False)
        opts_group.add(self.opt_swap)
        self.opt_oom     = self._switch_row("Adjust OOM scores",                 "Protect KDE shell; make browsers killable",      True)
        opts_group.add(self.opt_oom)
        self.opt_deep    = self._switch_row("Deep Clean (slow)",                 "Flush hugepages + NUMA + slab caches + reclaim 3 GiB", False)
        opts_group.add(self.opt_deep)

        cortex_group = Adw.PreferencesGroup(title="Raptor Cortex — Game Mode")
        cortex_group.set_description(
            "Selected services are suspended when any game launches and resumed when it exits.")
        content.append(cortex_group)

        self._service_switches = {}
        for name, pattern in ALL_SERVICES:
            row = Adw.SwitchRow()
            row.set_title(name)
            row.set_subtitle(f"pgrep: {pattern}")
            row.set_active(pattern in self._cortex_patterns)
            row.connect("notify::active", self._on_cortex_toggle, pattern)
            cortex_group.add(row)
            self._service_switches[pattern] = row

        self.result_group = Adw.PreferencesGroup(title="Last Optimization")
        self.result_group.set_visible(False)
        content.append(self.result_group)

        self.result_row = Adw.ActionRow()
        self.result_row.set_title("Freed")
        self.result_icon = Gtk.Image.new_from_icon_name("emblem-ok-symbolic")
        self.result_icon.add_css_class("success")
        self.result_row.add_prefix(self.result_icon)
        self.result_group.add(self.result_row)

        self.sus_group = Adw.PreferencesGroup(title="Currently Suspended")
        self.sus_group.set_visible(False)
        content.append(self.sus_group)

        self.sus_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
        self.sus_group.add(self.sus_box)

        # ── Quick Actions ──────────────────────────────────────────────────────
        quick_group = Adw.PreferencesGroup(title="Quick Actions")
        quick_group.set_description(
            "One-click presets for common scenarios. Effects are immediate.")
        content.append(quick_group)

        boost_row = Adw.ActionRow(title="Pre-Game Boost")
        boost_row.set_subtitle(
            "Switch to Performance mode, drop caches, reclaim ~1.5 GB from browser/Discord")
        boost_row.set_activatable(True)
        boost_row.connect("activated", self._on_pregame_boost)
        boost_icon = Gtk.Image.new_from_icon_name("media-playback-start-symbolic")
        boost_icon.set_pixel_size(18)
        boost_row.add_prefix(boost_icon)
        quick_group.add(boost_row)

        restore_row = Adw.ActionRow(title="Restore Desktop")
        restore_row.set_subtitle(
            "Switch back to Balanced, resume all suspended services")
        restore_row.set_activatable(True)
        restore_row.connect("activated", self._on_restore_desktop)
        rest_icon = Gtk.Image.new_from_icon_name("go-home-symbolic")
        rest_icon.set_pixel_size(18)
        restore_row.add_prefix(rest_icon)
        quick_group.add(restore_row)

        shader_row = Adw.ActionRow(title="Clear Shader Cache")
        shader_row.set_subtitle(
            "Delete Mesa, DXVK, and Steam shader caches — fixes visual glitches, "
            "frees disk space (shaders rebuild on next game launch)")
        shader_row.set_activatable(True)
        shader_row.connect("activated", self._on_clear_shaders)
        shader_icon = Gtk.Image.new_from_icon_name("edit-clear-all-symbolic")
        shader_icon.set_pixel_size(18)
        shader_row.add_prefix(shader_icon)
        quick_group.add(shader_row)

        # ── Persistent Settings ────────────────────────────────────────────────
        persist_group = Adw.PreferencesGroup(title="Persistent Settings")
        persist_group.set_description(
            "These settings survive reboots and are applied automatically.")
        content.append(persist_group)

        self.boot_mode_row = Adw.SwitchRow()
        self.boot_mode_row.set_title("Apply selected mode on every boot")
        self.boot_mode_row.set_subtitle(
            "Restores the Performance/Balanced/Power Saving mode after each reboot")
        self.boot_mode_row.set_active(self._settings.get("auto_apply_mode_on_boot", True))
        self.boot_mode_row.connect("notify::active", self._on_setting_toggle, "auto_apply_mode_on_boot")
        persist_group.add(self.boot_mode_row)

        self.auto_perf_row = Adw.SwitchRow()
        self.auto_perf_row.set_title("Auto-switch to Performance when game starts")
        self.auto_perf_row.set_subtitle(
            "Watches gamemode — when a game launches Cortex switches to Performance automatically")
        self.auto_perf_row.set_active(self._settings.get("auto_performance_on_game", False))
        self.auto_perf_row.connect("notify::active", self._on_setting_toggle, "auto_performance_on_game")
        persist_group.add(self.auto_perf_row)

        self.auto_restore_row = Adw.SwitchRow()
        self.auto_restore_row.set_title("Restore Balanced mode after game exits")
        self.auto_restore_row.set_subtitle(
            "Automatically switches back to Balanced when the game process ends")
        self.auto_restore_row.set_active(self._settings.get("auto_restore_after_game", False))
        self.auto_restore_row.connect("notify::active", self._on_setting_toggle, "auto_restore_after_game")
        persist_group.add(self.auto_restore_row)

        # ── Scheduled Cleanup ─────────────────────────────────────────────────
        sched_group = Adw.PreferencesGroup(title="Scheduled Memory Cleanup")
        sched_group.set_description(
            "Automatically run memory optimization in the background on a timer. "
            "Useful for long gaming sessions where browser memory grows over time.")
        content.append(sched_group)

        self.sched_enable_row = Adw.SwitchRow()
        self.sched_enable_row.set_title("Enable scheduled cleanup")
        self.sched_enable_row.set_subtitle("Runs the enabled optimization options above on a timer")
        self.sched_enable_row.set_active(self._settings.get("sched_cleanup_enabled", False))
        self.sched_enable_row.connect("notify::active", self._on_sched_toggle)
        sched_group.add(self.sched_enable_row)

        self.sched_interval_row = Adw.SpinRow.new_with_range(5, 120, 5)
        self.sched_interval_row.set_title("Cleanup interval (minutes)")
        self.sched_interval_row.set_subtitle("How often to run the automatic cleanup")
        self.sched_interval_row.set_value(self._settings.get("sched_cleanup_interval_min", 30))
        self.sched_interval_row.set_sensitive(self._settings.get("sched_cleanup_enabled", False))
        self.sched_interval_row.connect("changed", self._on_sched_interval_changed)
        sched_group.add(self.sched_interval_row)

        self.sched_status_row = Adw.ActionRow(title="Next cleanup")
        self.sched_status_label = Gtk.Label(label="Disabled")
        self.sched_status_label.add_css_class("dim-label")
        self.sched_status_row.add_suffix(self.sched_status_label)
        sched_group.add(self.sched_status_row)

        # Start timer if it was enabled last session
        if self._settings.get("sched_cleanup_enabled", False):
            self._start_sched_cleanup()

        btn_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
        btn_box.set_halign(Gtk.Align.CENTER)
        content.append(btn_box)

        self.run_btn = Gtk.Button(label="Optimize Memory Now")
        self.run_btn.add_css_class("suggested-action")
        self.run_btn.add_css_class("pill")
        self.run_btn.connect("clicked", self.on_optimize)
        btn_box.append(self.run_btn)

        self.resume_btn = Gtk.Button(label="Resume All Services")
        self.resume_btn.add_css_class("pill")
        self.resume_btn.set_sensitive(False)
        self.resume_btn.connect("clicked", self.on_resume)
        btn_box.append(self.resume_btn)

        self.spinner = Gtk.Spinner()
        btn_box.append(self.spinner)

    # ── Quick Action handlers ──────────────────────────────────────────────────

    def _on_pregame_boost(self, row):
        """One click: Performance mode + cache drop + 1.5 GB cgroup reclaim."""
        self._on_mode_switch(None, "performance")
        opts = {"caches": True, "compact": False, "zram": False,
                "swap": False, "oom": True, "deep": False, "thp": False, "cpu": False}
        before, total = mem_used_mb()
        threading.Thread(
            target=self._do_optimize, args=(opts, before, total), daemon=True
        ).start()
        toast = Adw.Toast.new("Pre-Game Boost applied — Performance mode active")
        toast.set_timeout(3)
        self._toast_overlay.add_toast(toast)

    def _on_restore_desktop(self, row):
        """Switch to Balanced + resume all suspended services."""
        self._on_mode_switch(None, "balanced")
        threading.Thread(target=self._resume_services, daemon=True).start()
        toast = Adw.Toast.new("Desktop restored — Balanced mode, all services resumed")
        toast.set_timeout(3)
        self._toast_overlay.add_toast(toast)

    def _resume_services(self):
        subprocess.run(["sudo", HELPER, "resume-background"], capture_output=True)
        GLib.idle_add(self.resume_btn.set_sensitive, False)

    def _on_clear_shaders(self, row):
        """Clear Mesa, DXVK, and Steam shader caches."""
        import shutil, glob
        home = os.path.expanduser("~")
        targets = [
            f"{home}/.cache/mesa_shader_cache",
            f"{home}/.cache/mesa_shader_cache_db",
            f"{home}/.cache/radv_cache",
            f"{home}/.cache/amdvlk",
            f"{home}/.local/share/vulkan/implicit_layer.d",
        ]
        # DXVK state caches
        targets += glob.glob(f"{home}/.local/share/Steam/steamapps/shadercache/**/*",
                             recursive=True)
        freed_mb = 0
        removed = 0
        for t in targets:
            try:
                if os.path.isdir(t):
                    size = sum(
                        os.path.getsize(os.path.join(dp, f))
                        for dp, _, fns in os.walk(t) for f in fns
                    ) // (1024 * 1024)
                    shutil.rmtree(t, ignore_errors=True)
                    freed_mb += size
                    removed += 1
                elif os.path.isfile(t):
                    freed_mb += os.path.getsize(t) // (1024 * 1024)
                    os.remove(t)
                    removed += 1
            except Exception:
                pass
        msg = f"Shader cache cleared — {freed_mb} MB freed ({removed} directories removed)"
        GLib.idle_add(self._show_toast, msg)

    def _show_toast(self, msg):
        toast = Adw.Toast.new(msg)
        toast.set_timeout(4)
        self._toast_overlay.add_toast(toast)

    # ── Persistent Settings handlers ───────────────────────────────────────────

    def _on_setting_toggle(self, row, _param, key):
        self._settings[key] = row.get_active()
        threading.Thread(
            target=save_persistent_settings, args=(self._settings,), daemon=True
        ).start()

    # ── Scheduled Cleanup handlers ─────────────────────────────────────────────

    def _on_sched_toggle(self, row, _param):
        enabled = row.get_active()
        self._settings["sched_cleanup_enabled"] = enabled
        self.sched_interval_row.set_sensitive(enabled)
        threading.Thread(
            target=save_persistent_settings, args=(self._settings,), daemon=True
        ).start()
        if enabled:
            self._start_sched_cleanup()
        else:
            self._stop_sched_cleanup()
            GLib.idle_add(self.sched_status_label.set_text, "Disabled")

    def _on_sched_interval_changed(self, row):
        interval = int(row.get_value())
        self._settings["sched_cleanup_interval_min"] = interval
        threading.Thread(
            target=save_persistent_settings, args=(self._settings,), daemon=True
        ).start()
        if self._settings.get("sched_cleanup_enabled", False):
            self._stop_sched_cleanup()
            self._start_sched_cleanup()

    def _start_sched_cleanup(self):
        self._stop_sched_cleanup()
        interval_min = self._settings.get("sched_cleanup_interval_min", 30)
        interval_ms  = interval_min * 60 * 1000
        self._sched_cleanup_id = GLib.timeout_add(interval_ms, self._run_sched_cleanup)
        GLib.idle_add(
            self.sched_status_label.set_text,
            f"Every {interval_min} min — next in {interval_min} min"
        )

    def _stop_sched_cleanup(self):
        if self._sched_cleanup_id is not None:
            GLib.source_remove(self._sched_cleanup_id)
            self._sched_cleanup_id = None

    def _run_sched_cleanup(self):
        """Called by GLib timer — run the enabled optimize options silently."""
        opts = {
            "caches":  self.opt_caches.get_active(),
            "compact": self.opt_compact.get_active(),
            "zram":    self.opt_zram.get_active(),
            "swap":    False,   # never auto-swap-flush
            "oom":     self.opt_oom.get_active(),
            "deep":    False,   # never auto deep-clean
            "thp":     False,
            "cpu":     False,
        }
        before, total = mem_used_mb()
        threading.Thread(
            target=self._do_optimize, args=(opts, before, total), daemon=True
        ).start()
        interval_min = self._settings.get("sched_cleanup_interval_min", 30)
        GLib.idle_add(
            self.sched_status_label.set_text,
            f"Every {interval_min} min — running now…"
        )
        # Re-schedule (return True keeps the timer alive)
        return True

    def _update_mode_banner(self):
        label, desc, _, _ = PERFORMANCE_MODES[self._current_mode]
        self.mode_banner.set_title(f"Active mode: {label} — {desc}")

    def _refresh_mode_buttons(self):
        for key, (row, icon, check) in self._mode_btns.items():
            is_active = (key == self._current_mode)
            # Active row: show checkmark, full opacity, not clickable (already selected)
            check.set_visible(is_active)
            icon.set_opacity(1.0 if is_active else 0.4)
            icon.set_css_classes(["accent"] if is_active else [])
            row.set_opacity(1.0 if is_active else 0.65)
            # Sensitive=False on the active row prevents re-selecting same mode,
            # but ALL inactive rows remain fully clickable.
            row.set_sensitive(not is_active)

    def _switch_row(self, title, subtitle, default):
        row = Adw.SwitchRow()
        row.set_title(title)
        row.set_subtitle(subtitle)
        row.set_active(default)
        return row

    def _on_cortex_toggle(self, row, _param, pattern):
        if row.get_active():
            self._cortex_patterns.add(pattern)
        else:
            self._cortex_patterns.discard(pattern)
        threading.Thread(target=save_cortex_config, args=(self._cortex_patterns,), daemon=True).start()

    def _on_mode_switch(self, row, mode_key):
        # Update UI immediately so it feels responsive
        self._current_mode = mode_key
        self._refresh_mode_buttons()
        self._update_mode_banner()
        # Persist the selection so next app launch reads the right mode
        persist_mode(mode_key)
        # Apply the kernel tuning in a background thread
        threading.Thread(target=self._apply_mode, args=(mode_key,), daemon=True).start()

    def _apply_mode(self, mode_key):
        ok = True

        result = subprocess.run(["sudo", HELPER, "set-mode", mode_key],
                                capture_output=True, text=True)
        if result.returncode != 0:
            ok = False

        if mode_key == "performance":
            subprocess.run(["sudo", HELPER, "1", "1", "1", "1", "0", "0", "0", "1"],
                           capture_output=True)
            subprocess.run(["sudo", HELPER, "trim-background"],
                           capture_output=True)
        elif mode_key == "balanced":
            subprocess.run(["sudo", HELPER, "1", "1", "0", "1", "0", "0", "0", "0"],
                           capture_output=True)
        elif mode_key == "power_saving":
            subprocess.run(["sudo", HELPER, "1", "0", "0", "0", "0", "0", "0", "0"],
                           capture_output=True)

        label = PERFORMANCE_MODES[mode_key][0]
        if ok:
            msg = f"Mode set to {label}"
        else:
            msg = f"{label} applied (powerprofilesctl unavailable, kernel tuning still active)"

        GLib.idle_add(self._on_mode_applied, msg)

    def _on_mode_applied(self, message):
        toast = Adw.Toast.new(message)
        toast.set_timeout(3)
        self._toast_overlay.add_toast(toast)
        self._refresh_stats()
        return False

    def _refresh_stats(self):
        used, total = mem_used_mb()
        if total > 0:
            ratio = used / total
            self.ram_bar.set_value(ratio)
            self.ram_label.set_text(f"{fmt_mb(used)} / {fmt_mb(total)}")
            if ratio > 0.85:
                self.ram_bar.remove_css_class("success")
                self.ram_bar.add_css_class("error")
            elif ratio > 0.65:
                self.ram_bar.remove_css_class("error")
                self.ram_bar.add_css_class("warning")
            else:
                self.ram_bar.remove_css_class("error")
                self.ram_bar.remove_css_class("warning")

        swap_used, swap_total = get_swap_usage()
        self.swap_label.set_text(
            f"{fmt_mb(swap_used)} / {fmt_mb(swap_total)}" if swap_total > 0 else "No swap")

        zram_orig, zram_total, zram_active = get_zram_usage()
        if zram_active:
            if zram_orig > 0:
                ratio = zram_orig / max(zram_total, 1)
                self.zram_label.set_text(f"{fmt_mb(zram_orig)} → {fmt_mb(zram_total)} ({ratio:.1f}x)")
            else:
                self.zram_label.set_text(f"{fmt_mb(zram_total)} slot, idle")
        else:
            self.zram_label.set_text("Not active")

        boost = get_cpu_boost()
        self.boost_label.set_text("Enabled ✓" if boost else "Disabled" if boost is not None else "N/A")

        cpu_t = get_cpu_temp()
        self.cpu_temp_label.set_text(f"{cpu_t} °C" if cpu_t is not None else "N/A")
        self.cpu_temp_label.set_css_classes(
            ["error"] if cpu_t and cpu_t > 90
            else ["warning"] if cpu_t and cpu_t > 75
            else ["dim-label"])

        gpu_t = get_gpu_temp()
        self.gpu_temp_label.set_text(f"{gpu_t} °C" if gpu_t is not None else "N/A")
        self.gpu_temp_label.set_css_classes(
            ["error"] if gpu_t and gpu_t > 95
            else ["warning"] if gpu_t and gpu_t > 80
            else ["dim-label"])

        freq = get_cpu_freq_mhz()
        self.cpu_freq_label.set_text(
            f"{freq} MHz ({freq/1000:.2f} GHz)" if freq else "N/A")
        return True

    def on_optimize(self, btn):
        if self._running:
            return
        self._running = True
        self.run_btn.set_sensitive(False)
        self.spinner.start()
        opts = {
            "caches":  self.opt_caches.get_active(),
            "compact": self.opt_compact.get_active(),
            "zram":    self.opt_zram.get_active(),
            "oom":     self.opt_oom.get_active(),
            "deep":    self.opt_deep.get_active(),
            "swap":    self.opt_swap.get_active(),
        }
        before_used, before_total = mem_used_mb()
        threading.Thread(target=self._do_optimize, args=(opts, before_used, before_total), daemon=True).start()

    def _do_optimize(self, opts, before_used, before_total):
        subprocess.run([
            "sudo", HELPER,
            "1" if opts["caches"]  else "0",
            "1" if opts["compact"] else "0",
            "1" if opts["zram"]    else "0",
            "1" if opts["oom"]     else "0",
            "1" if opts["deep"]    else "0",
            "1" if opts["swap"]    else "0",
            "0", "0"
        ], capture_output=True)

        suspended = []
        for name, pattern in ALL_SERVICES:
            if pattern not in self._cortex_patterns:
                continue
            result = subprocess.run(["pgrep", "-f", pattern], capture_output=True, text=True)
            if result.returncode == 0:
                subprocess.run(["pkill", "-STOP", "-f", pattern], capture_output=True)
                suspended.append(name)

        self._suspended_now = suspended
        after_used, _ = mem_used_mb()
        freed = max(0, before_used - after_used)
        GLib.idle_add(self._show_result, before_used, before_total, after_used, freed, suspended)

    def _show_result(self, before, total, after, freed, suspended):
        self._running = False
        self.run_btn.set_sensitive(True)
        self.spinner.stop()
        self._refresh_stats()

        self.result_group.set_visible(True)
        self.result_row.set_title(f"Freed {fmt_mb(freed)}")
        self.result_row.set_subtitle(
            f"Before: {fmt_mb(before)} / {fmt_mb(total)}   After: {fmt_mb(after)} / {fmt_mb(total)}")

        if suspended:
            self.resume_btn.set_sensitive(True)
            self.sus_group.set_visible(True)
            child = self.sus_box.get_first_child()
            while child:
                nxt = child.get_next_sibling()
                self.sus_box.remove(child)
                child = nxt
            for name in suspended:
                lbl = Gtk.Label(label=f"  • {name}", xalign=0)
                lbl.add_css_class("dim-label")
                self.sus_box.append(lbl)
        else:
            self.sus_group.set_visible(False)

    def on_resume(self, btn):
        for _, pattern in ALL_SERVICES:
            if pattern in self._cortex_patterns:
                subprocess.run(["pkill", "-CONT", "-f", pattern], capture_output=True)
        self._suspended_now.clear()
        self.resume_btn.set_sensitive(False)
        self.sus_group.set_visible(False)
        threading.Thread(
            target=lambda: subprocess.run(["sudo", HELPER, "restore-background"], capture_output=True),
            daemon=True,
        ).start()


if __name__ == "__main__":
    app = RaptorCortexApp()
    sys.exit(app.run(sys.argv))
PYEOF
chmod +x /usr/bin/raptor-cortex

# ── Launcher wrapper ──────────────────────────────────────────────────────────
cat << 'EOF' > /usr/bin/raptor-cortex-launcher
#!/bin/bash
export ADW_DISABLE_PORTAL=1
exec /usr/bin/raptor-cortex "$@"
EOF
chmod +x /usr/bin/raptor-cortex-launcher

# ── .desktop entry ────────────────────────────────────────────────────────────
mkdir -p /usr/share/applications
cat << 'EOF' > /usr/share/applications/raptor-cortex.desktop
[Desktop Entry]
Version=1.1
Type=Application
Name=Raptor Cortex
GenericName=Memory & Performance Manager
Comment=Unified RAM optimization, performance mode switching, and game mode — no password required
Exec=/usr/bin/raptor-cortex-launcher
Icon=raptor-cortex
Terminal=false
Categories=X-RaptorOS;System;Settings;
Keywords=cortex;memory;ram;optimize;performance;gaming;
StartupNotify=true
X-KDE-SubstituteUID=false
EOF

echo "CORTEX_READY"
