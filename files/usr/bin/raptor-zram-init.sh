#!/bin/bash
set -euo pipefail

TOTAL_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
TOTAL_GB=$(( TOTAL_KB / 1024 / 1024 ))

# Set zram to half of total RAM, capped at 16 GB
ZRAM_GB=$(( TOTAL_GB / 2 ))
(( ZRAM_GB > 16 )) && ZRAM_GB=16
(( ZRAM_GB < 1 )) && ZRAM_GB=1

logger -t raptor-zram "Setting zram size to ${ZRAM_GB}G (detected ${TOTAL_GB}G RAM)"
echo "${ZRAM_GB}G" > /sys/block/zram0/disksize
