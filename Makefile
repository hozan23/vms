VMS_CMD = vms
VMS_CMD_PATH = $(DESTDIR)$(PREFIX)/bin/$(VMS_CMD)
VMS_BASH_FILE = $(VMS_CMD).sh

.PHONY: all install uninstall

all: install

install: $(VMS_BASH_FILE)
	mkdir -p $(DESTDIR)$(PREFIX)/bin
	cp $(VMS_BASH_FILE) $(VMS_CMD_PATH)
	chmod 755 $(VMS_CMD_PATH)
	
uninstall:
	rm -f $(VMS_CMD_PATH)


