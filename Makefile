# Makefile for devicekit-ios Xcode project

# Project configuration
PROJECT = devicekit-ios.xcodeproj
SCHEME = devicekit-ios
BUILD_DIR = build
ARCHIVE_PATH = $(BUILD_DIR)/$(SCHEME).xcarchive
EXPORT_PATH = $(BUILD_DIR)/export

# Build configuration (Debug or Release)
CONFIGURATION ?= Release

# Code signing
DEVELOPMENT_TEAM ?=
CODE_SIGN_IDENTITY ?= Apple Development

# Export method for IPA (development, ad-hoc, app-store, enterprise)
EXPORT_METHOD ?= development

.PHONY: clean build archive install install-sim list-devices ipa ipa-unsigned sim-zip-arm64 sim-zip-x86_64 sim-zip test-ipa lint

clean:
	@echo "Cleaning build artifacts..."
	rm -rf $(BUILD_DIR)
	xcodebuild clean -project $(PROJECT) -scheme $(SCHEME) -configuration $(CONFIGURATION)

build:
	@echo "Building $(SCHEME) for iOS device ($(CONFIGURATION))..."
	xcodebuild build \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-configuration $(CONFIGURATION) \
		-destination 'generic/platform=iOS' \
		-derivedDataPath $(BUILD_DIR) \
		-allowProvisioningUpdates \
		CODE_SIGN_IDENTITY="$(CODE_SIGN_IDENTITY)" \
		$(if $(DEVELOPMENT_TEAM),DEVELOPMENT_TEAM=$(DEVELOPMENT_TEAM),)

archive:
	@echo "Creating archive for $(SCHEME)..."
	xcodebuild archive \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-configuration $(CONFIGURATION) \
		-destination 'generic/platform=iOS' \
		-archivePath $(ARCHIVE_PATH) \
		-allowProvisioningUpdates \
		CODE_SIGN_IDENTITY="$(CODE_SIGN_IDENTITY)" \
		$(if $(DEVELOPMENT_TEAM),DEVELOPMENT_TEAM=$(DEVELOPMENT_TEAM),)
	@echo "Archive created at: $(ARCHIVE_PATH)"

install: build
	@echo "Installing $(SCHEME) on connected device..."
	@DEVICE_ID=$$(xcrun xctrace list devices 2>&1 | grep -E "iPhone|iPad" | grep -v "Simulator" | head -n1 | sed -E 's/.*\(([A-F0-9-]+)\).*/\1/'); \
	if [ -z "$$DEVICE_ID" ]; then \
		echo "Error: No iOS device connected"; \
		exit 1; \
	fi; \
	echo "Installing on device: $$DEVICE_ID"; \
	xcrun devicectl device install app \
		--device $$DEVICE_ID \
		$(BUILD_DIR)/Build/Products/$(CONFIGURATION)-iphoneos/$(SCHEME).app

# Install DeviceKit main app and XCUITest runner on a booted iOS Simulator.
# Usage:
#   make install-sim                            — auto-detects the first booted simulator
#   make install-sim SIMULATOR_UDID=<udid>      — targets a specific simulator
SIMULATOR_UDID ?=
install-sim:
	@echo "Building $(SCHEME) for iOS Simulator (build-for-testing)..."
	@xcodebuild build-for-testing \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-configuration $(CONFIGURATION) \
		-destination 'generic/platform=iOS Simulator' \
		-derivedDataPath $(BUILD_DIR) \
		CODE_SIGN_IDENTITY="" \
		CODE_SIGNING_REQUIRED=NO \
		CODE_SIGNING_ALLOWED=NO | xcbeautify
	@SIM_UDID="$(SIMULATOR_UDID)"; \
	if [ -z "$$SIM_UDID" ]; then \
		echo "Auto-detecting booted simulator..."; \
		SIM_UDID=$$(xcrun simctl list devices booted | grep -E "\(([A-F0-9-]+)\)" | head -1 | sed -E 's/.*\(([A-F0-9-]+)\).*/\1/'); \
		if [ -z "$$SIM_UDID" ]; then \
			echo "Error: No booted simulator found. Start one first:"; \
			echo "  xcrun simctl list devices available"; \
			echo "  xcrun simctl boot <udid>"; \
			exit 1; \
		fi; \
		echo "Found booted simulator: $$SIM_UDID"; \
	fi; \
	echo "Installing $(SCHEME).app on simulator $$SIM_UDID..."; \
	xcrun simctl install $$SIM_UDID "$(BUILD_DIR)/Build/Products/$(CONFIGURATION)-iphonesimulator/$(SCHEME).app"; \
	echo "Installing $(SCHEME)UITests-Runner.app on simulator $$SIM_UDID..."; \
	xcrun simctl install $$SIM_UDID "$(BUILD_DIR)/Build/Products/$(CONFIGURATION)-iphonesimulator/$(SCHEME)UITests-Runner.app"; \
	echo ""; \
	echo "Done. DeviceKit installed on simulator $$SIM_UDID"

