#!/usr/bin/env bash

# ELKS System Builder
# This build script is also called in main.yml for GitHub Continuous Integration
#
# Usage: ./build.sh [-q] [auto [[ext] [[[allimages]]]]]
#   -q          quiet: suppress build output, show rolling progress dots
#   <no args>:  user build: build cross-compiler, menuconfig kernel and standard apps
#   auto        github CI build:: just IBM PC, 8018X, NECV25 kernel and standard apps
#   ext         also build external apps (requires OpenWatcom C installed)
#   allimages   also build all floppy and HD disk images
#
# After building the system once, the following can be used to rebuild the system:
#   $ make clean
#   $ make
#   $ ./buildext.sh all     # optionally build specified external apps (OpenWatcom reqd)
#   $ ./qemu.sh
#
set -e

SCRIPTDIR="$(dirname "$0")"
LOGFILE="$SCRIPTDIR/build.log"

# Parse -q flag before positional args
QUIET=""
while getopts "q" opt; do
	case $opt in
		q) QUIET=1 ;;
	esac
done
shift $((OPTIND-1))

# auto mode (CI) overrides -q, always shows full output for debugging
if [ "$1" = "auto" ]; then
	QUIET=""
fi

# Save fd 3 for terminal, start fresh log
exec 3>&1
: > "$LOGFILE"

msg() {
	echo "$*" >&3
}

run() {
	local msgtxt="$1"
	shift
	if [ -n "$QUIET" ]; then
		echo -n "  $msgtxt" >&3
		"$@" >> "$LOGFILE" 2>&1 &
		local pid=$!
		while kill -0 $pid 2>/dev/null; do
			echo -n "." >&3
			sleep 3
		done
		wait $pid
		local rc=$?
		if [ $rc -eq 0 ]; then
			echo " done" >&3
		else
			echo " FAILED" >&3
			return $rc
		fi
	else
		msg "=== $msgtxt ==="
		"$@" 2>&3 | tee -a "$LOGFILE" >&3
		return "${PIPESTATUS[0]}"
	fi
}

clean_exit () {
	E="$1"
	test -z "$E" && E=0
	if [ $E -eq 0 ]; then
		msg "Build script has completed successfully."
	else
		msg "Build script has terminated with error $E"
	fi
	[ -n "$QUIET" ] && msg "Full log: $LOGFILE"
	exit $E
}

# Environment setup

. "$SCRIPTDIR/env.sh"
[ $? -ne 0 ] && clean_exit 1

# Build cross tools if not already

if [ "$1" != "auto" ]; then
	mkdir -p "$CROSSDIR"
	run "Building cross tools" tools/build.sh || clean_exit 1
fi

# Configure all

if [ "$1" = "auto" ]; then
	msg "Invoking 'make defconfig'..."
	make defconfig || clean_exit 2
	msg "Building IBM PC image..."
	cp ibmpc-1440-nc.config .config
else
	msg ""
	msg "Now invoking 'make menuconfig' for you to configure the system."
	msg "The defaults should be OK for many systems, but you may want to review them."
	echo -n "Press ENTER to continue..." >&3
	read
	make menuconfig || clean_exit 2
fi

test -e .config || clean_exit 3

# Clean kernel, user land and image

if [ "$1" != "auto" ]; then
	run "Cleaning all" make clean || clean_exit 4
fi

# Build default kernel, user land and image

run "Building all" make all || clean_exit 5

if [ "$2" = "ext" ]; then
	run "Building external applications" ./buildext.sh all || clean_exit 51
fi

# Possibly build all images

if [ "$3" = "allimages" ]; then
	run "Building FD images" sh -c "cd image && make images-minix images-fat" || clean_exit 6
	run "Building HD images" sh -c "cd image && make images-hd" || clean_exit 61
fi

# Build 8018X kernel and image
if [ "$1" = "auto" ]; then
	msg "Building 8018X image..."
	cp 8018x.config .config
	run "Cleaning kernel for 8018X" make kclean || clean_exit 7
	rm -f elkscmd/basic/*.o
	run "Building 8018X" make || clean_exit 8
fi

# Build NEC V25 kernel and image
if [ "$1" = "auto" ]; then
	msg "Building NECV 25 image..."
	cp necv25.config .config
	run "Cleaning kernel for NECV25" make kclean || clean_exit 7
	rm -f elkscmd/basic/*.o
	run "Building NECV25" make || clean_exit 8
fi

# Build PC-98 kernel, PC-98 Nano-X, some user land files and image
if [ "$1" = "auto" ]; then
	msg "Building PC-98 image..."
	cp pc98-1232.config .config
	./buildext.sh microwindows_pc98
	run "Cleaning kernel for PC-98" make kclean || clean_exit 9
	rm -f bootblocks/*.o
	rm -f elkscmd/sys_utils/clock.o
	rm -f elkscmd/sys_utils/ps.o
	rm -f elkscmd/sys_utils/meminfo.o
	rm -f elkscmd/sys_utils/beep.o
	rm -f elkscmd/basic/*.o
	run "Building PC-98" make || clean_exit 10
fi

# Success

msg "Target image is in 'image' folder."
clean_exit 0
