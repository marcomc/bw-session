PREFIX ?= $(HOME)/.local
BINDIR ?= $(PREFIX)/bin
TARGET ?= bw-session
SRC ?= bw-session.sh

.PHONY: install uninstall

install:
	mkdir -p "$(BINDIR)"
	install -m 700 "$(SRC)" "$(BINDIR)/$(TARGET)"
	@echo "Installed $(TARGET) to $(BINDIR)/$(TARGET)"

uninstall:
	rm -f "$(BINDIR)/$(TARGET)"
	@echo "Removed $(BINDIR)/$(TARGET)"
