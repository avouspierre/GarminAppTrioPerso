include properties.mk
appName = `grep entry manifest.xml | sed 's/.*entry="\([^"]*\).*/\1/'`
devices = `grep 'iq:product id' manifest.xml | sed 's/.*iq:product id="\([^"]*\).*/\1/'`

# Default target
.DEFAULT_GOAL := help

# Help target - shows available commands
help:
	@echo "Garmin Connect IQ Makefile Commands:"
	@echo "  make build         - Build for default device ($(DEVICE))"
	@echo "  make buildall      - Build for all devices in manifest"
	@echo "  make run           - Build and run in simulator"
	@echo "  make test          - Build and run unit tests"
	@echo "  make clean         - Remove all built files"
	@echo "  make package       - Create .iq file for Connect IQ store"
	@echo "  make deploy        - Copy built .prg to device/folder"
	@echo "  make check         - Run type checking (strict mode)"
	@echo "  make sim           - Just start the simulator"
	@echo "  make release       - Build optimized release version"
	@echo "  make debug         - Build debug version with profiling"
	@echo "  make devices       - List all supported devices"
	@echo "  make validate      - Validate manifest and resources"
	@echo "  make show-config   - Show current configuration"
	@echo ""
	@echo "Current settings:"
	@echo "  App Name: $(appName)"
	@echo "  Device: $(DEVICE)"
	@echo "  SDK: $(SDK_HOME)"

# Standard build
build:
	"$(SDK_HOME)/bin/monkeyc" \
	--jungles ./monkey.jungle \
	--device $(DEVICE) \
	--output bin/$(appName).prg \
	--private-key $(PRIVATE_KEY) \
	--warn

# Build for all devices in manifest
buildall:
	@for device in $(devices); do \
		echo "-----"; \
		echo "Building for" $$device; \
		"$(SDK_HOME)/bin/monkeyc" \
		--jungles ./monkey.jungle \
		--device $$device \
		--output bin/$(appName)-$$device.prg \
		--private-key $(PRIVATE_KEY) \
		--warn; \
	done

# Build and run in simulator
run: build
	@"$(SDK_HOME)/bin/connectiq" &
	@echo "Waiting for simulator to start..."
	@sleep 5
	@"$(SDK_HOME)/bin/monkeydo" bin/$(appName).prg $(DEVICE) || \
	(echo "Retrying connection to simulator..." && sleep 3 && \
	"$(SDK_HOME)/bin/monkeydo" bin/$(appName).prg $(DEVICE))

# Just start the simulator without building
sim:
	@"$(SDK_HOME)/bin/connectiq" &
	@echo "Simulator started"

# Build with debug symbols and profiling support
debug:
	"$(SDK_HOME)/bin/monkeyc" \
	--jungles ./monkey.jungle \
	--device $(DEVICE) \
	--output bin/$(appName)-debug.prg \
	--private-key $(PRIVATE_KEY) \
	--debug \
	--profile \
	--typecheck 3 \
	--warn

# Build optimized release version
release:
	"$(SDK_HOME)/bin/monkeyc" \
	--jungles ./monkey.jungle \
	--device $(DEVICE) \
	--output bin/$(appName)-release.prg \
	--private-key $(PRIVATE_KEY) \
	--release \
	--optimization 2 \
	--warn

# Run unit tests
test:
	"$(SDK_HOME)/bin/monkeyc" \
	--jungles ./monkey.jungle \
	--device $(DEVICE) \
	--output bin/$(appName)-test.prg \
	--private-key $(PRIVATE_KEY) \
	--unit-test \
	--warn
	@"$(SDK_HOME)/bin/connectiq" &
	@sleep 5
	@"$(SDK_HOME)/bin/monkeydo" bin/$(appName)-test.prg $(DEVICE) -t

# Type checking with strict mode
check:
	"$(SDK_HOME)/bin/monkeyc" \
	--jungles ./monkey.jungle \
	--device $(DEVICE) \
	--output bin/$(appName)-check.prg \
	--private-key $(PRIVATE_KEY) \
	--typecheck 3 \
	--warn

# Clean build artifacts
clean:
	@rm -rf bin/*
	@echo "Cleaned bin directory"

# Deploy to device (copy to GARMIN folder when device connected)
deploy: build
	@cp bin/$(appName).prg $(DEPLOY)
	@echo "Deployed $(appName).prg to $(DEPLOY)"

# Create Connect IQ store package
package:
	@"$(SDK_HOME)/bin/monkeyc" \
	--jungles ./monkey.jungle \
	--package-app \
	--release \
	--output bin/$(appName).iq \
	--private-key $(PRIVATE_KEY) \
	--warn
	@echo "Created package: bin/$(appName).iq"

# Build for store with all devices
package-all:
	@echo "Building store package for all devices..."
	@"$(SDK_HOME)/bin/monkeyc" \
	--jungles ./monkey.jungle \
	--package-app \
	--release \
	--output bin/$(appName)-all.iq \
	--private-key $(PRIVATE_KEY) \
	--warn
	@echo "Created multi-device package: bin/$(appName)-all.iq"

# List all supported devices
devices:
	@echo "Devices in manifest.xml:"
	@echo $(devices) | tr ' ' '\n' | sort | nl

# Validate manifest and check for common issues
validate:
	@echo "Validating manifest.xml..."
	@if [ ! -f manifest.xml ]; then echo "ERROR: manifest.xml not found"; exit 1; fi
	@echo "Checking for duplicate permissions..."
	@grep -o 'uses-permission id="[^"]*"' manifest.xml | sort | uniq -d | sed 's/uses-permission id="/Duplicate: /;s/"//'
	@echo "Validation complete"

# Watch for changes and rebuild (requires fswatch or inotifywait)
watch:
	@echo "Watching for changes (requires fswatch)..."
	@fswatch -o source/ resources* manifest.xml | while read f; do make build; done

# Generate build statistics
stats: 
	"$(SDK_HOME)/bin/monkeyc" \
	--jungles ./monkey.jungle \
	--device $(DEVICE) \
	--output bin/$(appName)-stats.prg \
	--private-key $(PRIVATE_KEY) \
	--build-stats 0 \
	--warn

# Build with specific optimization
optimize-size:
	"$(SDK_HOME)/bin/monkeyc" \
	--jungles ./monkey.jungle \
	--device $(DEVICE) \
	--output bin/$(appName)-size.prg \
	--private-key $(PRIVATE_KEY) \
	--release \
	--optimization z \
	--warn
	@echo "Built size-optimized version"

optimize-speed:
	"$(SDK_HOME)/bin/monkeyc" \
	--jungles ./monkey.jungle \
	--device $(DEVICE) \
	--output bin/$(appName)-speed.prg \
	--private-key $(PRIVATE_KEY) \
	--release \
	--optimization p \
	--warn
	@echo "Built performance-optimized version"

# Install to simulator (without building)
install:
	@"$(SDK_HOME)/bin/monkeydo" bin/$(appName).prg $(DEVICE)

# Run in simulator with debug output
run-debug: debug
	@"$(SDK_HOME)/bin/connectiq" &
	@echo "Waiting for simulator to start..."
	@sleep 5
	@"$(SDK_HOME)/bin/monkeydo" bin/$(appName)-debug.prg $(DEVICE)

# Create all common build variants
all: clean build release debug optimize-size optimize-speed
	@echo "Built all variants"

.PHONY: help build buildall run sim debug release test check clean deploy package package-all devices validate watch stats optimize-size optimize-speed install run-debug all