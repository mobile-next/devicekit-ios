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

.PHONY: clean build archive ipa-unsigned sim-zip-arm64 sim-zip-x86_64 sim-zip sim-install test-coverage coverage-html lint

clean:
	@echo "Cleaning build artifacts..."
	rm -rf $(BUILD_DIR)
	xcodebuild clean -project $(PROJECT) -scheme $(SCHEME) -configuration $(CONFIGURATION)

debug:
	@$(MAKE) build CONFIGURATION=Debug

release:
	@$(MAKE) build CONFIGURATION=Release

# Create unsigned IPA with XCUITest runner for real iOS devices
ipa-unsigned:
	@echo "Building unsigned test runner for arm64 iOS devices..."
	xcodebuild build-for-testing \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-configuration $(CONFIGURATION) \
		-destination 'generic/platform=iOS' \
		-derivedDataPath $(BUILD_DIR) \
		CODE_SIGN_IDENTITY="" \
		CODE_SIGNING_REQUIRED=NO \
		CODE_SIGNING_ALLOWED=NO | xcbeautify
	@scripts/patch-runner.sh "$(BUILD_DIR)/Build/Products/$(CONFIGURATION)-iphoneos"
	@echo "Packaging runner IPA..."
	@rm -rf $(EXPORT_PATH)/Payload
	@rm -f $(EXPORT_PATH)/$(SCHEME)-runner.ipa
	@mkdir -p $(EXPORT_PATH)/Payload
	@cp -r "$(BUILD_DIR)/Build/Products/$(CONFIGURATION)-iphoneos/$(SCHEME)UITests-Runner.app" $(EXPORT_PATH)/Payload/
	@cd $(EXPORT_PATH) && zip -r $(SCHEME)-runner.ipa Payload
	@rm -rf $(EXPORT_PATH)/Payload
	@echo "Runner IPA created at: $(EXPORT_PATH)/$(SCHEME)-runner.ipa"

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
	@scripts/patch-runner.sh "$(BUILD_DIR)/Build/Products/$(CONFIGURATION)-iphonesimulator" "$(EXPORT_PATH)"
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
	@scripts/patch-runner.sh "$(BUILD_DIR)/Build/Products/$(CONFIGURATION)-iphonesimulator" "$(EXPORT_PATH)"
	@cd $(EXPORT_PATH) && zip -r $(SCHEME)-Sim-x86_64.zip $(SCHEME)UITests-Runner.app
	@rm -rf "$(EXPORT_PATH)/$(SCHEME)UITests-Runner.app"
	@echo "Simulator zip created at: $(EXPORT_PATH)/$(SCHEME)-Sim-x86_64.zip"

# Build both simulator zips
sim-zip: sim-zip-arm64 sim-zip-x86_64

# Build and install on booted simulator
sim-install:
	@BOOTED=$$(xcrun simctl list devices booted -j | jq -r '[.devices[][] | select(.state=="Booted")] | first | .udid'); \
	echo "Building for simulator $$BOOTED..."; \
	xcodebuild build-for-testing \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-configuration $(CONFIGURATION) \
		-destination "id=$$BOOTED" \
		-derivedDataPath $(BUILD_DIR)/local | xcbeautify; \
	PRODUCTS="$(BUILD_DIR)/local/Build/Products/$(CONFIGURATION)-iphonesimulator"; \
	scripts/patch-runner.sh "$$PRODUCTS"; \
	xcrun simctl install "$$BOOTED" "$$PRODUCTS/$(SCHEME).app"; \
	xcrun simctl install "$$BOOTED" "$$PRODUCTS/$(SCHEME)UITests-Runner.app"; \
	echo "Installed on simulator $$BOOTED"

# Build, run mocha tests with code coverage
test-coverage:
	@rm -rf $(BUILD_DIR)/coverage.xcresult
	@BOOTED=$$(xcrun simctl list devices booted -j | jq -r '[.devices[][] | select(.state=="Booted")] | first | .udid'); \
	scripts/test-coverage.sh $(PROJECT) $(SCHEME) "$$BOOTED" $(BUILD_DIR)

# Generate HTML coverage report (run after test-coverage)
coverage-html:
	@PROFDATA=$$(find $(BUILD_DIR)/local/Build/ProfileData -name "Coverage.profdata" 2>/dev/null | head -1); \
	BINARY="$(BUILD_DIR)/local/Build/Products/Debug-iphonesimulator/$(SCHEME)UITests-Runner.app/PlugIns/$(SCHEME)UITests.xctest/$(SCHEME)UITests"; \
	if [ -z "$$PROFDATA" ] || [ ! -f "$$BINARY" ]; then echo "error: Run 'make test-coverage' first"; exit 1; fi; \
	rm -rf coverage-html; \
	xcrun llvm-cov show "$$BINARY" -instr-profile "$$PROFDATA" -format=html -output-dir=coverage-html \
		-ignore-filename-regex='build/local/SourcePackages|DerivedSources'; \
	echo "Coverage report: coverage-html/index.html"; \
	open coverage-html/index.html

# Run SwiftLint
lint:
	@echo "Running SwiftLint..."
	swiftlint lint --strict
