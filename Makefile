SWIFT_FORMAT = xcrun swift-format
SWIFT_TARGETS = chlipist chlipistTests
FILES ?= $(SWIFT_TARGETS)

.PHONY: format lint check

format:
	$(SWIFT_FORMAT) format --in-place --parallel --recursive $(FILES)

lint:
	$(SWIFT_FORMAT) lint --strict --parallel --recursive $(FILES)

check: lint