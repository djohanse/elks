#!/usr/bin/env bash
# ELKS with macOS vmnet-shared networking (needs sudo)
# Provides full IP/ICMP support — traceroute shows real hops
set -e
cd "$(dirname "$0")"

IMAGE="../../image/fd1440.img"
[ -f "$IMAGE" ] || IMAGE="../../image/fd2880.img"
[ -f "$IMAGE" ] || { echo "No ELKS image found!"; exit 1; }

QEMU="${QEMU:-qemu-system-x86_64}"

echo "======================================================"
echo "  ELKS with macOS vmnet-shared networking"
echo ""
echo "  Provides full IP forwarding (ICMP, TCP, UDP)"
echo "  Traceroute shows real internet hops"
echo ""
echo "  NOTE: needs sudo for macOS vmnet framework"
echo "======================================================"
echo ""
echo "  Inside ELKS, configure networking:"
echo "    1. Check vmnet gateway IP (run in another terminal):"
echo "       ifconfig vmenet0"
echo ""
echo "    2. Configure ELKS (gateway should be 192.168.2.1):"
echo "       ifconfig 192.168.2.100 netmask 255.255.255.0 gateway 192.168.2.1"
echo "       ktcp &"
echo ""
echo "    3. Test:"
echo "       ping -c 3 8.8.8.8"
echo "       traceroute 8.8.8.8"
echo ""
echo "======================================================"
echo ""

exec sudo "$QEMU" -nodefaults -machine pc -cpu 486,tsc -m 8M \
    -serial stdio \
    -netdev vmnet-shared,id=net0 \
    -device ne2k_isa,irq=12,netdev=net0 \
    -snapshot \
    -fda "$IMAGE"
