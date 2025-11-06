# Garmin Watch watchface

The repository contains the watchface for Garmin usable with Trio system.

| units | Data Type | Fenix8Pro |
| --- | --- | --- |
| mmol | sensRatio | <img src="https://github.com/mountrcg/Trio-GarminWatchface/blob/main/Fenix8Pro_mmol-sensRatio.png" width="300"> |
| mgdl | COB | <img src="https://github.com/mountrcg/Trio-GarminWatchface/blob/main/Fenix8Pro_mgdl-COB.png" width="300"> |

The WF requires a large PR applied to Trio, which is not yet done. In the meanwhile you can use the branch Garmin from my Trio repo, if you want access to the new Garmin watch implementations. They let you define within Trio app whether to show COB or sensitivity ratio.

You could also use the popular Swissalpine xDrip+/Spike watchface. I will make the derivative for Trio available here in the release section as prg's only. So no settings, it will be defaulted to Trio as data source.

## How to use 

To sideload the prg in your devices there are several methods. 

### I use Android File Transfer:
Make sure Garmin Express is not installed
- Make sure usb mode in watch is MTP (media transfer)
- Attach your watch to computer by USB. Android File Transfer starts automatically.
- Drop the prg file in the folder GARMIN/Apps
- quit Android File Transfer, detach Watch from USB

### May be it also works with Garmin Express:
- Install Garmin Express and configure with your account
- Attach your watch to computer by USB. You should see your watch as USB-drive then.
- It's usually named "GARMIN" as device (on Mac too, plus it have drive letter in windows, for example, let's say it's drive "E:").
Open your watch storage in Explorer or Finder, enter into folder GARMIN and then in its subfolder APP, so you now should be in path like E:\GARMIN\APPS (on Windows) or /GARMIN/GARMIN/APPS  (on Mac, where first "GARMIN" stands for device name).
- Download any watchface, app, widget with .PRG-file extension format from our file archive you want and put it in that GARMIN/APPS folder.
- You even can download that file directly to yours watch folder from browser, but be sure to finish download before detachment, or you can have broken unfinished file.
- Eject garmin's USB-storage, wait until it writes all caches and only then detach your watch from USB.
- Enter into watch settings and choose ConnectIQ watchface or enable/disable widget or work with that freshly installed app.

## How to start building yourself

Download the Garmin SDK.
You need to install Visual Studio Code. In it you will need to install the Monkey C plugin. 
Once you have that within Visual Studio Code hit CMD-Shift-P and enter Monkey. You will see all commands for testing and building Garmin apps.
* use `Monkey C: Open SDK Manager` and download all devices and newest SDK release
* use `Monkey C: Generate a Developer Key` and follow instructions
* use `Monkey C: Build for Device` to genrate your own *.prg file to sideload to your watch
* 
More information are available here : https://developer.garmin.com/connect-iq/overview/ 

# Developer Setup Guide

## Quick Start

### First Time Setup

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd Trio-GarminWatchface
   ```

2. **Run the setup script** (Recommended)
   ```bash
   chmod +x setup.sh
   ./setup.sh
   ```
   
   OR manually create your configuration:
   
   ```bash
   cp ConfigExample.local Config.local
   # Edit Config.local with your settings
   ```

3. **Verify your configuration**
   ```bash
   make show-config
   ```

4. **Build and run**
   ```bash
   make build    # Build the app
   make run      # Build and run in simulator
   make help     # See all available commands
   ```

## Configuration Files

### `Config.local`
This file contains your personal development settings:
- SDK path
- Preferred device
- Developer key location
- Deploy path

### `ConfigOverride.local` (Your personal settings - NOT in git)
Optional file for additional overrides that take precedence over Config.local.

### `properties.mk` (Shared defaults - IN git)
Contains default settings that work for most developers. Your Config.local overrides these.

## Common Settings

### SDK Path Examples
- **macOS**: `/Users/YourName/Library/Application\ Support/Garmin/ConnectIQ/Sdks/connectiq-sdk-mac-8.3.0-2025-09-22-5813687a0`
- **Windows**: `C:/Users/YourName/AppData/Roaming/Garmin/ConnectIQ/Sdks/connectiq-sdk-win-8.3.0`
- **Linux**: `/home/yourname/garmin/connectiq-sdk-linux-8.3.0`

### Popular Devices
- `fenix7`, `fenix6`, `fenix5xplus`
- `enduro3`, `enduro`
- `epix2`, `epixpro51mm`
- `venu3`, `venu2`
- `forerunner965`, `forerunner955`
- `edge1040`, `edge840`

## Useful Make Commands

### Building
- `make build` - Build for your default device
- `make buildall` - Build for all supported devices
- `make release` - Build optimized release version
- `make debug` - Build with debug symbols

### Testing
- `make run` - Build and run in simulator
- `make sim` - Just start the simulator
- `make test` - Run unit tests
- `make check` - Run type checking

### Distribution
- `make package` - Create .iq file for Connect IQ Store
- `make deploy` - Copy to your connected Garmin device

### Development
- `make clean` - Remove all build artifacts
- `make devices` - List all supported devices
- `make validate` - Check manifest for issues
- `make show-config` - Show current configuration

## Troubleshooting

### SDK Not Found
If you get "SDK not found" warning:
1. Check that Connect IQ SDK is installed
2. Update `SDK_HOME` in `Config.local` with correct path
3. Run `make show-config` to verify

### Simulator Won't Start
If simulator doesn't connect:
1. Make sure no other simulator is running
2. Try `make clean` then `make run`
3. Manually start simulator with `make sim`, then `make install`

### Device Not Supported
If your device isn't recognized:
1. Check device name with `make devices`
2. Ensure device is listed in `manifest.xml`
3. Update Connect IQ SDK to latest version

## Adding New Developers

When a new developer joins:
1. They clone the repository
2. Run `./setup.sh` or copy `ConfigExample.local` to `Config.local`
3. Update `Config.local` with their paths
4. Start developing!

No need to modify any shared files or worry about merge conflicts!

## Priority Order

Configuration settings are loaded in this order (later overrides earlier):
1. `properties.mk` defaults
2. `Config.local` (your main config)
3. `ConfigOverride.local` (optional additional overrides)

