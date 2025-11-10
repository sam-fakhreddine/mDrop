# Build Instructions

This document provides detailed instructions for building mDrop from source.

## Prerequisites

### System Requirements

- **macOS**: 13.0 (Ventura) or later
- **Xcode**: 15.0 or later
- **Hardware**: Mac with Metal support (all Apple Silicon Macs, most Intel Macs from 2012+)

### Installing Xcode

1. Download Xcode from the Mac App Store or [Apple Developer](https://developer.apple.com/xcode/)
2. Install the Xcode Command Line Tools:
   ```bash
   xcode-select --install
   ```

## Building with Xcode (Recommended)

### Step 1: Clone the Repository

```bash
git clone https://github.com/yourusername/mDrop.git
cd mDrop
```

### Step 2: Open in Xcode

```bash
open mDrop.xcodeproj
```

Alternatively, you can:
- Launch Xcode
- Select "Open a project or file"
- Navigate to the `mDrop.xcodeproj` file

### Step 3: Configure Code Signing

1. Select the `mDrop` project in the Project Navigator (left sidebar)
2. Select the `mDrop` target
3. Go to the "Signing & Capabilities" tab
4. Under "Signing", select your Team from the dropdown
   - If you don't have a team, you can use your Apple ID:
     - Go to Xcode > Settings > Accounts
     - Click the "+" button to add your Apple ID
     - Select your newly added Apple ID as the team

### Step 4: Build and Run

**Option A: Run in Debug Mode**
- Press `Cmd + R` or click the ▶️ button in the top-left
- The app will build and launch automatically

**Option B: Build Only**
- Press `Cmd + B`
- Find the built app in `~/Library/Developer/Xcode/DerivedData/mDrop-*/Build/Products/Debug/`

**Option C: Build for Release**
- Select "Product" > "Scheme" > "Edit Scheme"
- Change "Build Configuration" to "Release"
- Press `Cmd + B` to build

### Step 5: Grant Permissions

On first launch, macOS will prompt you to grant microphone access:
1. Click "OK" when prompted
2. If you miss the prompt, go to:
   - System Settings > Privacy & Security > Microphone
   - Enable the checkbox next to "mDrop"

## Building from Command Line

### Quick Build

```bash
# Debug build
xcodebuild -project mDrop.xcodeproj -scheme mDrop -configuration Debug build

# Release build
xcodebuild -project mDrop.xcodeproj -scheme mDrop -configuration Release build
```

### Advanced Build Options

```bash
# Build with specific SDK
xcodebuild -project mDrop.xcodeproj \
  -scheme mDrop \
  -configuration Release \
  -sdk macosx \
  build

# Build for specific architecture (Apple Silicon)
xcodebuild -project mDrop.xcodeproj \
  -scheme mDrop \
  -configuration Release \
  -arch arm64 \
  build

# Build universal binary (Intel + Apple Silicon)
xcodebuild -project mDrop.xcodeproj \
  -scheme mDrop \
  -configuration Release \
  -arch arm64 -arch x86_64 \
  build
```

### Clean Build

If you encounter build issues, clean the build directory:

```bash
# Clean via xcodebuild
xcodebuild clean -project mDrop.xcodeproj -scheme mDrop

# Or manually remove derived data
rm -rf ~/Library/Developer/Xcode/DerivedData/mDrop-*
```

## Running the Built Application

After building, you can run the application:

```bash
# Debug build
open ~/Library/Developer/Xcode/DerivedData/mDrop-*/Build/Products/Debug/mDrop.app

# Release build
open ~/Library/Developer/Xcode/DerivedData/mDrop-*/Build/Products/Release/mDrop.app
```

## Creating a Distributable Package

### Archive for Distribution

1. In Xcode, select "Product" > "Archive"
2. Once complete, the Organizer window will open
3. Select your archive and click "Distribute App"
4. Choose distribution method:
   - **Direct Distribution**: For personal use
   - **App Store Connect**: For App Store submission
   - **Developer ID**: For distribution outside the App Store

### Command Line Archive

```bash
# Create archive
xcodebuild archive \
  -project mDrop.xcodeproj \
  -scheme mDrop \
  -configuration Release \
  -archivePath ./build/mDrop.xcarchive

# Export archive
xcodebuild -exportArchive \
  -archivePath ./build/mDrop.xcarchive \
  -exportPath ./build/export \
  -exportOptionsPlist ExportOptions.plist
```

## Troubleshooting

### Common Build Errors

#### Error: "No signing certificate found"

**Solution**:
1. Go to Xcode > Settings > Accounts
2. Add your Apple ID
3. Download manual provisioning profiles if needed

#### Error: "Metal validation errors"

**Solution**:
1. Ensure your Mac supports Metal
2. Check that the deployment target is set to macOS 13.0 or later
3. Verify shader syntax in `Shaders.metal`

#### Error: "Cannot find 'AVFoundation' in scope"

**Solution**:
1. This should not happen as AVFoundation is a system framework
2. Try cleaning the build folder: `Cmd + Shift + K`
3. Restart Xcode

#### Error: "Command Line Tools are not installed"

**Solution**:
```bash
xcode-select --install
```

### Build Performance Tips

- **Use Release Configuration**: Much faster runtime performance
- **Enable Build Timing**: Xcode > Settings > Behaviors > Enable "Show build times"
- **Clean Derived Data**: Periodically clean `~/Library/Developer/Xcode/DerivedData`

## Optimization Flags

The project is configured with optimal build settings:

### Debug Configuration
- `SWIFT_OPTIMIZATION_LEVEL = -Onone` (no optimization for debugging)
- `MTL_ENABLE_DEBUG_INFO = INCLUDE_SOURCE` (Metal debugging enabled)
- `DEBUG = 1` preprocessor macro

### Release Configuration
- `SWIFT_OPTIMIZATION_LEVEL = -O` (full optimization)
- `SWIFT_COMPILATION_MODE = wholemodule` (whole-module optimization)
- `MTL_FAST_MATH = YES` (faster Metal math operations)

## Continuous Integration

### GitHub Actions Example

```yaml
name: Build mDrop

on: [push, pull_request]

jobs:
  build:
    runs-on: macos-13
    steps:
      - uses: actions/checkout@v3

      - name: Select Xcode
        run: sudo xcode-select -s /Applications/Xcode_15.0.app

      - name: Build
        run: xcodebuild -project mDrop.xcodeproj -scheme mDrop -configuration Release build
```

## Development Builds

For active development:

1. Use Debug configuration for easier debugging
2. Enable "Debug Metal API Validation" in the scheme settings
3. Use Instruments for performance profiling
4. Enable Address Sanitizer for memory issue detection

## Questions or Issues?

If you encounter build issues not covered here, please:
1. Check the GitHub Issues page
2. Ensure you're using the latest Xcode version
3. Try a clean build
4. Open a new issue with your build log
