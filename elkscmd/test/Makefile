BASEDIR=..

include $(BASEDIR)/Makefile-rules

SUBDIRS =  \
	libc   \
	other  \
	echo   \
	# EOL

.PHONY: $(SUBDIRS)

all: $(SUBDIRS:%=%/all)

install: $(SUBDIRS:%=%/install)

clean: $(SUBDIRS:%=%/clean)

%/all:
	$(MAKE) -C $* all

%/install:
	$(MAKE) -C $* install

%/clean:
	$(MAKE) -C $* clean