list-devices:
	@echo "Connected iOS devices:"
	@xcrun xctrace list devices 2>&1 | grep -E "iPhone|iPad" | grep -v "Simulator" || echo "No devices connected"

# Debug build shortcut
debug:
	@$(MAKE) build CONFIGURATION=Debug

# Release build shortcut
release:
	@$(MAKE) build CONFIGURATION=Release

# Create IPA from archive
ipa: archive
	@echo "Creating export options from template..."
	@mkdir -p $(EXPORT_PATH)
	@if [ -z "$(DEVELOPMENT_TEAM)" ]; then \
		echo "Auto-detecting team ID from archive..."; \
		TEAM_ID=$$(xcodebuild -showBuildSettings -project $(PROJECT) -scheme $(SCHEME) -configuration $(CONFIGURATION) | grep "DEVELOPMENT_TEAM" | sed 's/.*= //'); \
		echo "Detected team ID: $$TEAM_ID"; \
		sed -e 's/{{EXPORT_METHOD}}/$(EXPORT_METHOD)/g' \
		    -e "s/{{DEVELOPMENT_TEAM}}/$$TEAM_ID/g" \
		    ExportOptions.plist.template > $(BUILD_DIR)/ExportOptions.plist; \
	else \
		sed -e 's/{{EXPORT_METHOD}}/$(EXPORT_METHOD)/g' \
		    -e 's/{{DEVELOPMENT_TEAM}}/$(DEVELOPMENT_TEAM)/g' \
		    ExportOptions.plist.template > $(BUILD_DIR)/ExportOptions.plist; \
	fi
	@echo "Exporting IPA (method: $(EXPORT_METHOD))..."
	xcodebuild -exportArchive \
		-archivePath $(ARCHIVE_PATH) \
		-exportPath $(EXPORT_PATH) \
		-exportOptionsPlist $(BUILD_DIR)/ExportOptions.plist \
		-allowProvisioningUpdates
	@echo ""
	@echo "IPA created successfully at: $(EXPORT_PATH)/$(SCHEME).ipa"

# Create unsigned IPA (for later resigning with adhoc cert)
ipa-unsigned:
	@echo "Building unsigned app for arm64 iOS devices..."
	xcodebuild build \
		-project devicekit-ios.xcodeproj \
		-scheme $(SCHEME) \
		-configuration $(CONFIGURATION) \
		-destination 'generic/platform=iOS' \
		-derivedDataPath $(BUILD_DIR) \
		CODE_SIGN_IDENTITY="" \
		CODE_SIGNING_REQUIRED=NO \
		CODE_SIGNING_ALLOWED=NO | xcbeautify
	@echo "Packaging unsigned app into IPA..."
	@mkdir -p $(EXPORT_PATH)/Payload
	@cp -r $(BUILD_DIR)/Build/Products/$(CONFIGURATION)-iphoneos/$(SCHEME).app $(EXPORT_PATH)/Payload/
	@cd $(EXPORT_PATH) && zip -r $(SCHEME)-unsigned.ipa Payload
	@rm -rf $(EXPORT_PATH)/Payload
	@echo ""
	@echo "Unsigned IPA created at: $(EXPORT_PATH)/$(SCHEME)-unsigned.ipa"
	@echo "You can now resign this with your adhoc certificate using:"
	@echo "  codesign -f -s 'Your Identity' $(EXPORT_PATH)/$(SCHEME)-unsigned.ipa"

