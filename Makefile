APP_NAME    = VoiceInput
BUNDLE_ID   = com.voiceinput.app
VERSION     = 1.0.0

# ── Paths ──────────────────────────────────────────────────────────────────────
RELEASE_DIR = release
APP_BUNDLE  = $(RELEASE_DIR)/$(APP_NAME).app
CONTENTS    = $(APP_BUNDLE)/Contents
MACOS_DIR   = $(CONTENTS)/MacOS
RESOURCES   = $(CONTENTS)/Resources
ICNS_FILE   = Assets/AppIcon.icns
DMG_FILE    = $(RELEASE_DIR)/$(APP_NAME).dmg

# Python 3 (used for icon generation). Override with: make icon PYTHON=/path/to/python3
PYTHON      ?= python3
LOCAL_CODESIGN_ID ?= VoiceInput Local Code Signing

# Stable certificate signing is required for TCC / Accessibility trust.
# You can override manually, e.g.:
#   make install CODESIGN_ID="Apple Development: Your Name (TEAMID)"
CODESIGN_ID ?= $(shell security find-identity -v -p codesigning 2>/dev/null | rg -F "\"$(LOCAL_CODESIGN_ID)\"" >/dev/null && printf '%s' "$(LOCAL_CODESIGN_ID)" || security find-identity -v -p codesigning 2>/dev/null | sed -n 's/.*"\(.*\)"/\1/p' | head -n 1)

.PHONY: all build icon run install dmg clean require-signing-identity signing-identities local-signing-cert

all: build

# ── Icon ───────────────────────────────────────────────────────────────────────
icon:
	@echo "▶ Generating app icon..."
	$(PYTHON) Scripts/make_icon.py

require-signing-identity:
	@if [ -z "$(strip $(CODESIGN_ID))" ]; then \
		echo "✗ No valid code signing identity found."; \
		echo "  VoiceInput now requires stable certificate signing for Accessibility trust."; \
		echo "  Install an Apple Development / Developer ID Application certificate,"; \
		echo "  or pass one explicitly:"; \
		echo "    make install CODESIGN_ID=\"Apple Development: Your Name (TEAMID)\""; \
		echo ""; \
		echo "  Available identities:"; \
		security find-identity -v -p codesigning || true; \
		exit 1; \
	fi
	@echo "▶ Using signing identity: $(CODESIGN_ID)"

signing-identities:
	@security find-identity -v -p codesigning

local-signing-cert:
	@bash Scripts/create_local_codesign_cert.sh

# ── Build .app bundle ──────────────────────────────────────────────────────────
build: icon require-signing-identity
	@echo "▶ Compiling (release)..."
	swift build -c release
	@echo "▶ Assembling $(APP_BUNDLE)..."
	mkdir -p $(MACOS_DIR) $(RESOURCES)
	cp .build/release/VoiceInputApp $(MACOS_DIR)/$(APP_NAME)
	cp Info.plist $(CONTENTS)/Info.plist
	@[ -f $(ICNS_FILE) ] && cp $(ICNS_FILE) $(RESOURCES)/AppIcon.icns \
		|| echo "  (no icon file, skipping)"
	@echo "▶ Signing..."
	codesign --force --sign "$(CODESIGN_ID)" \
		--entitlements Entitlements.plist \
		--identifier $(BUNDLE_ID) \
		$(APP_BUNDLE)
	@echo "✓ Built: $(APP_BUNDLE)"

# ── Run directly (without installing) ─────────────────────────────────────────
run: build
	open $(APP_BUNDLE)

# ── Install to /Applications (stable path = stable Accessibility trust) ────────
install: build
	rm -rf /Applications/$(APP_NAME).app
	cp -R $(APP_BUNDLE) /Applications/$(APP_NAME).app
	@echo "✓ Installed: /Applications/$(APP_NAME).app"
	@echo "  → If this is a first install, grant Accessibility in:"
	@echo "    System Settings › Privacy & Security › Accessibility"

# ── DMG installer (drag-to-Applications style) ─────────────────────────────────
dmg: build
	@which create-dmg > /dev/null 2>&1 \
		|| (echo "Installing create-dmg via Homebrew..." && brew install create-dmg)
	rm -f "$(DMG_FILE)"
	create-dmg \
		--volname "$(APP_NAME)" \
		--volicon "$(ICNS_FILE)" \
		--window-size 540 340 \
		--icon-size 128 \
		--icon "$(APP_NAME).app" 150 155 \
		--hide-extension "$(APP_NAME).app" \
		--app-drop-link 390 155 \
		--no-internet-enable \
		"$(DMG_FILE)" \
		"$(APP_BUNDLE)"
	@echo ""
	@echo "✓ DMG ready: $(DMG_FILE)"
	@ls -lh "$(DMG_FILE)"

# ── Clean ──────────────────────────────────────────────────────────────────────
clean:
	swift package clean
	rm -rf $(RELEASE_DIR) Assets/AppIcon.iconset Assets/AppIcon.icns
