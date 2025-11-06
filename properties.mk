# Default configuration - these can be overridden by Config.local
# This file is committed to git

# Try to include local developer settings (not in git)
-include ConfigOverride.local

# Default SDK path (macOS standard location)
SDK_HOME ?= $(HOME)/Library/Application\ Support/Garmin/ConnectIQ/Sdks/connectiq-sdk-mac-8.3.0-2025-09-22-5813687a0

# Default device for testing
DEVICE ?= fenix7

# Default private key location
PRIVATE_KEY ?= $(HOME)/.ssh/developer_key

# Default deploy location (for make deploy)
# This could be a mounted Garmin device or a specific folder
DEPLOY ?= /Volumes/GARMIN/GARMIN/APPS/

# Additional settings with defaults
BUILD_NUMBER ?= 0
VERBOSE ?= false

# Computed values (don't override these)
APP_NAME := $(shell grep entry manifest.xml | sed 's/.*entry="\([^"]*\).*/\1/')
SDK_BIN := $(SDK_HOME)/bin

# Validate that SDK exists
ifeq ($(wildcard $(SDK_BIN)/monkeyc),)
    $(warning SDK not found at $(SDK_HOME))
    $(warning Please create ConfigOverride.local and set SDK_HOME to your Connect IQ SDK path)
endif

# Show current configuration (can be called with make show-config)
show-config:
	@echo "Current Configuration:"
	@echo "  SDK_HOME: $(SDK_HOME)"
	@echo "  DEVICE: $(DEVICE)"
	@echo "  PRIVATE_KEY: $(PRIVATE_KEY)"
	@echo "  DEPLOY: $(DEPLOY)"
	@echo "  APP_NAME: $(APP_NAME)"
	@echo ""
	@if [ -f ConfigOverride.local ]; then \
		echo "Using local overrides from ConfigOverride.local"; \
	else \
		echo "No ConfigOverride.local found - using defaults from Config.local"; \
		echo "Create ConfigOverride.local to override these settings"; \
	fi
