# Setup Guide

Step-by-step instructions for building and running Knob from source.

## 1. Prerequisites

### Xcode

Install Xcode 16+ from the Mac App Store, then set it as the active toolchain:

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```

Verify:

```bash
xcodebuild -version
# Xcode 16.x
```

### Homebrew dependencies

```bash
brew install cmake xcodegen
```

## 2. Clone the repository

```bash
git clone --recurse-submodules https://github.com/markconde/knob.git
cd knob
```

If you already cloned without `--recurse-submodules`:

```bash
git submodule update --init --recursive
```

## 3. Build whisper.cpp

The build script compiles whisper.cpp as a static library with Metal GPU acceleration:

```bash
bash Knob/Scripts/build-whisper.sh
```

This produces static libraries under `vendor/whisper.cpp/build/install/lib/`. The script skips the build if the libraries are already up to date.

### What gets built

| Library | Purpose |
|---|---|
| `libwhisper.a` | Core whisper inference |
| `libggml.a` | Tensor library |
| `libggml-base.a` | Base GGML operations |
| `libggml-cpu.a` | CPU backend |
| `libggml-metal.a` | Metal GPU backend |

## 4. Generate Xcode project

```bash
xcodegen generate
```

This reads `project.yml` and produces `Knob.xcodeproj`. The generated project file is gitignored — `project.yml` is the source of truth.

## 5. Build the app

### From the command line

```bash
xcodebuild -project Knob.xcodeproj -scheme Knob -configuration Debug -arch arm64 build
```

### From Xcode

Open `Knob.xcodeproj`, select the **Knob** scheme, and build (Cmd+B).

**Note:** The first build will run `build-whisper.sh` automatically via the pre-build script phase. This takes a few minutes on first run.

### Code signing

The project uses automatic code signing with no team set. To sign with your developer certificate:

1. Open the project in Xcode
2. Select the Knob target → Signing & Capabilities
3. Select your development team

Or set `DEVELOPMENT_TEAM` in `project.yml` and regenerate.

## 6. Download the whisper model

Knob uses the `ggml-small.en.bin` model (~466 MB). Create the model directory and download:

```bash
mkdir -p ~/Library/Application\ Support/Knob/models

# Download from Hugging Face
curl -L -o ~/Library/Application\ Support/Knob/models/ggml-small.en.bin \
  https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-small.en.bin
```

## 7. Grant permissions

On first launch, Knob needs two macOS permissions:

### Microphone

The app will show a system dialog requesting microphone access. Click Allow.

### Accessibility

Required for the global hotkey and synthetic paste. The app will direct you to:

**System Settings → Privacy & Security → Accessibility**

Add and enable Knob in the list. You may need to restart the app after granting.

## 8. Run

Launch the built app from Xcode (Cmd+R) or from the build output:

```bash
open ~/Library/Developer/Xcode/DerivedData/Knob-*/Build/Products/Debug/Knob.app
```

You should see a microphone icon in the menu bar.

## Troubleshooting

### `xcodegen` not found

```bash
brew install xcodegen
```

### `cmake` not found

```bash
brew install cmake
```

### Build fails with missing `whisper.h`

Run the whisper build script first:

```bash
bash Knob/Scripts/build-whisper.sh
```

### Linker errors (undefined symbols)

The set of `.a` files from whisper.cpp may change across versions. Check what was actually built:

```bash
ls vendor/whisper.cpp/build/install/lib/
```

Update `OTHER_LDFLAGS` in `project.yml` to match, then regenerate with `xcodegen generate`.

### Accessibility permission not working

Make sure you're granting permission to the correct binary. During development, this may be the Xcode-built `.app` in DerivedData, not a copy elsewhere. After granting, restart the app.