# Build XCUITest runner for iOS Simulator (arm64 — Apple Silicon)
sim-zip-arm64:
	@echo "Building $(SCHEME) XCUITest runner for iOS Simulator (arm64)..."
	xcodebuild build-for-testing \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-configuration $(CONFIGURATION) \
		-destination 'generic/platform=iOS Simulator' \
		-derivedDataPath $(BUILD_DIR) \
		CODE_SIGN_IDENTITY="" \
		CODE_SIGNING_REQUIRED=NO \
		CODE_SIGNING_ALLOWED=NO \
		ARCHS=arm64 | xcbeautify
	@mkdir -p $(EXPORT_PATH)
	@cp -r "$(BUILD_DIR)/Build/Products/$(CONFIGURATION)-iphonesimulator/$(SCHEME)UITests-Runner.app" $(EXPORT_PATH)/
	@cd $(EXPORT_PATH) && zip -r $(SCHEME)-Sim-arm64.zip $(SCHEME)UITests-Runner.app
	@rm -rf "$(EXPORT_PATH)/$(SCHEME)UITests-Runner.app"
	@echo "Simulator zip created at: $(EXPORT_PATH)/$(SCHEME)-Sim-arm64.zip"

# Build XCUITest runner for iOS Simulator (x86_64 — Intel)
sim-zip-x86_64:
	@echo "Building $(SCHEME) XCUITest runner for iOS Simulator (x86_64)..."
	xcodebuild build-for-testing \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-configuration $(CONFIGURATION) \
		-destination 'generic/platform=iOS Simulator' \
		-derivedDataPath $(BUILD_DIR) \
		CODE_SIGN_IDENTITY="" \
		CODE_SIGNING_REQUIRED=NO \
		CODE_SIGNING_ALLOWED=NO \
		ARCHS=x86_64 | xcbeautify
	@mkdir -p $(EXPORT_PATH)
	@cp -r "$(BUILD_DIR)/Build/Products/$(CONFIGURATION)-iphonesimulator/$(SCHEME)UITests-Runner.app" $(EXPORT_PATH)/
	@cd $(EXPORT_PATH) && zip -r $(SCHEME)-Sim-x86_64.zip $(SCHEME)UITests-Runner.app
	@rm -rf "$(EXPORT_PATH)/$(SCHEME)UITests-Runner.app"
	@echo "Simulator zip created at: $(EXPORT_PATH)/$(SCHEME)-Sim-x86_64.zip"

# Build both simulator zips
sim-zip: sim-zip-arm64 sim-zip-x86_64

# Build for testing with XCUITest files
test-ipa:
	@echo "Checking for connected device..."
	@DEVICE_ID=$$(xcrun xctrace list devices 2>&1 | grep -E "iPhone|iPad" | grep -v "Simulator" | head -n1 | sed -E 's/.*\(([A-F0-9-]+)\).*/\1/'); \
	if [ -z "$$DEVICE_ID" ]; then \
		echo "Warning: No device connected. Building for generic device may fail for UITests."; \
		echo "Please connect a device and try again, or register a device in Apple Developer Portal."; \
		DESTINATION='generic/platform=iOS'; \
	else \
		echo "Using connected device: $$DEVICE_ID"; \
		DESTINATION="id=$$DEVICE_ID"; \
	fi; \
	echo "Building for testing with XCUITest files ($(CONFIGURATION))..."; \
	xcodebuild build-for-testing \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-configuration $(CONFIGURATION) \
		-destination "$$DESTINATION" \
		-derivedDataPath $(BUILD_DIR) \
		-allowProvisioningUpdates \
		CODE_SIGN_IDENTITY="$(CODE_SIGN_IDENTITY)" \
		$(if $(DEVELOPMENT_TEAM),DEVELOPMENT_TEAM=$(DEVELOPMENT_TEAM),)
	@echo ""
	@echo "Creating test package..."
	@cd $(BUILD_DIR)/Build/Products && \
		zip -r $(CURDIR)/$(BUILD_DIR)/$(SCHEME)-UITests.zip \
		$(CONFIGURATION)-iphoneos/*.app \
		$(CONFIGURATION)-iphoneos/*.xctest \
		*.xctestrun
	@echo ""
	@echo "Test package created at: $(BUILD_DIR)/$(SCHEME)-UITests.zip"
	@echo "Contents:"
	@echo "  - $(SCHEME).app (main app)"
	@echo "  - XCUITest bundles and runner"
	@echo "  - .xctestrun file for test execution"

# Run SwiftLint
lint:
	@echo "Running SwiftLint..."
	swiftlint lint --strict
