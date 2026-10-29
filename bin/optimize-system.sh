#!/usr/bin/env bash
# Nothing OS Rice - Safe System & Battery Optimizer
# This script configures NVIDIA RTD3 dynamic power management (0W idle),
# disables unnecessary background daemons, and sets up high-speed zram
# compressed swap to prevent sluggishness on 8GB RAM.

set -euo pipefail

if [ "$EUID" -ne 0 ]; then
    echo -e "\033[1;31mError:\033[0m This script must be run with root privileges."
    echo "Usage: sudo $0"
    exit 1
fi

echo -e "\033[1;34m==>\033[0m Starting system optimizations..."

# -------------------------------------------------------------
# 1. NVIDIA RTD3 Dynamic Power Management (Saves ~10.7 Watts at idle)
# -------------------------------------------------------------
echo -e "\033[1;34m[1/4]\033[0m Configuring NVIDIA GPU Dynamic Power Management (RTD3)..."

cat << 'EOF' > /etc/modprobe.d/nvidia-power.conf
# Enable Runtime D3 (D3cold) power management for Ampere/Turing mobile dGPU
options nvidia "NVreg_DynamicPowerManagement=0x02"
EOF

# Disable and mask nvidia-persistenced so the driver can enter low power D3cold
systemctl stop nvidia-persistenced.service 2>/dev/null || true
systemctl disable nvidia-persistenced.service 2>/dev/null || true
systemctl mask nvidia-persistenced.service 2>/dev/null || true

# Set runtime PM control to auto for all NVIDIA PCI devices
for dev in /sys/bus/pci/devices/*; do
    if [ -f "$dev/vendor" ] && [ "$(cat "$dev/vendor")" = "0x10de" ]; then
        if [ -f "$dev/power/control" ]; then
            echo auto > "$dev/power/control" 2>/dev/null || true
        fi
    fi
done

# -------------------------------------------------------------
# 2. Disable unnecessary background daemons
# -------------------------------------------------------------
echo -e "\033[1;34m[2/4]\033[0m Disabling unwanted background daemons..."

# Local Deepseek LLM server (if user wants to start it manually, they can run modelctl)
echo "  -> Stopping and disabling snap.deepseek-r1.server-webui.service..."
systemctl stop snap.deepseek-r1.server-webui.service 2>/dev/null || true
systemctl disable snap.deepseek-r1.server-webui.service 2>/dev/null || true

# ModemManager (cellular broadband probe; not needed on laptops without cellular SIM cards)
echo "  -> Stopping and disabling ModemManager.service..."
systemctl stop ModemManager.service 2>/dev/null || true
systemctl disable ModemManager.service 2>/dev/null || true

# -------------------------------------------------------------
# 3. Fast ZRAM compressed memory swap (Eliminates disk swap latency)
# -------------------------------------------------------------
echo -e "\033[1;34m[3/4]\033[0m Setting up fast zram compressed in-memory swap..."

wait_for_apt_lock() {
    local waited=0
    while fuser /var/lib/dpkg/lock-frontend /var/lib/dpkg/lock /var/lib/apt/lists/lock >/dev/null 2>&1; do
        if [ "$waited" -eq 0 ]; then
            echo "  -> Waiting for background package manager lock to clear..."
        fi
        sleep 2
        waited=$((waited + 2))
        [ "$waited" -gt 60 ] && break
    done
}

if ! dpkg -s zram-tools >/dev/null 2>&1; then
    echo "  -> Installing zram-tools..."
    wait_for_apt_lock
    DEBIAN_FRONTEND=noninteractive apt-get update -qq
    wait_for_apt_lock
    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq zram-tools
fi

cat << 'EOF' > /etc/default/zramswap
# ZRAM configuration: compressed swap in RAM using zstd algorithm
ALGO=zstd
PERCENT=60
PRIORITY=100
EOF

systemctl restart zramswap.service 2>/dev/null || true
systemctl enable zramswap.service 2>/dev/null || true

# -------------------------------------------------------------
# 4. Kernel memory and responsiveness sysctl settings
# -------------------------------------------------------------
echo -e "\033[1;34m[4/5]\033[0m Applying memory responsiveness sysctl settings..."

cat << 'EOF' > /etc/sysctl.d/99-nothing-os-performance.conf
# Optimize paging priority for zram (compress anonymous memory before thrashing disk)
vm.swappiness = 100
# Keep directory and inode caches longer
vm.vfs_cache_pressure = 50
# Flush dirty cache in smaller chunks to avoid UI stutter during heavy I/O
vm.dirty_background_bytes = 67108864
vm.dirty_bytes = 268435456
EOF

sysctl -p /etc/sysctl.d/99-nothing-os-performance.conf >/dev/null 2>&1 || true

# -------------------------------------------------------------
# 5. Microsoft Edge RAM & Resource Optimization Policy
# -------------------------------------------------------------
echo -e "\033[1;34m[5/5]\033[0m Configuring Microsoft Edge Memory Saver & Sleeping Tabs policy..."

mkdir -p /etc/opt/edge/policies/managed
cat << 'EOF' > /etc/opt/edge/policies/managed/performance.json
{
  "SleepingTabsEnabled": true,
  "SleepingTabsTimeout": 300,
  "EfficiencyModeEnabled": true,
  "BackgroundModeEnabled": false,
  "StartupBoostEnabled": false
}
EOF
chmod 644 /etc/opt/edge/policies/managed/performance.json

echo ""
echo -e "\033[1;32m✓ Optimization complete!\033[0m"
echo "--------------------------------------------------------"
if command -v zramctl >/dev/null 2>&1; then
    echo "ZRAM Status:"
    zramctl || true
fi
echo "--------------------------------------------------------"
echo "NVIDIA Power Control Status:"
for dev in /sys/bus/pci/devices/*; do
    if [ -f "$dev/vendor" ] && [ "$(cat "$dev/vendor")" = "0x10de" ]; then
        echo "Device: $(basename "$dev") - power/control: $(cat "$dev/power/control" 2>/dev/null || echo 'N/A')"
    fi
done
echo "--------------------------------------------------------"
echo "Note: A system reboot is recommended to fully initialize NVIDIA D3cold RTD3."
