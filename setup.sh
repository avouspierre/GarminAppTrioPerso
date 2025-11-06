#!/bin/bash
# Setup script for new developers

echo "Garmin Connect IQ Project Setup"
echo "================================"
echo ""

# Check if ConfigOverride.local already exists
if [ -f ConfigOverride.local ]; then
    echo "✅ ConfigOverride.local already exists. Your personal settings are preserved."
    exit 0
fi

# Create ConfigOverride.local for personal settings
touch ConfigOverride.local
echo "✓ Created ConfigOverride.local for your personal settings"

# Try to detect SDK location
echo ""
echo "Detecting Connect IQ SDK..."

# Common SDK locations
if [ -d "$HOME/Library/Application Support/Garmin/ConnectIQ/Sdks" ]; then
    # macOS - get the newest SDK (last in sorted list)
    SDK_DIR="$HOME/Library/Application Support/Garmin/ConnectIQ/Sdks"
    SDK_PATH=$(ls -d "$SDK_DIR"/connectiq-sdk-mac-* 2>/dev/null | sort -V | tail -n 1)
elif [ -d "$APPDATA/Garmin/ConnectIQ/Sdks" ]; then
    # Windows (Git Bash/WSL) - get the newest SDK
    SDK_DIR="$APPDATA/Garmin/ConnectIQ/Sdks"
    SDK_PATH=$(ls -d "$SDK_DIR"/connectiq-sdk-win-* 2>/dev/null | sort -V | tail -n 1)
elif [ -d "$HOME/garmin" ]; then
    # Linux (common location) - get the newest SDK
    SDK_PATH=$(ls -d "$HOME/garmin"/connectiq-sdk-linux-* 2>/dev/null | sort -V | tail -n 1)
fi

if [ -n "$SDK_PATH" ]; then
    echo "✓ Found SDK at: $SDK_PATH"
    # Add SDK path to ConfigOverride.local if not already there
    if ! grep -q "SDK_HOME" ConfigOverride.local; then
        echo "" >> ConfigOverride.local
        echo "# Auto-detected SDK path" >> ConfigOverride.local
        echo "SDK_HOME = $SDK_PATH" >> ConfigOverride.local
        echo "✓ Added SDK path to ConfigOverride.local"
    fi
else
    echo "⚠️  Could not auto-detect SDK location"
    echo "   Please add SDK_HOME to ConfigOverride.local manually"
fi

# Check for developer key
echo ""
echo "Checking for developer key..."
if [ -f "$HOME/.ssh/developer_key" ]; then
    echo "✓ Found developer key at default location"
else
    echo "⚠️  No developer key found at $HOME/.ssh/developer_key"
    echo "   Please update PRIVATE_KEY in Config.local"
fi

# Get preferred device
echo ""
read -p "Enter your preferred device for testing (e.g., fenix7, enduro3): " device
if [ -n "$device" ]; then
    if ! grep -q "DEVICE" ConfigOverride.local; then
        echo "" >> ConfigOverride.local
        echo "# Preferred device" >> ConfigOverride.local
        echo "DEVICE = $device" >> ConfigOverride.local
        echo "✓ Set default device to: $device"
    fi
fi

# Check for developer key and add to override if different from default
echo ""
echo "Checking for developer key..."
if [ -f "$HOME/.ssh/developer_key" ]; then
    echo "✓ Found developer key at default location"
else
    echo "⚠️  No developer key found at default location"
    read -p "Enter path to your developer key: " keypath
    if [ -n "$keypath" ]; then
        echo "" >> ConfigOverride.local
        echo "# Developer key path" >> ConfigOverride.local
        echo "PRIVATE_KEY = $keypath" >> ConfigOverride.local
    fi
fi

# Create bin directory if it doesn't exist
if [ ! -d "bin" ]; then
    mkdir bin
    echo "✓ Created bin directory"
fi

echo ""
echo "Setup complete! 🎉"
echo ""
echo "Next steps:"
echo "1. Review ConfigOverride.local for your personal settings"
echo "2. Run 'make show-config' to verify your settings"
echo "3. Run 'make build' to test the build"
echo "4. Run 'make help' to see all available commands"
