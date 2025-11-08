include properties.mk
appName = `grep entry manifest.xml | sed 's/.*entry="\([^"]*\).*/\1/'`
devices = `grep 'iq:product id' manifest.xml | sed 's/.*iq:product id="\([^"]*\).*/\1/'`

.DEFAULT_GOAL := help

help:
	@echo "Garmin Connect IQ Makefile Commands:"
	@echo ""
	@echo "Building:"
	@echo "  make build         - Build for default device ($(DEVICE))"
	@echo "  make buildall      - Build for all devices in manifest"
	@echo "  make choose        - Interactive device selection and build"
	@echo "  make release       - Build optimized release version"
	@echo "  make debug         - Build debug version with profiling"
	@echo ""
	@echo "Running:"
	@echo "  make sim           - Start the simulator (leave it running)"
	@echo "  make install       - Install to running simulator"
	@echo "  make run           - Build and install to simulator"
	@echo "  make choose-run    - Choose device, build, and run"
	@echo "  make test          - Build and run unit tests"
	@echo ""
	@echo "Other:"
	@echo "  make clean         - Remove all built files"
	@echo "  make package       - Create .iq file for Connect IQ store"
	@echo "  make devices       - List all supported devices"
	@echo "  make validate      - Validate manifest and resources"
	@echo ""
	@echo "Current settings:"
	@echo "  App Name: $(appName)"
	@echo "  Device: $(DEVICE)"

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

# Interactive device selection and build
choose:
	@echo "Available devices:"
	@PS3="Select device number: "; \
	select device in $(devices); do \
		if [ -n "$$device" ]; then \
			echo "Building for $$device..."; \
			"$(SDK_HOME)/bin/monkeyc" \
			--jungles ./monkey.jungle \
			--device $$device \
			--output bin/$(appName)-$$device.prg \
			--private-key $(PRIVATE_KEY) \
			--warn; \
			echo "Built: bin/$(appName)-$$device.prg"; \
			break; \
		else \
			echo "Invalid selection"; \
		fi; \
	done

# Interactive device selection, build, and run
choose-run:
	@echo "Available devices:"
	@PS3="Select device number: "; \
	select device in $(devices); do \
		if [ -n "$$device" ]; then \
			echo "Building for $$device..."; \
			"$(SDK_HOME)/bin/monkeyc" \
			--jungles ./monkey.jungle \
			--device $$device \
			--output bin/$(appName)-$$device.prg \
			--private-key $(PRIVATE_KEY) \
			--warn && \
			echo "Checking for simulator..." && \
			(pgrep -q -f "connectiq" || (echo "Starting simulator..." && "$(SDK_HOME)/bin/connectiq" &)) && \
			sleep 3 && \
			echo "Installing to simulator..." && \
			"$(SDK_HOME)/bin/monkeydo" bin/$(appName)-$$device.prg $$device; \
			break; \
		else \
			echo "Invalid selection"; \
		fi; \
	done

# Build and install to simulator (uses existing sim if running)
run: build
	@echo "Checking for running simulator..."
	@pgrep -q -f "connectiq" || (echo "Starting simulator..." && "$(SDK_HOME)/bin/connectiq" &)
	@sleep 3
	@echo "Installing to simulator..."
	@"$(SDK_HOME)/bin/monkeydo" bin/$(appName).prg $(DEVICE)

# Just start the simulator
sim:
	@if pgrep -q -f "connectiq"; then \
		echo "Simulator already running"; \
	else \
		echo "Starting simulator..."; \
		"$(SDK_HOME)/bin/connectiq" & \
		echo "Wait 10-15 seconds for simulator window to appear"; \
	fi

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

# Run unit tests (uses existing sim if running)
test:
	"$(SDK_HOME)/bin/monkeyc" \
	--jungles ./monkey.jungle \
	--device $(DEVICE) \
	--output bin/$(appName)-test.prg \
	--private-key $(PRIVATE_KEY) \
	--unit-test \
	--warn
	@echo "Checking for running simulator..."
	@pgrep -q -f "connectiq" || (echo "Starting simulator..." && "$(SDK_HOME)/bin/connectiq" &)
	@sleep 3
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

# Watch for changes and rebuild (requires fswatch)
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

# Install to simulator (without building) - assumes sim is running
install:
	@echo "Installing to simulator..."
	@"$(SDK_HOME)/bin/monkeydo" bin/$(appName).prg $(DEVICE)

# Build debug and run (uses existing sim if running)
run-debug: debug
	@echo "Checking for running simulator..."
	@pgrep -q -f "connectiq" || (echo "Starting simulator..." && "$(SDK_HOME)/bin/connectiq" &)
	@sleep 3
	@"$(SDK_HOME)/bin/monkeydo" bin/$(appName)-debug.prg $(DEVICE)

# Kill all stuck simulator processes
kill-sim:
	@echo "Killing stuck simulator processes..."
	@pkill -9 -f monkeydo || true
	@pkill -9 -f "bin/sh.*monkeydo" || true
	@echo "Done. Run 'make sim' to start fresh."

# Create all common build variants
all: clean build release debug optimize-size optimize-speed
	@echo "Built all variants"

.PHONY: help build buildall choose choose-run run sim debug release test check clean deploy package package-all devices validate watch stats optimize-size optimize-speed install run-debug kill-sim all