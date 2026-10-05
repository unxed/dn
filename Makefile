# Laconic front-end for the native DN build (issue #3).
#   make              -> tools/build.sh linux64
#   make install      -> $(PREFIX)/lib/dn/ + wrapper in $(PREFIX)/bin/dn
# Overrides: PREFIX=/usr/local  DESTDIR=  TARGET=linux64  OUT=out/linux64

PREFIX  ?= /usr/local
DESTDIR ?=
TARGET  ?= linux64
OUT     ?= out/$(TARGET)
LIBDIR  := $(DESTDIR)$(PREFIX)/lib/dn
BINDIR  := $(DESTDIR)$(PREFIX)/bin

.PHONY: all install uninstall clean

all:
	tools/build.sh $(TARGET) $(OUT)

install: all
	install -d $(LIBDIR) $(BINDIR)
	install -m 755 $(OUT)/dn $(LIBDIR)/dn
	# Resources must sit next to the binary (or behind DNDLG); see mainapp.pas OpenResourceStream.
	-cp -a $(OUT)/*.dlg $(OUT)/*.lng $(OUT)/*.hlp $(LIBDIR)/
	if [ -d $(OUT)/xlt ]; then cp -a $(OUT)/xlt $(LIBDIR)/; fi
	printf '%s\n' \
	  '#!/bin/sh' \
	  'LIB=$(PREFIX)/lib/dn' \
	  'export DNDLG=$$LIB' \
	  'exec "$$LIB/dn" "$$@"' > $(BINDIR)/dn
	chmod 755 $(BINDIR)/dn

uninstall:
	rm -f $(BINDIR)/dn
	rm -rf $(LIBDIR)

clean:
	rm -rf $(OUT)
