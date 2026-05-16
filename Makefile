SWIFT_FORMAT = xcrun swift-format
SWIFT_TARGETS = Chlipist ChlipistTests
FILES ?= $(SWIFT_TARGETS)
XCODEBUILD = xcodebuild
XCODE_PROJECT = Chlipist.xcodeproj
XCODE_SCHEME = Chlipist
XCODE_CONFIGURATION ?= Release
DERIVED_DATA_PATH ?= ./.build
MARKETING_VERSION ?= 0.0.1
CURRENT_PROJECT_VERSION ?= 1
CODE_SIGN_IDENTITY ?=
CODE_SIGNING_REQUIRED ?= NO
CODE_SIGNING_ALLOWED ?= NO

.PHONY: format lint check build-release-app

format:
	$(SWIFT_FORMAT) format --in-place --parallel --recursive $(FILES)

lint:
	$(SWIFT_FORMAT) lint --strict --parallel --recursive $(FILES)

check: lint

build-release-app:
	$(XCODEBUILD) -project $(XCODE_PROJECT) \
		-scheme $(XCODE_SCHEME) \
		-configuration $(XCODE_CONFIGURATION) \
		-derivedDataPath "$(DERIVED_DATA_PATH)" \
		MARKETING_VERSION="$(MARKETING_VERSION)" \
		CURRENT_PROJECT_VERSION="$(CURRENT_PROJECT_VERSION)" \
		CODE_SIGN_IDENTITY="$(CODE_SIGN_IDENTITY)" \
		CODE_SIGNING_REQUIRED=$(CODE_SIGNING_REQUIRED) \
		CODE_SIGNING_ALLOWED=$(CODE_SIGNING_ALLOWED) \
		build
