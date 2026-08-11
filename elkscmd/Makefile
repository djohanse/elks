# Makefile for the ELKS command set.
#
###############################################################################
#
# Include standard rules.

BASEDIR = .

include $(BASEDIR)/Makefile-rules

###############################################################################
#
# Subdirectories for clean / build / install

# All subdirectories to build & clean (elkscmd/lib handled specially)

IA16DIRS =       \
	advent      \
	ash         \
	audio       \
	basic       \
	bc          \
	busyelks    \
	debug       \
	disk_utils  \
	fsck_dos    \
	ekermit	    \
	elvis	    \
	file_utils  \
	gui         \
	inet        \
	ktcp        \
	minix1      \
	minix2      \
	minix3      \
	misc_utils  \
	romprg      \
	sash        \
	screen      \
	cron        \
	sh_utils    \
	sys_utils   \
	tui         \
	test        \
	# EOL

OWCDIRS =       \
    basic       \
    fsck_dos    \
    gui         \
    # EOL

C86DIRS =       \
    gui         \
    # EOL

###############################################################################
#
# Compile all IA16 apps

ALL = ia16

all: $(ALL)

lib:
	$(MAKE) -C lib all

ia16: $(IA16DIRS)

$(IA16DIRS): lib checkconfig
	$(MAKE) -C $@ all

checkconfig:
	@if [ ! -e $(TOPDIR)/include/autoconf.h ]; \
	then echo -e "\n*** ERROR: You must configure ELKS first ***\n" >&2; exit 1; fi

.PHONY: $(IA16DIRS) lib checkconfig ia16 owc c86 owclean c86clean

owc: $(OWCDIRS:%=owc-%)

owc-%: checkconfig
	$(MAKE) -C $* -f Makefile.owc all

c86: $(C86DIRS:%=c86-%)

c86-%: checkconfig
	$(MAKE) -C $* -f Makefile.c86 all

clean: owclean c86clean $(IA16DIRS:%=%/clean)
	$(MAKE) -C lib clean

%/clean:
	$(MAKE) -C $* clean

owclean: $(OWCDIRS:%=owclean-%)

owclean-%:
	$(MAKE) -C $* -f Makefile.owc clean

c86clean: $(C86DIRS:%=c86clean-%)

c86clean-%:
	$(MAKE) -C $* -f Makefile.c86 clean

install:
	$(MAKE) -f Make.install "CONFIG=$(TOPDIR)/.config"

###############################################################################
