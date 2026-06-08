#!/usr/bin/env bash
# ELKS with QEMU user-mode networking (no sudo needed)
set -e
cd "$(dirname "$0")"

IMAGE="../../image/fd1440.img"
[ -f "$IMAGE" ] || IMAGE="../../image/fd2880.img"
[ -f "$IMAGE" ] || { echo "No ELKS image found!"; exit 1; }

QEMU="${QEMU:-qemu-system-x86_64}"

echo "======================================================"
echo "  ELKS with QEMU user-mode networking (no sudo)"
echo "======================================================"
echo ""
echo "  In the ELKS shell that opens:"
echo ""
echo "    1. Configure networking:"
echo "       ifconfig 10.0.2.15 netmask 255.255.255.0 gateway 10.0.2.2"
echo ""
echo "    2. Start ktcp:"
echo "       ktcp &"
echo ""
echo "    3. Test:"
echo "       ping -c 3 8.8.8.8"
echo "       ping -c 3 google.com"
echo "       traceroute 8.8.8.8"
echo ""
echo "  NOTE: traceroute via user-mode shows 1 hop only"
echo "  (QEMU slirp doesn't forward ICMP Time Exceeded)"
echo "======================================================"
echo ""

exec "$QEMU" -nodefaults -machine pc -cpu 486,tsc -m 8M \
    -serial stdio \
    -netdev user,id=net0,hostfwd=tcp::2323-10.0.2.15:23 \
    -device ne2k_isa,irq=12,netdev=net0 \
    -snapshot \
    -fda "$IMAGE"
