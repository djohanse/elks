#!/usr/bin/env bash
#
# Multi-hop traceroute test using Alpine Linux kernel + custom initramfs router
# Downloads Alpine's vmlinuz-lts and initramfs-lts, injects a router init,
# and runs srcbox (ELKS) ↔ router (Alpine) ↔ dstbox (ELKS) via QEMU sockets.
#
set -e
SCRIPTDIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPTDIR"

P12="${P12:-20001}"
P32="${P32:-20002}"
DLDIR="/tmp/traceroute-test"
mkdir -p "$DLDIR"

find_qemu() {
    for q in qemu-system-x86_64 qemu-system-i386; do
        type -p "$q" >/dev/null 2>&1 && echo "$q" && return
    done
    echo "QEMU not found!" >&2; exit 1
}
QEMU="$(find_qemu)"

# ---------- Alpine kernel ----------
echo "Downloading Alpine kernel + initramfs..."
ALPINE_BASE="https://dl-cdn.alpinelinux.org/alpine/v3.20/releases/x86_64/netboot"

[ -f "$DLDIR/vmlinuz-lts" ] || curl -fSL -o "$DLDIR/vmlinuz-lts" "$ALPINE_BASE/vmlinuz-lts"
[ -f "$DLDIR/initramfs-lts" ] || curl -fSL -o "$DLDIR/initramfs-lts" "$ALPINE_BASE/initramfs-lts"

echo "Building router initramfs..."

# Extract Alpine's initramfs
rm -rf "$DLDIR/rootfs"
mkdir -p "$DLDIR/rootfs"
cd "$DLDIR/rootfs"
# Alpine's initramfs might be compressed cpio or plain cpio
if file "$DLDIR/initramfs-lts" | grep -q gzip; then
    gunzip -c "$DLDIR/initramfs-lts" | cpio -idm 2>/dev/null
else
    cat "$DLDIR/initramfs-lts" | cpio -idm 2>/dev/null
fi

# Check if e1000 module exists
echo "=== Checking for e1000 module ==="
find lib/modules -name "e1000*" -type f 2>/dev/null | head -5 || echo "No e1000 module found!"

# Replace /init with our router init
cat > init << 'INITEOF'
#!/bin/sh
export PATH=/bin:/sbin:/usr/bin:/usr/sbin

echo "=========================================="
echo "  ROUTER INIT STARTING"
echo "=========================================="

# Mount essential filesystems
busybox mount -t proc none /proc
busybox mount -t sysfs none /sys
busybox mount -t devtmpfs none /dev

# Find kernel version
KVER=$(busybox ls /lib/modules/ 2>/dev/null | busybox head -1)
echo "Kernel modules: /lib/modules/$KVER"

# Load e1000 module
echo "Loading e1000 driver..."
modprobe e1000 2>/dev/null || busybox insmod /lib/modules/$KVER/kernel/drivers/net/ethernet/intel/e1000/e1000.ko 2>/dev/null

# Wait for interfaces
busybox sleep 2

echo "Network interfaces:"
busybox ip link show

# Configure networking
echo "Configuring eth0 (10.0.1.1)..."
busybox ip link set eth0 up 2>&1
busybox ip addr add 10.0.1.1/24 dev eth0 2>&1
echo "eth0 configured, checking..."
busybox ip addr show eth0 2>&1

echo "Configuring eth1 (10.0.2.1)..."
busybox ip link set eth1 up 2>&1
busybox ip addr add 10.0.2.1/24 dev eth1 2>&1
echo "eth1 configured, checking..."
busybox ip addr show eth1 2>&1

# Enable IP forwarding
echo "Enabling IP forwarding..."
echo 1 > /proc/sys/net/ipv4/ip_forward 2>&1
echo "ip_forward=$(cat /proc/sys/net/ipv4/ip_forward 2>/dev/null)"

echo "=========================================="
echo "  ROUTER READY"
echo "  eth0: 10.0.1.1 (srcbox side)"
echo "  eth1: 10.0.2.1 (dstbox side)"
echo "=========================================="

# Comprehensive diagnostics
echo ""
echo "=========================================="
echo "  ROUTER DIAGNOSTICS"
echo "=========================================="

