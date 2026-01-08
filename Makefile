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

.PHONY: clean build archive ipa-unsigned sim-zip-arm64 sim-zip-x86_64 sim-zip lint

clean:
	@echo "Cleaning build artifacts..."
	rm -rf $(BUILD_DIR)
	xcodebuild clean -project $(PROJECT) -scheme $(SCHEME) -configuration $(CONFIGURATION)

debug:
	@$(MAKE) build CONFIGURATION=Debug

release:
	@$(MAKE) build CONFIGURATION=Release

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
	@echo "Unsigned IPA created at: $(EXPORT_PATH)/$(SCHEME)-unsigned.ipa"

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

# Run SwiftLint
lint:
	@echo "Running SwiftLint..."
	swiftlint lint --strict
