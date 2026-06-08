#!/usr/bin/env bash
# Start dstbox ELKS instance
set -e
SCRIPTDIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPTDIR"

QEMU="${QEMU:-qemu-system-x86_64}"
IMAGE="../../image/fd1440.img"
[ -f "$IMAGE" ] || IMAGE="../../image/fd2880.img"

echo "[dstbox] Starting ELKS dstbox (serial stdio)..."
echo ""
exec $QEMU -nodefaults -machine pc -cpu 486,tsc -m 8M \
    -netdev socket,id=net0,connect=127.0.0.1:20002 \
    -device ne2k_isa,irq=12,netdev=net0 \
    -serial stdio \
    -snapshot \
    -fda "$IMAGE" -name dstbox