echo "Interface status:"
busybox ip link show eth0 2>/dev/null
busybox ip link show eth1 2>/dev/null

echo ""
echo "IP addresses:"
busybox ip addr show eth0 2>/dev/null
busybox ip addr show eth1 2>/dev/null

echo ""
echo "Routing table:"
busybox ip route show 2>/dev/null

echo ""
echo "ARP table:"
busybox cat /proc/net/arp 2>/dev/null || echo "(empty)"

echo ""
echo "Network device statistics:"
busybox cat /proc/net/dev 2>/dev/null | busybox grep -E "eth|Inter|face"

echo ""
echo "IP forwarding:"
busybox cat /proc/sys/net/ipv4/ip_forward 2>/dev/null || echo "(not available)"

echo ""
echo "=========================================="
echo "  Router is ready. Waiting for packets..."
echo "  Check diagnostics every 10 seconds."
echo "=========================================="
echo ""

# Start web server for testing www browser
echo "Starting web server on port 80..."
echo "<html><body><h1>Hello from ELKS Router</h1><a href='/test'>Test link</a><p>This is a test page for the www browser.</p></body></html>" > /tmp/index.html
busybox httpd -p 80 -h /tmp &
echo "Web server started."

# Periodic diagnostics
while true; do
  busybox sleep 10
  echo "--- $(busybox date) ---"
  echo "ARP:"
  busybox cat /proc/net/arp 2>/dev/null || echo "(empty)"
  echo "eth0 RX/TX packets:"
  busybox cat /proc/net/dev 2>/dev/null | busybox grep eth0 || echo "(not found)"
done
INITEOF
chmod +x init

# Repack initramfs
find . | cpio -o -H newc 2>/dev/null | gzip > "$DLDIR/initramfs-router.cpio.gz"
cd "$SCRIPTDIR"
rm -rf "$DLDIR/rootfs"

echo "Router kernel: $DLDIR/vmlinuz-lts"
echo "Router initramfs: $DLDIR/initramfs-router.cpio.gz"

# ---------- ELKS image ----------
IMAGE="../../image/fd1440.img"
[ -f "$IMAGE" ] || IMAGE="../../image/fd2880.img"
[ -f "$IMAGE" ] || { echo "No ELKS image found!"; exit 1; }

# ---------- Cleanup ----------
cleanup() { kill $PID_ROUTER $PID_SRC $PID_DST 2>/dev/null; wait 2>/dev/null; }
trap cleanup EXIT INT TERM

echo ""
echo "================================================"
echo "  Multi-hop traceroute test"
echo "================================================"
echo ""
echo "  INSTRUCTIONS:"
echo ""
echo "  1. Run this script in Terminal 1 (router)"
echo "     You will see Alpine Linux boot messages"
echo "     Wait for 'ROUTER READY' message"
echo ""
echo "  2. Open Terminal 2 and run:"
echo "     cd $(pwd) && ./start_srcbox.sh"
echo "     Then: telnet localhost 4001"
echo "     Login as root, then run:"
echo "       ktcp 10.0.1.2 255.255.255.0 10.0.1.1 &"
echo "       traceroute 10.0.2.2"
echo ""
echo "  3. Open Terminal 3 and run:"
echo "     cd $(pwd) && ./start_dstbox.sh"
echo "     Then: telnet localhost 4002"
echo "     Login as root, then run:"
echo "       ktcp 10.0.2.2 255.255.255.0 10.0.2.1 &"
echo ""
echo "================================================"
echo ""

# Router — Alpine with two e1000 NICs (foreground, serial output to this terminal)
echo "[router] Starting Alpine router..."
exec $QEMU -accel tcg -nodefaults -machine pc -cpu qemu64 -m 256M \
    -kernel "$DLDIR/vmlinuz-lts" \
    -initrd "$DLDIR/initramfs-router.cpio.gz" \
    -append "console=ttyS0,115200 net.ifnames=0" \
    -serial stdio \
    -netdev socket,id=e0,listen=:$P12 -device e1000,netdev=e0,mac=52:54:00:12:34:01 \
    -netdev socket,id=e1,listen=:$P32 -device e1000,netdev=e1,mac=52:54:00:12:34:02 \
    -name router
